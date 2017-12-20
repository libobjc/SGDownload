//
//  SGDownloadImp.m
//  SGDownload
//
//  Created by Single on 2017/3/17.
//  Copyright © 2017年 single. All rights reserved.
//

#import "SGDownloadImp.h"
#import "SGDownloadTaskPrivate.h"
#import "SGDownloadTaskQueue.h"
#import "SGDownloadTuple.h"
#import "SGDownloadTupleQueue.h"
#import "SGDownloadTools.h"

#import <objc/message.h>
#if TARGET_OS_OSX
#import <AppKit/AppKit.h>
#elif TARGET_OS_IOS || TARGET_OS_TV
#import <UIKit/UIKit.h>
#endif


#pragma mark - SGDownlaodManager Interface

@interface SGDownloadManager: NSObject

+ (instancetype)manager;

@property (nonatomic, strong) NSMutableArray <SGDownload *> * downloads;

@end


#pragma mark - SGDownlaod Interface

NSString * const SGDownloadDefaultIdentifier = @"SGDownloadDefaultIdentifier";

@interface SGDownload () <NSURLSessionDownloadDelegate>

@property (nonatomic, strong) NSURLSession * session;
@property (nonatomic, strong) NSOperationQueue * sessionDelegateQueue;
@property (nonatomic, copy) void(^backgroundCompletionHandler)(void);

@property (nonatomic, strong) SGDownloadTaskQueue * taskQueue;
@property (nonatomic, strong) SGDownloadTupleQueue * taskTupleQueue;
@property (nonatomic, strong) NSCondition * concurrentCondition;
@property (nonatomic, strong) NSLock * lastResumeLock;

@property (nonatomic, strong) NSOperationQueue * downloadOperationQueue;
@property (nonatomic, strong) NSInvocationOperation * downloadOperation;

@property (nonatomic, assign) BOOL running;
@property (nonatomic, assign) BOOL closed;

@end


#pragma mark - SGDownlaodManager implementation

@implementation SGDownloadManager

+ (instancetype)manager
{
    static SGDownloadManager * manager = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        manager = [[SGDownloadManager alloc] init];
    });
    return manager;
}

- (instancetype)init
{
    if (self = [super init]) {
        self.downloads = [NSMutableArray array];
        
        NSNotificationName name = nil;
#if TARGET_OS_OSX
        name = NSApplicationWillTerminateNotification;
#elif TARGET_OS_IOS || TARGET_OS_TV
        name = UIApplicationWillTerminateNotification;
#endif
        if (name) {
            [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(applicationWillTerminate) name:name object:nil];
        }
    }
    return self;
}

- (void)applicationWillTerminate
{
    [[self.downloads copy] enumerateObjectsUsingBlock:^(SGDownload * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        [obj invalidate];
        [obj.taskQueue invalidate];
        [obj.taskQueue archive];
    }];
}

@end


#pragma mark - SGDownload implementation

@implementation SGDownload

+ (instancetype)download
{
    return [self downloadWithIdentifier:SGDownloadDefaultIdentifier];
}

+ (instancetype)downloadWithIdentifier:(NSString *)identifier
{
    for (SGDownload * obj in [SGDownloadManager manager].downloads) {
        if ([obj.identifier isEqualToString:identifier]) {
            return obj;
        }
    }
    SGDownload * obj = [[self alloc] initWithIdentifier:identifier];
    [[SGDownloadManager manager].downloads addObject:obj];
    return obj;
}

- (instancetype)initWithIdentifier:(NSString *)identifier
{
    if (self = [super init]) {
        self->_identifier = identifier;
        self->_sessionConfiguration = [NSURLSessionConfiguration backgroundSessionConfigurationWithIdentifier:identifier];
        self.maxConcurrentOperationCount = 1;
        self.taskQueue = [SGDownloadTaskQueue queueWithDownload:self];
        self.taskTupleQueue = [[SGDownloadTupleQueue alloc] init];
    }
    return self;
}

- (void)run
{
    if (!self.running) {
        self.running = YES;
        [self setupOperation];
    }
}

- (void)invalidate
{
    if (self.closed) return;
    
    self.closed = YES;
    [self.taskQueue invalidate];
    [self.taskTupleQueue cancelAllTupleResume:YES completionHandler:^(NSArray <SGDownloadTuple *> * tuples) {
        [self.taskQueue archive];
        [self.session invalidateAndCancel];
        [self.downloadOperationQueue cancelAllOperations];
        self.downloadOperation = nil;
        [self.concurrentCondition broadcast];
        [[SGDownloadManager manager].downloads removeObject:self];
    }];
}

- (void)setupOperation
{
    if (self.maxConcurrentOperationCount <= 0) {
        self.maxConcurrentOperationCount = 1;
    }
    self.concurrentCondition = [[NSCondition alloc] init];
    self.lastResumeLock = [[NSLock alloc] init];
    
    self.sessionDelegateQueue = [[NSOperationQueue alloc] init];
    self.sessionDelegateQueue.maxConcurrentOperationCount = 1;
    self.sessionDelegateQueue.qualityOfService = NSQualityOfServiceUserInteractive;
    self.sessionDelegateQueue.suspended = YES;
    
    [self.lastResumeLock lock];
    self.session = [NSURLSession sessionWithConfiguration:self.sessionConfiguration
                                                 delegate:self
                                            delegateQueue:self.sessionDelegateQueue];
    
    Ivar ivar = class_getInstanceVariable(NSClassFromString(@"__NSURLBackgroundSession"), "_tasks");
    if (ivar) {
        NSDictionary <NSNumber *, NSURLSessionDownloadTask *> * lastTasks = object_getIvar(self.session, ivar);
        if (lastTasks && lastTasks.count > 0) {
            for (NSNumber * key in lastTasks) {
                NSURLSessionDownloadTask * obj = [lastTasks objectForKey:key];
                SGDownloadTask * downloadTask = [self.taskQueue taskForContentURL:[self getURLFromSessionTask:obj]];
                if (downloadTask) {
                    [self.taskQueue setTaskState:downloadTask state:SGDownloadTaskStateRunning];
                    SGDownloadTuple * tuple = [SGDownloadTuple tupleWithDownloadTask:downloadTask sessionTask:obj];
                    [self.taskTupleQueue addTuple:tuple];
                }
            }
        }
    }
    [self.lastResumeLock unlock];
    self.sessionDelegateQueue.suspended = NO;
    
    self.downloadOperation = [[NSInvocationOperation alloc] initWithTarget:self selector:@selector(downloadOperationHandler) object:nil];
    self.downloadOperationQueue = [[NSOperationQueue alloc] init];
    self.downloadOperationQueue.maxConcurrentOperationCount = 1;
    self.downloadOperationQueue.qualityOfService = NSQualityOfServiceUserInteractive;
   [self.downloadOperationQueue addOperation:self.downloadOperation];
}

- (void)downloadOperationHandler
{
    while (YES) {
        @autoreleasepool
        {
            if (self.closed) {
                break;
            }
            [self.concurrentCondition lock];
            while (self.taskTupleQueue.tuples.count >= self.maxConcurrentOperationCount) {
                [self.concurrentCondition wait];
            }
            [self.concurrentCondition unlock];
            SGDownloadTask * downloadTask = [self.taskQueue downloadTaskSync];
            if (!downloadTask) {
                break;
            }
            [self.taskQueue setTaskState:downloadTask state:SGDownloadTaskStateRunning];
            
            NSURLSessionDownloadTask * sessionTask = nil;
            if (downloadTask.resumeInfoData.length > 0) {
                sessionTask = [self.session downloadTaskWithResumeData:downloadTask.resumeInfoData];
            } else {
                sessionTask = [self.session downloadTaskWithURL:downloadTask.contentURL];
            }
            SGDownloadTuple * tuple = [SGDownloadTuple tupleWithDownloadTask:downloadTask sessionTask:sessionTask];
            [self.taskTupleQueue addTuple:tuple];
            [sessionTask resume];
        }
    }
}


#pragma mark - Interface

- (SGDownloadTask *)taskForContentURL:(NSURL *)contentURL
{
    return [self.taskQueue taskForContentURL:contentURL];
}

- (NSArray <SGDownloadTask *> *)tasksForAll
{
    return [self.taskQueue.tasksForAll copy];
}

- (NSArray <SGDownloadTask *> *)tasksForRunningOrWatting
{
    return [[self.taskQueue tasksForRunningOrWatting] copy];
}

- (NSArray <SGDownloadTask *> *)tasksForState:(SGDownloadTaskState)state
{
    return [[self.taskQueue tasksForState:state] copy];
}

- (void)addDownloadTask:(SGDownloadTask *)task
{
    [self.taskQueue addDownloadTask:task];
}

- (void)addDownloadTasks:(NSArray <SGDownloadTask *> *)tasks
{
    [self.taskQueue addDownloadTasks:tasks];
}

- (void)addSuppendTask:(SGDownloadTask *)task
{
    [self.taskQueue addSuppendTask:task];
}

- (void)addSuppendTasks:(NSArray <SGDownloadTask *> *)tasks
{
    [self.taskQueue addSuppendTasks:tasks];
}

- (void)resumeAllTasks
{
    [self.taskQueue resumeAllTasks];
}

- (void)resumeTask:(SGDownloadTask *)task
{
    [self.taskQueue resumeTask:task];
}

- (void)resumeTasks:(NSArray <SGDownloadTask *> *)tasks
{
    [self.taskQueue resumeTasks:tasks];
}

- (void)suspendAllTasks
{
    [self.taskQueue suspendAllTasks];
    [self.taskTupleQueue cancelAllTupleResume:YES completionHandler:nil];
}

- (void)suspendTask:(SGDownloadTask *)task
{
    [self.taskQueue suspendTask:task];
    [self.taskTupleQueue cancelDownloadTask:task resume:YES completionHandler:nil];
}

- (void)suspendTasks:(NSArray <SGDownloadTask *> *)tasks
{
    [self.taskQueue suspendTasks:tasks];
    [self.lastResumeLock lock];
    [self.taskTupleQueue cancelDownloadTasks:tasks resume:YES completionHandler:^(NSArray<SGDownloadTuple *> *tuples) {
        [self.lastResumeLock unlock];
    }];
}

- (void)cancelAllTasks
{
    [self.taskQueue cancelAllTasks];
    [self.taskTupleQueue cancelAllTupleResume:NO completionHandler:nil];
}

- (void)cancelTask:(SGDownloadTask *)task
{
    [self.taskQueue cancelTask:task];
    [self.taskTupleQueue cancelDownloadTask:task resume:NO completionHandler:nil];
}

- (void)cancelTasks:(NSArray <SGDownloadTask *> *)tasks
{
    [self.taskQueue cancelTasks:tasks];
    [self.taskTupleQueue cancelDownloadTasks:tasks resume:NO completionHandler:nil];
}

- (void)cancelAllTasksAndDeleteFiles
{
    [self.taskQueue deleteAllTaskFiles];
    [self cancelAllTasks];
}

- (void)cancelTaskAndDeleteFile:(SGDownloadTask *)task
{
    [self.taskQueue deleteTaskFile:task];
    [self cancelTask:task];
}

- (void)cancelTasksAndDeleteFiles:(NSArray <SGDownloadTask *> *)tasks
{
    [self.taskQueue cancelTasks:tasks];
    [self cancelTasks:tasks];
}

- (void)dealloc
{
    [self invalidate];
}


#pragma mark - NSURLSessionDownloadDelegate

+ (void)handleEventsForBackgroundURLSession:(NSString *)identifier completionHandler:(void (^)(void))completionHandler
{
    SGDownload * download = [SGDownload downloadWithIdentifier:identifier];
    download.backgroundCompletionHandler = completionHandler;
}

- (void)URLSessionDidFinishEventsForBackgroundURLSession:(NSURLSession *)session
{
    if (self.backgroundCompletionHandler) {
        self.backgroundCompletionHandler();
    }
}

- (void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)sessionTask didCompleteWithError:(NSError *)error
{
    [self.lastResumeLock lock];
    [self.concurrentCondition lock];
    SGDownloadTask * downloadTask = [self.taskQueue taskForContentURL:[self getURLFromSessionTask:sessionTask]];
    SGDownloadTuple * tuple = [self.taskTupleQueue tupleWithDownloadTask:downloadTask sessionTask:(NSURLSessionDownloadTask *)sessionTask];
    if (!tuple) {
        [self.taskTupleQueue removeTupleWithSesstionTask:sessionTask];
        [self.concurrentCondition signal];
        [self.concurrentCondition unlock];
        [self.lastResumeLock unlock];
        return;
    }
    
    SGDownloadTaskState state;
    if (error) {
        NSData * resumeData = [error.userInfo objectForKey:NSURLSessionDownloadTaskResumeData];
        if (resumeData) {
            tuple.downloadTask.resumeInfoData = resumeData;
        }
        if (error.code == NSURLErrorCancelled) {
            state = SGDownloadTaskStateSuspend;
        } else {
            tuple.downloadTask.error = error;
            state = SGDownloadTaskStateFailured;
        }
    } else {
        if (![[NSFileManager defaultManager] fileExistsAtPath:tuple.downloadTask.fileURL.path]) {
            tuple.downloadTask.error = [NSError errorWithDomain:@"download file is deleted" code:-1 userInfo:nil];
            state = SGDownloadTaskStateFailured;
        } else {
            state = SGDownloadTaskStateFinished;
        }
    }
    
    [self.taskQueue setTaskState:tuple.downloadTask state:state];
    [self.taskTupleQueue removeTuple:tuple];
    if ([self.taskQueue tasksForRunningOrWatting].count <= 0 && self.taskTupleQueue.tuples.count <= 0) {
        dispatch_async(dispatch_get_main_queue(), ^{
            if ([self.delegate respondsToSelector:@selector(downloadDidCompleteAllRunningTasks:)]) {
                [self.delegate downloadDidCompleteAllRunningTasks:self];
            }
        });
    }
    [self.concurrentCondition signal];
    [self.concurrentCondition unlock];
    [self.lastResumeLock unlock];
}

- (void)URLSession:(NSURLSession *)session downloadTask:(NSURLSessionDownloadTask *)sessionTask didFinishDownloadingToURL:(NSURL *)location
{
    [self.lastResumeLock lock];
    SGDownloadTask * downloadTask = [self.taskQueue taskForContentURL:[self getURLFromSessionTask:sessionTask]];
    SGDownloadTuple * tuple = [self.taskTupleQueue tupleWithDownloadTask:downloadTask sessionTask:(NSURLSessionDownloadTask *)sessionTask];
    if (!tuple) {
        [self.lastResumeLock unlock];
        return;
    }
    
    NSString * path = location.path;
    BOOL exists = [[NSFileManager defaultManager] fileExistsAtPath:path];
    if (!exists) {
        path = [SGDownloadTools replacehHomeDirectoryForFilePath:path];
        exists = [[NSFileManager defaultManager] fileExistsAtPath:path];
        if (!exists) {
            tuple.downloadTask.error = [NSError errorWithDomain:@"download file is deleted" code:-1 userInfo:nil];
            [self.lastResumeLock unlock];
            return;
        }
    }
    
    NSError * error = nil;
    unsigned long long fileSzie = [[[NSFileManager defaultManager] attributesOfItemAtPath:path error:&error] fileSize];
    if (error || fileSzie == 0) {
        tuple.downloadTask.error = [NSError errorWithDomain:@"download file is empty" code:-1 userInfo:nil];
        [self.lastResumeLock unlock];
        return;
    }
    
    NSString * filePath = tuple.downloadTask.fileURL.path;
    NSString * directoryPath = filePath.stringByDeletingLastPathComponent;
    
    if ([[NSFileManager defaultManager] fileExistsAtPath:filePath]) {
        [[NSFileManager defaultManager] removeItemAtPath:filePath error:nil];
    }
    
    BOOL isDirectory;
    BOOL result = [[NSFileManager defaultManager] fileExistsAtPath:directoryPath isDirectory:&isDirectory];
    if (!result || !isDirectory) {
        [[NSFileManager defaultManager] createDirectoryAtPath:directoryPath withIntermediateDirectories:YES attributes:nil error:nil];
    }
    
    [[NSFileManager defaultManager] moveItemAtPath:path toPath:filePath error:&error];
    tuple.downloadTask.error = error;
    [self.lastResumeLock unlock];
}

- (void)URLSession:(NSURLSession *)session downloadTask:(NSURLSessionDownloadTask *)sessionTask didWriteData:(int64_t)bytesWritten totalBytesWritten:(int64_t)totalBytesWritten totalBytesExpectedToWrite:(int64_t)totalBytesExpectedToWrite
{
    [self.lastResumeLock lock];
    SGDownloadTask * downloadTask = [self.taskQueue taskForContentURL:[self getURLFromSessionTask:sessionTask]];
    SGDownloadTuple * tuple = [self.taskTupleQueue tupleWithDownloadTask:downloadTask sessionTask:(NSURLSessionDownloadTask *)sessionTask];
    if (!tuple) {
        [self.lastResumeLock unlock];
        return;
    }
    
    [tuple.downloadTask setBytesWritten:bytesWritten
                      totalBytesWritten:totalBytesWritten
              totalBytesExpectedToWrite:totalBytesExpectedToWrite];
    if (tuple.downloadTask.state != SGDownloadTaskStateSuspend) {
        [self.taskQueue setTaskState:tuple.downloadTask state:SGDownloadTaskStateRunning];
    }
    [self.lastResumeLock unlock];
}

- (void)URLSession:(NSURLSession *)session downloadTask:(NSURLSessionDownloadTask *)sessionTask didResumeAtOffset:(int64_t)fileOffset expectedTotalBytes:(int64_t)expectedTotalBytes
{
    [self.lastResumeLock lock];
    SGDownloadTask * downloadTask = [self.taskQueue taskForContentURL:[self getURLFromSessionTask:sessionTask]];
    SGDownloadTuple * tuple = [self.taskTupleQueue tupleWithDownloadTask:downloadTask sessionTask:(NSURLSessionDownloadTask *)sessionTask];
    if (!tuple) {
        [self.lastResumeLock unlock];
        return;
    }
    
    tuple.downloadTask.resumeFileOffset = fileOffset;
    tuple.downloadTask.resumeExpectedTotalBytes = expectedTotalBytes;
    if (tuple.downloadTask.state != SGDownloadTaskStateSuspend) {
        [self.taskQueue setTaskState:tuple.downloadTask state:SGDownloadTaskStateRunning];
    }
    [self.lastResumeLock unlock];
}

- (NSURL *)getURLFromSessionTask:(NSURLSessionTask *)sessionTask
{
    if (sessionTask.originalRequest.URL) {
        return sessionTask.originalRequest.URL;
    } else if (sessionTask.currentRequest.URL) {
        return sessionTask.currentRequest.URL;
    }
    return nil;
}

@end
