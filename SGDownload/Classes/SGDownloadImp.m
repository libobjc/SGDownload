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
#import "SGDownloadConfiguration.h"

#import <TargetConditionals.h>
#if TARGET_OS_OSX
#import <AppKit/AppKit.h>
#elif TARGET_OS_IOS || TARGET_OS_TV
#import <UIKit/UIKit.h>
#endif

NSString * const SGDownloadDefaultIdentifier = @"SGDownloadDefaultIdentifier";

@interface SGDownload () <NSURLSessionDownloadDelegate>

@property (nonatomic, strong) NSURLSession * session;

@property (nonatomic, strong) SGDownloadTaskQueue * taskQueue;
@property (nonatomic, strong) SGDownloadTupleQueue * taskTupleQueue;
@property (nonatomic, strong) dispatch_semaphore_t concurrentSemaphore;

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
    return [self downloadWithConfiguration:[SGDownloadConfiguration defaultConfiguration] identifier:identifier];
}

+ (instancetype)downloadWithConfiguration:(SGDownloadConfiguration *)configuration
{
    return [self downloadWithConfiguration:configuration identifier:SGDownloadDefaultIdentifier];
}

+ (instancetype)downloadWithConfiguration:(SGDownloadConfiguration *)configuration identifier:(NSString *)identifier
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
    SGDownload * obj = [[self alloc] initWithConfiguration:configuration identifier:identifier];
    [downloads addObject:obj];
    return obj;
}

- (instancetype)initWithConfiguration:(SGDownloadConfiguration *)configuration identifier:(NSString *)identifier
{
    if (self = [super init]) {
        self->_configuration = configuration;
        self->_identifier = identifier;
        [self setupOperation];
        [self setupNotification];
    }
    return self;
}

- (void)setupOperation
{
    self.session = [NSURLSession sessionWithConfiguration:self.configuration.sessionConfiguration
                                                 delegate:self
                                            delegateQueue:self.configuration.delegateQueue];
    
    self.taskQueue = [SGDownloadTaskQueue queueWithIdentifier:self.identifier];
    self.taskTupleQueue = [[SGDownloadTupleQueue alloc] init];
    long count;
    if (self.configuration.maxConcurrentOperationCount <= 0) {
        count = 0;
    } else {
        count = self.configuration.maxConcurrentOperationCount - 1;
    }
    self.concurrentSemaphore = dispatch_semaphore_create(count);
    
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
            NSLog(@"等待 dispatch_semaphore_wait");
            dispatch_semaphore_wait(self.concurrentSemaphore, DISPATCH_TIME_FOREVER);
            NSLog(@"等待 dispatch_semaphore_wait 完成");
        }
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
        dispatch_semaphore_signal(self.concurrentSemaphore);
        [downloads removeObject:self];
    }];
}

- (void)invalidateSync
{
    if (self.closed) return;
    
    self.closed = YES;
    [self.taskQueue invalidate];
    [self.taskTupleQueue cancelAllResumeSync];
    [self.taskQueue archive];
    [self.session invalidateAndCancel];
    [self.downloadOperationQueue cancelAllOperations];
    self.downloadOperation = nil;
    dispatch_semaphore_signal(self.concurrentSemaphore);
    [downloads removeObject:self];
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

- (void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task didCompleteWithError:(NSError *)error
{
    SGDownloadTuple * tuple = [self.taskTupleQueue tupleWithSessionTask:(NSURLSessionDownloadTask *)task];
    if (!tuple) return;
    
    if (error) {
        if (error.code == NSURLErrorCancelled) {
            tuple.downlaodTask.state = SGDownloadTaskStateSuspend;
        } else {
            tuple.downlaodTask.state = SGDownloadTaskStateFaiulred;
            tuple.downlaodTask.error = error;
            if ([self.delegate respondsToSelector:@selector(download:task:didFailuredWithError:)]) {
                [self.delegate download:self task:tuple.downlaodTask didFailuredWithError:error];
            }
        }
    } else {
        tuple.downlaodTask.state = SGDownloadTaskStateFinished;
        [self.taskTupleQueue finishTuple:tuple];
        if ([self.delegate respondsToSelector:@selector(download:taskDidFinished:)]) {
            [self.delegate download:self taskDidFinished:tuple.downlaodTask];
        }
    }
    NSLog(@"唤醒 dispatch_semaphore_signal");
    dispatch_semaphore_signal(self.concurrentSemaphore);
    NSLog(@"唤醒 dispatch_semaphore_signal 完成");
}

- (void)URLSession:(NSURLSession *)session downloadTask:(NSURLSessionDownloadTask *)downloadTask didFinishDownloadingToURL:(NSURL *)location
{
    SGDownloadTuple * tuple = [self.taskTupleQueue tupleWithSessionTask:downloadTask];
    if (!tuple) return;
    
    NSError * error;
    [[NSFileManager defaultManager] moveItemAtURL:location toURL:tuple.downlaodTask.fileURL error:&error];
    tuple.downlaodTask.error = error;
    NSLog(@"完成 : %@", tuple.downlaodTask.fileURL);
}

- (void)URLSession:(NSURLSession *)session downloadTask:(NSURLSessionDownloadTask *)downloadTask didWriteData:(int64_t)bytesWritten totalBytesWritten:(int64_t)totalBytesWritten totalBytesExpectedToWrite:(int64_t)totalBytesExpectedToWrite
{
    SGDownloadTuple * tuple = [self.taskTupleQueue tupleWithSessionTask:downloadTask];
    if (!tuple) return;
    
    tuple.downlaodTask.bytesWritten = bytesWritten;
    tuple.downlaodTask.totalBytesWritten = totalBytesWritten;
    tuple.downlaodTask.totalBytesExpectedToWrite = totalBytesExpectedToWrite;
    if ([self.delegate respondsToSelector:@selector(download:task:didWriteData:totalBytesWritten:totalBytesExpectedToWrite:)]) {
        [self.delegate download:self
                           task:tuple.downlaodTask
                   didWriteData:tuple.downlaodTask.bytesWritten
              totalBytesWritten:tuple.downlaodTask.totalBytesWritten
      totalBytesExpectedToWrite:tuple.downlaodTask.totalBytesExpectedToWrite];
    }
}

- (void)URLSession:(NSURLSession *)session downloadTask:(NSURLSessionDownloadTask *)downloadTask didResumeAtOffset:(int64_t)fileOffset expectedTotalBytes:(int64_t)expectedTotalBytes
{
    SGDownloadTuple * tuple = [self.taskTupleQueue tupleWithSessionTask:downloadTask];
    if (!tuple) return;
    
    tuple.downlaodTask.resumeFileOffset = fileOffset;
    tuple.downlaodTask.resumeExpectedTotalBytes = expectedTotalBytes;
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
    [self invalidateSync];
}

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [self invalidate];
    NSLog(@"SGDownload release");
}

@end
