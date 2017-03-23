//
//  SGDownloadImp.m
//  SGDownload
//
//  Created by Single on 2017/3/17.
//  Copyright © 2017年 single. All rights reserved.
//

#import "SGDownloadImp.h"
#import "SGDownloadTask.h"
#import "SGDownloadTaskQueue.h"
#import "SGDownloadTuple.h"
#import "SGDownloadTupleQueue.h"
#import "SGDownloadTools.h"

#import <TargetConditionals.h>
#if TARGET_OS_OSX
#import <AppKit/AppKit.h>
#elif TARGET_OS_IOS || TARGET_OS_TV
#import <UIKit/UIKit.h>
#endif

NSString * const SGDownloadDefaultIdentifier = @"SGDownloadDefaultIdentifier";

@interface SGDownload () <NSURLSessionDownloadDelegate>

@property (nonatomic, strong) NSURLSession * session;
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
    
    self.downloadOperation = [[NSInvocationOperation alloc] initWithTarget:self selector:@selector(downloadOperationHandler) object:nil];
    self.downloadOperationQueue = [[NSOperationQueue alloc] init];
    self.downloadOperationQueue.maxConcurrentOperationCount = 1;
    self.downloadOperationQueue.qualityOfService = NSQualityOfServiceUserInteractive;
    
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [self.downloadOperationQueue addOperation:self.downloadOperation];
    });
}

- (void)downloadOperationHandler
{
    while (YES) {
        @autoreleasepool
        {
            if (self.closed) {
                break;
            }
            NSLog(@"调用 downloadTaskSync");
            SGDownloadTask * downloadTask = [self.taskQueue downloadTaskSync];
            if (!downloadTask) {
                break;
            }
            NSLog(@"调用 downloadTaskSync 完成");
            downloadTask.state = SGDownloadTaskStateRunning;
            
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
            NSLog(@"等待 dispatch_semaphore_wait");
            dispatch_semaphore_wait(self.concurrentSemaphore, DISPATCH_TIME_FOREVER);
            NSLog(@"等待 dispatch_semaphore_wait 完成");
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
    NSLog(@"URLSessionDidFinishEventsForBackgroundURLSession");
    if (self.backgroundCompletionHandler) {
        self.backgroundCompletionHandler();
    }
}

- (void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task didCompleteWithError:(NSError *)error
{
    SGDownloadTuple * tuple = [self.taskTupleQueue tupleWithSessionTask:(NSURLSessionDownloadTask *)task];
    if (tuple)
    {
        if (error) {
            NSData * resumeData = [error.userInfo objectForKey:NSURLSessionDownloadTaskResumeData];
            if (resumeData) {
                tuple.downloadTask.resumeInfoData = resumeData;
            }
            if (error.code == NSURLErrorCancelled) {
                tuple.downloadTask.state = SGDownloadTaskStateSuspend;
            } else {
                tuple.downloadTask.error = error;
                tuple.downloadTask.state = SGDownloadTaskStateFailured;
                if ([self.delegate respondsToSelector:@selector(download:task:didFailuredWithError:)]) {
                    [self.delegate download:self task:tuple.downloadTask didFailuredWithError:error];
                }
            }
        } else {
            if (![[NSFileManager defaultManager] fileExistsAtPath:tuple.downloadTask.fileURL.path]) {
                tuple.downloadTask.error = [NSError errorWithDomain:@"download file is deleted" code:-1 userInfo:nil];
                tuple.downloadTask.state = SGDownloadTaskStateFailured;
                if ([self.delegate respondsToSelector:@selector(download:task:didFailuredWithError:)]) {
                    [self.delegate download:self task:tuple.downloadTask didFailuredWithError:error];
                }
            } else {
                tuple.downloadTask.state = SGDownloadTaskStateFinished;
                if ([self.delegate respondsToSelector:@selector(download:taskDidFinished:)]) {
                    [self.delegate download:self taskDidFinished:tuple.downloadTask];
                }
            }
        }
        [self.taskTupleQueue removeTuple:tuple];
        NSLog(@"唤醒 dispatch_semaphore_signal");
        dispatch_semaphore_signal(self.concurrentSemaphore);
        NSLog(@"唤醒 dispatch_semaphore_signal 完成");
    }
    else
    {
        SGDownloadTask * downloadTask = [self.taskQueue taskWithContentURL:task.currentRequest.URL];
        if (!downloadTask) return;
        
        if (error) {
            NSData * resumeData = [error.userInfo objectForKey:NSURLSessionDownloadTaskResumeData];
            if (resumeData) {
                downloadTask.resumeInfoData = resumeData;
            }
            if (error.code == NSURLErrorCancelled) {
                downloadTask.state = SGDownloadTaskStateWaiting;
            } else {
                downloadTask.error = error;
                downloadTask.state = SGDownloadTaskStateFailured;
            }
        } else {
            if (![[NSFileManager defaultManager] fileExistsAtPath:downloadTask.fileURL.path]) {
                downloadTask.error = [NSError errorWithDomain:@"download file is deleted" code:-1 userInfo:nil];
                downloadTask.state = SGDownloadTaskStateFailured;
            } else {
                downloadTask.state = SGDownloadTaskStateFinished;
            }
        }
    }
    [self.taskQueue archive];
}

- (void)URLSession:(NSURLSession *)session downloadTask:(NSURLSessionDownloadTask *)downloadTask didFinishDownloadingToURL:(NSURL *)location
{
    SGDownloadTask * obj = nil;
    SGDownloadTuple * tuple = [self.taskTupleQueue tupleWithSessionTask:downloadTask];
    if (tuple) {
        obj = tuple.downloadTask;
    } else {
        obj = [self.taskQueue taskWithContentURL:downloadTask.currentRequest.URL];
    }
    if (!obj) return;
    
    NSString * path = location.path;
    BOOL exists = [[NSFileManager defaultManager] fileExistsAtPath:path];
    if (!exists) {
        path = [SGDownloadTools replacehHomeDirectoryForFilePath:path];
        exists = [[NSFileManager defaultManager] fileExistsAtPath:path];
        if (!exists) {
            obj.error = [NSError errorWithDomain:@"download file is deleted" code:-1 userInfo:nil];
            NSLog(@"完成 移动失败 3");
            return;
        }
    }
    
    NSString * filePath = obj.fileURL.path;
    if ([[NSFileManager defaultManager] fileExistsAtPath:filePath]) {
        [[NSFileManager defaultManager] removeItemAtPath:filePath error:nil];
    }
    NSError * error;
    [[NSFileManager defaultManager] moveItemAtPath:path toPath:filePath error:&error];
    obj.error = error;
    if (error) {
        NSLog(@"完成 移动失败 : %@", error);
    } else {
        NSLog(@"完成 : %@", obj.fileURL);
    }
}

- (void)URLSession:(NSURLSession *)session downloadTask:(NSURLSessionDownloadTask *)downloadTask didWriteData:(int64_t)bytesWritten totalBytesWritten:(int64_t)totalBytesWritten totalBytesExpectedToWrite:(int64_t)totalBytesExpectedToWrite
{
    SGDownloadTuple * tuple = [self.taskTupleQueue tupleWithSessionTask:downloadTask];
    if (!tuple) return;
    
    tuple.downloadTask.bytesWritten = bytesWritten;
    tuple.downloadTask.totalBytesWritten = totalBytesWritten;
    tuple.downloadTask.totalBytesExpectedToWrite = totalBytesExpectedToWrite;
    if ([self.delegate respondsToSelector:@selector(download:task:didWriteData:totalBytesWritten:totalBytesExpectedToWrite:)]) {
        [self.delegate download:self
                           task:tuple.downloadTask
                   didWriteData:tuple.downloadTask.bytesWritten
              totalBytesWritten:tuple.downloadTask.totalBytesWritten
      totalBytesExpectedToWrite:tuple.downloadTask.totalBytesExpectedToWrite];
    }
}

- (void)URLSession:(NSURLSession *)session downloadTask:(NSURLSessionDownloadTask *)downloadTask didResumeAtOffset:(int64_t)fileOffset expectedTotalBytes:(int64_t)expectedTotalBytes
{
    SGDownloadTuple * tuple = [self.taskTupleQueue tupleWithSessionTask:downloadTask];
    if (!tuple) return;
    
    tuple.downloadTask.resumeFileOffset = fileOffset;
    tuple.downloadTask.resumeExpectedTotalBytes = expectedTotalBytes;
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
