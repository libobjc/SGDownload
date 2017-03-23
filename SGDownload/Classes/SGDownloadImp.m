//
//  SGDownloadImp.m
//  SGDownload
//
//  Created by Single on 2017/3/17.
//  Copyright © 2017年 single. All rights reserved.
//

#import "SGDownloadImp.h"
#import "SGDownloadTask.h"
#import "SGDownloadTaskPrivate.h"
#import "SGDownloadTaskQueue.h"
#import "SGDownloadTuple.h"
#import "SGDownloadTupleQueue.h"
#import "SGDownloadTools.h"

#import <objc/message.h>

#import <TargetConditionals.h>
#if TARGET_OS_OSX
#import <AppKit/AppKit.h>
#elif TARGET_OS_IOS || TARGET_OS_TV
#import <UIKit/UIKit.h>
#endif

NSString * const SGDownloadDefaultIdentifier = @"SGDownloadDefaultIdentifier";

@interface SGDownload () <NSURLSessionDownloadDelegate>

@property (nonatomic, strong) NSURLSession * session;
@property (nonatomic, assign) NSInteger lastSessionTaskCount;
@property (nonatomic, copy) void(^backgroundCompletionHandler)();

@property (nonatomic, strong) SGDownloadTaskQueue * taskQueue;
@property (nonatomic, strong) SGDownloadTupleQueue * taskTupleQueue;
@property (nonatomic, strong) dispatch_semaphore_t concurrentSemaphore;

@property (nonatomic, strong) NSOperationQueue * delegateQueue;
@property (nonatomic, strong) NSOperationQueue * downloadOperationQueue;
@property (nonatomic, strong) NSInvocationOperation * downloadOperation;

@property (nonatomic, assign) BOOL closed;

@end

@implementation SGDownload

static NSMutableArray <SGDownload *> * downloads = nil;

+ (instancetype)download
{
    return [self downloadWithIdentifier:SGDownloadDefaultIdentifier];
}

+ (instancetype)downloadWithIdentifier:(NSString *)identifier
{
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        downloads = [NSMutableArray array];
    });
    for (SGDownload * obj in downloads) {
        if ([obj.identifier isEqualToString:identifier]) {
            return obj;
        }
    }
    SGDownload * obj = [[self alloc] initWithIdentifier:identifier];
    [downloads addObject:obj];
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
        [self setupNotification];
    }
    return self;
}

- (void)startRunning
{
    [self setupOperation];
}

- (void)setupOperation
{
    long count;
    if (self.maxConcurrentOperationCount <= 0) {
        count = 0;
    } else {
        count = self.maxConcurrentOperationCount - 1;
    }
    self.concurrentSemaphore = dispatch_semaphore_create(count);
    
    self.delegateQueue = [[NSOperationQueue alloc] init];
    self.delegateQueue.maxConcurrentOperationCount = 1;
    self.delegateQueue.qualityOfService = NSQualityOfServiceUserInteractive;
    
    self.session = [NSURLSession sessionWithConfiguration:self.sessionConfiguration
                                                 delegate:self
                                            delegateQueue:self.delegateQueue];
    
    Ivar ivar = class_getInstanceVariable(NSClassFromString(@"__NSURLBackgroundSession"), "_tasks");
    if (ivar) {
        NSDictionary <NSNumber *, NSURLSessionDownloadTask *> * lastTasks = object_getIvar(self.session, ivar);
        if (lastTasks && lastTasks.count > 0) {
            self.lastSessionTaskCount = lastTasks.count;
            [lastTasks enumerateKeysAndObjectsUsingBlock:^(NSNumber * _Nonnull key, NSURLSessionDownloadTask * _Nonnull obj, BOOL * _Nonnull stop) {
                SGDownloadTask * downloadTask = [self.taskQueue taskWithContentURL:obj.currentRequest.URL];
                if (obj.state == NSURLSessionTaskStateRunning) {
                    [self.taskQueue setTaskState:downloadTask state:SGDownloadTaskStateRunning];
                }
                SGDownloadTuple * tuple = [SGDownloadTuple tupleWithDownloadTask:downloadTask sessionTask:obj];
                [self.taskTupleQueue addTuple:tuple];
                [self.taskQueue archive];
            }];
        }
    }
    
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
            while (self.lastSessionTaskCount > 0) {
                dispatch_semaphore_wait(self.concurrentSemaphore, DISPATCH_TIME_FOREVER);
            }
            NSLog(@"开始下载新任务");
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
            [self.taskQueue archive];
            NSLog(@"开始下载 : %@", downloadTask.title);
            dispatch_semaphore_wait(self.concurrentSemaphore, DISPATCH_TIME_FOREVER);
        }
    }
}

- (void)stopRunning
{
    if (self.closed) return;
    
    self.closed = YES;
    [self.taskQueue invalidate];
    [self.taskTupleQueue cancelAllTupleResume:YES completionHandler:^(NSArray <SGDownloadTuple *> * tuples) {
        [self.taskQueue archive];
        [self.session invalidateAndCancel];
        [self.downloadOperationQueue cancelAllOperations];
        self.downloadOperation = nil;
        dispatch_semaphore_signal(self.concurrentSemaphore);
        [downloads removeObject:self];
    }];
}


#pragma mark - Interface

- (SGDownloadTask *)taskWithContentURL:(NSURL *)contentURL
{
    return [self.taskQueue taskWithContentURL:contentURL];
}

- (void)downloadTask:(SGDownloadTask *)task
{
    [self.taskQueue downloadTask:task];
}

- (void)downloadTasks:(NSArray<SGDownloadTask *> *)tasks
{
    [self.taskQueue downloadTasks:tasks];
}

- (void)resumeAllTasks
{
    [self.taskQueue resumeAllTasks];
}

- (void)resumeTask:(SGDownloadTask *)task
{
    [self.taskQueue resumeTask:task];
}

- (void)resumeTasks:(NSArray<SGDownloadTask *> *)tasks
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

- (void)suspendTasks:(NSArray<SGDownloadTask *> *)tasks
{
    [self.taskQueue suspendTasks:tasks];
    [self.taskTupleQueue cancelDownloadTasks:tasks resume:YES completionHandler:nil];
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

- (NSArray <SGDownloadTask *> *)tasks
{
    return self.taskQueue.tasks;
}


#pragma mark - NSURLSessionDownloadDelegate

- (void)handleEventsForBackgroundURLSession:(NSString *)identifier completionHandler:(void (^)())completionHandler
{
    if ([identifier isEqualToString:self.identifier]) {
        self.backgroundCompletionHandler = completionHandler;
    }
}

- (void)URLSessionDidFinishEventsForBackgroundURLSession:(NSURLSession *)session
{
    NSLog(@"%s", __func__);
    if (self.backgroundCompletionHandler) {
        self.backgroundCompletionHandler();
    }
}

- (void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task didCompleteWithError:(NSError *)error
{
    SGDownloadTuple * tuple = [self.taskTupleQueue tupleWithSessionTask:(NSURLSessionDownloadTask *)task];
    if (!tuple) return;
    
    [tuple.downloadTask setBytesWritten:0
                      totalBytesWritten:task.countOfBytesReceived
              totalBytesExpectedToWrite:task.countOfBytesExpectedToReceive];
    
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
    self.lastSessionTaskCount--;
    dispatch_semaphore_signal(self.concurrentSemaphore);
    [self.taskQueue archive];
}

- (void)URLSession:(NSURLSession *)session downloadTask:(NSURLSessionDownloadTask *)downloadTask didFinishDownloadingToURL:(NSURL *)location
{
    SGDownloadTuple * tuple = [self.taskTupleQueue tupleWithSessionTask:downloadTask];
    if (!tuple) return;
    
    NSString * path = location.path;
    BOOL exists = [[NSFileManager defaultManager] fileExistsAtPath:path];
    if (!exists) {
        path = [SGDownloadTools replacehHomeDirectoryForFilePath:path];
        exists = [[NSFileManager defaultManager] fileExistsAtPath:path];
        if (!exists) {
            tuple.downloadTask.error = [NSError errorWithDomain:@"download file is deleted" code:-1 userInfo:nil];
            NSLog(@"完成 移动失败 3");
            return;
        }
    }
    
    NSString * filePath = tuple.downloadTask.fileURL.path;
    if ([[NSFileManager defaultManager] fileExistsAtPath:filePath]) {
        [[NSFileManager defaultManager] removeItemAtPath:filePath error:nil];
    }
    NSError * error;
    [[NSFileManager defaultManager] moveItemAtPath:path toPath:filePath error:&error];
    tuple.downloadTask.error = error;
    if (error) {
        NSLog(@"完成 移动失败 : %@", error);
    } else {
        NSLog(@"完成 : %@", filePath);
    }
}

- (void)URLSession:(NSURLSession *)session downloadTask:(NSURLSessionDownloadTask *)downloadTask didWriteData:(int64_t)bytesWritten totalBytesWritten:(int64_t)totalBytesWritten totalBytesExpectedToWrite:(int64_t)totalBytesExpectedToWrite
{
    SGDownloadTuple * tuple = [self.taskTupleQueue tupleWithSessionTask:downloadTask];
    if (!tuple) return;
    
    [self.taskQueue setTaskState:tuple.downloadTask state:SGDownloadTaskStateRunning];
    [tuple.downloadTask setBytesWritten:bytesWritten
                      totalBytesWritten:totalBytesWritten
              totalBytesExpectedToWrite:totalBytesExpectedToWrite];
    [self.taskQueue archive];
}

- (void)URLSession:(NSURLSession *)session downloadTask:(NSURLSessionDownloadTask *)downloadTask didResumeAtOffset:(int64_t)fileOffset expectedTotalBytes:(int64_t)expectedTotalBytes
{
    SGDownloadTuple * tuple = [self.taskTupleQueue tupleWithSessionTask:downloadTask];
    if (!tuple) return;
    
    [self.taskQueue setTaskState:tuple.downloadTask state:SGDownloadTaskStateRunning];
    tuple.downloadTask.resumeFileOffset = fileOffset;
    tuple.downloadTask.resumeExpectedTotalBytes = expectedTotalBytes;
    [self.taskQueue archive];
}


#pragma mark - Notification

- (void)setupNotification
{
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

- (void)applicationWillTerminate
{
    [self.taskQueue archive];
}

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [self stopRunning];
    NSLog(@"SGDownload release");
}

@end
