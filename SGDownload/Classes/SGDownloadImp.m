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

#import <TargetConditionals.h>
#if TARGET_OS_OSX
#import <AppKit/AppKit.h>
#elif TARGET_OS_IOS || TARGET_OS_TV
#import <UIKit/UIKit.h>
#endif

NSString * const SGDownloadDefaultIdentifier = @"SGDownloadDefaultIdentifier";

@interface SGDownload () <NSURLSessionDownloadDelegate>

@property (nonatomic, strong) NSOperationQueue * downloadOperationQueue;
@property (nonatomic, strong) NSInvocationOperation * downloadOperation;

@property (nonatomic, strong) NSURLSession * session;
@property (nonatomic, strong) NSOperationQueue * sessionDelegateQueue;

@property (nonatomic, strong) NSCondition * condition;
@property (nonatomic, strong) SGDownloadTaskQueue * taskQueue;
@property (nonatomic, assign) SGDownloadTask * currentDownloadTask;
@property (nonatomic, assign) NSURLSessionDownloadTask * currrentSessionTask;

@property (nonatomic, assign) BOOL closed;

@end

@implementation SGDownload

+ (instancetype)download
{
    return [self downloadWithIdentifier:SGDownloadDefaultIdentifier];
}

+ (instancetype)downloadWithIdentifier:(NSString *)identifier
{
    static NSMutableArray <SGDownload *> * downloads = nil;
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
        [self setupOperation];
        [self setupNotification];
    }
    return self;
}

- (void)setupOperation
{
    self.taskQueue = [SGDownloadTaskQueue queueWithIdentifier:self.identifier];
    self.condition = [[NSCondition alloc] init];
    
    self.sessionDelegateQueue = [[NSOperationQueue alloc] init];
    self.sessionDelegateQueue.maxConcurrentOperationCount = 1;
    self.sessionDelegateQueue.qualityOfService = NSQualityOfServiceUserInteractive;
    self.session = [NSURLSession sessionWithConfiguration:[NSURLSessionConfiguration defaultSessionConfiguration]
                                                 delegate:self
                                            delegateQueue:self.sessionDelegateQueue];
    
    self.downloadOperation = [[NSInvocationOperation alloc] initWithTarget:self selector:@selector(downloadOperationHandler) object:nil];
    self.downloadOperationQueue = [[NSOperationQueue alloc] init];
    self.downloadOperationQueue.maxConcurrentOperationCount = 1;
    self.downloadOperationQueue.qualityOfService = NSQualityOfServiceUserInteractive;
    [self.downloadOperationQueue addOperation:self.downloadOperation];
}

- (void)downloadOperationHandler
{
    while (YES) {
        if (self.closed) {
            break;
        }
        self.currentDownloadTask = [self.taskQueue downloadTaskSync];
        if (!self.currentDownloadTask) {
            break;
        }
        self.currentDownloadTask.state = SGDownloadTaskStateRunning;
        
        if (self.currentDownloadTask.resumeInfoData.length > 0) {
            self.currrentSessionTask = [self.session downloadTaskWithResumeData:self.currentDownloadTask.resumeInfoData];
        } else {
            self.currrentSessionTask = [self.session downloadTaskWithURL:self.currentDownloadTask.contentURL];
        }
        [self.currrentSessionTask resume];
        [self.taskQueue threadBlock];
    }
}

- (void)invalidate
{
    if (self.closed) return;
    
    self.closed = YES;
    if (self.currentDownloadTask && self.currrentSessionTask) {
        [self cancelCurrentSessionTaskResume:YES];
    }
    [self.taskQueue invalidate];
    [self.session invalidateAndCancel];
    [self.downloadOperationQueue cancelAllOperations];
    self.downloadOperation = nil;
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
    [self cancelCurrentSessionTaskResume:YES];
}

- (void)suspendTask:(SGDownloadTask *)task
{
    [self.taskQueue suspendTask:task];
    if (self.currentDownloadTask == task) {
        [self cancelCurrentSessionTaskResume:YES];
    }
}

- (void)suspendTasks:(NSArray<SGDownloadTask *> *)tasks
{
    [self.taskQueue suspendTasks:tasks];
    if ([tasks containsObject:self.currentDownloadTask]) {
        [self cancelCurrentSessionTaskResume:YES];
    }
}

- (void)cancelAllTasks
{
    [self.taskQueue cancelAllTasks];
    [self cancelCurrentSessionTaskResume:NO];
}

- (void)cancelTask:(SGDownloadTask *)task
{
    [self.taskQueue cancelTask:task];
    if (self.currentDownloadTask == task) {
        [self cancelCurrentSessionTaskResume:NO];
    }
}

- (void)cancelTasks:(NSArray <SGDownloadTask *> *)tasks
{
    [self.taskQueue cancelTasks:tasks];
    if ([tasks containsObject:self.currentDownloadTask]) {
        [self cancelCurrentSessionTaskResume:NO];
    }
}

- (void)cancelCurrentSessionTaskResume:(BOOL)resume
{
    if (!self.currrentSessionTask) return;
    if (resume) {
        [self.condition lock];
        __weak typeof(self) weakSelf = self;
        [self.currrentSessionTask cancelByProducingResumeData:^(NSData * _Nullable resumeData) {
            __strong typeof(weakSelf) strongSelf = weakSelf;
            strongSelf.currentDownloadTask.resumeInfoData = resumeData;
            [strongSelf.condition signal];
        }];
        [self.condition wait];
        [self.condition unlock];
    } else {
        [self.currrentSessionTask cancel];
    }
}

- (NSArray <SGDownloadTask *> *)tasks
{
    return self.taskQueue.tasks;
}


#pragma mark - NSURLSessionDownloadDelegate

- (void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task didCompleteWithError:(NSError *)error
{
    if (self.currrentSessionTask == task || self.currentDownloadTask.state == SGDownloadTaskStateRunning) {
        if (error) {
            if (error.code == NSURLErrorCancelled) {
                self.currentDownloadTask.state = SGDownloadTaskStateSuspend;
            } else {
                self.currentDownloadTask.state = SGDownloadTaskStateFaiulred;
                self.currentDownloadTask.error = error;
                if ([self.delegate respondsToSelector:@selector(download:task:didFailuredWithError:)]) {
                    [self.delegate download:self task:self.currentDownloadTask didFailuredWithError:error];
                }
            }
        } else {
            self.currentDownloadTask.state = SGDownloadTaskStateFinished;
            if ([self.delegate respondsToSelector:@selector(download:taskDidFinished:)]) {
                [self.delegate download:self taskDidFinished:self.currentDownloadTask];
            }
        }
    }
    [self.taskQueue threadResume];
}

- (void)URLSession:(NSURLSession *)session downloadTask:(NSURLSessionDownloadTask *)downloadTask didFinishDownloadingToURL:(NSURL *)location
{
    if (self.currrentSessionTask == downloadTask) {
        NSError * error;
        [[NSFileManager defaultManager] moveItemAtURL:location toURL:self.currentDownloadTask.fileURL error:&error];
        self.currentDownloadTask.error = error;
    }
}

- (void)URLSession:(NSURLSession *)session downloadTask:(NSURLSessionDownloadTask *)downloadTask didWriteData:(int64_t)bytesWritten totalBytesWritten:(int64_t)totalBytesWritten totalBytesExpectedToWrite:(int64_t)totalBytesExpectedToWrite
{
    if (self.currrentSessionTask == downloadTask) {
        self.currentDownloadTask.bytesWritten = bytesWritten;
        self.currentDownloadTask.totalBytesWritten = totalBytesWritten;
        self.currentDownloadTask.totalBytesExpectedToWrite = totalBytesExpectedToWrite;
        if ([self.delegate respondsToSelector:@selector(download:task:didWriteData:totalBytesWritten:totalBytesExpectedToWrite:)]) {
            [self.delegate download:self
                               task:self.currentDownloadTask
                       didWriteData:self.currentDownloadTask.bytesWritten
                  totalBytesWritten:self.currentDownloadTask.totalBytesWritten
          totalBytesExpectedToWrite:self.currentDownloadTask.totalBytesExpectedToWrite];
        }
    }
}

- (void)URLSession:(NSURLSession *)session downloadTask:(NSURLSessionDownloadTask *)downloadTask didResumeAtOffset:(int64_t)fileOffset expectedTotalBytes:(int64_t)expectedTotalBytes
{
    if (self.currrentSessionTask == downloadTask) {
        self.currentDownloadTask.resumeFileOffset = fileOffset;
        self.currentDownloadTask.resumeExpectedTotalBytes = expectedTotalBytes;
    }
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
    [self invalidate];
}

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [self invalidate];
}

@end
