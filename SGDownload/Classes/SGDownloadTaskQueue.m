//
//  SGDownloadTaskQueue.m
//  SGDownload
//
//  Created by Single on 2017/3/17.
//  Copyright © 2017年 single. All rights reserved.
//

#import "SGDownloadTaskQueue.h"
#import "SGDownloadImp.h"
#import "SGDownloadTaskPrivate.h"

#if TARGET_OS_OSX
#import <AppKit/AppKit.h>
#elif TARGET_OS_IOS || TARGET_OS_TV
#import <UIKit/UIKit.h>
#endif

@interface SGDownloadTaskQueue ()

@property (nonatomic, copy) NSString * archiverPath;
@property (nonatomic, strong) NSCondition * condition;
@property (nonatomic, assign) BOOL closed;

@end

@implementation SGDownloadTaskQueue

+ (instancetype)queueWithDownload:(SGDownload *)download
{
    return [[self alloc] initWithDownload:download];
}

- (instancetype)initWithDownload:(SGDownload *)download
{
    if (self = [super init]) {
        self->_download = download;
        self->_archiverPath = [SGDownload archiverFilePathWithIdentifier:download.identifier];
        self->_tasks = [NSKeyedUnarchiver unarchiveObjectWithFile:self.archiverPath];
        if (!self->_tasks) {
            self->_tasks = [NSMutableArray array];
        }
        self.condition = [[NSCondition alloc] init];
        [self resetQueue];
        [self setupNotification];
    }
    return self;
}

- (void)resetQueue
{
    [self.condition lock];
    for (SGDownloadTask * obj in self.tasks) {
        obj.download = self.download;
        if (obj.state == SGDownloadTaskStateRunning) {
            obj.state = SGDownloadTaskStateWaiting;
        }
    }
    [self.condition unlock];
    [self archive];
}

- (NSMutableArray <SGDownloadTask *> *)tasksRunningOrWatting
{
    [self.condition lock];
    NSMutableArray * temp = [NSMutableArray array];
    for (SGDownloadTask * obj in self.tasks) {
        if (obj.state == SGDownloadTaskStateRunning || obj.state == SGDownloadTaskStateWaiting) {
            [temp addObject:obj];
        }
    }
    if (temp.count <= 0) {
        temp = nil;
    }
    [self.condition unlock];
    return temp;
}

- (NSMutableArray <SGDownloadTask *> *)tasksWithState:(SGDownloadTaskState)state
{
    [self.condition lock];
    NSMutableArray * temp = [NSMutableArray array];
    for (SGDownloadTask * obj in self.tasks) {
        if (obj.state == state) {
            [temp addObject:obj];
        }
    }
    if (temp.count <= 0) {
        temp = nil;
    }
    [self.condition unlock];
    return temp;
}

- (SGDownloadTask *)taskWithContentURL:(NSURL *)contentURL
{
    if (contentURL.absoluteString.length <= 0) return nil;
    [self.condition lock];
    SGDownloadTask * task = nil;
    for (SGDownloadTask * obj in self.tasks) {
        if ([obj.contentURL.absoluteString isEqualToString:contentURL.absoluteString]) {
            task = obj;
            break;
        }
    }
    [self.condition unlock];
    return task;
}

- (void)setTaskState:(SGDownloadTask *)task state:(SGDownloadTaskState)state
{
    if (!task) return;
    [self.condition lock];
    task.state = state;
    [self.condition unlock];
    [self archive];
}

- (SGDownloadTask *)downloadTaskSync
{
    if (self.closed) return nil;
    [self.condition lock];
    SGDownloadTask * task;
    do {
        for (SGDownloadTask * obj in self.tasks) {
            if (self.closed) {
                [self.condition unlock];
                return nil;
            }
            switch (obj.state) {
                case SGDownloadTaskStateNone:
                case SGDownloadTaskStateWaiting:
                    task = obj;
                    break;
                default:
                    break;
            }
        }
        if (!task) {
            [self.condition wait];
        }
    } while (!task);
    [self.condition unlock];
    return task;
}

- (void)downloadTask:(SGDownloadTask *)task
{
    if (task) {
        [self downloadTasks:@[task]];
    }
}

- (void)downloadTasks:(NSArray <SGDownloadTask *> *)tasks
{
    if (self.closed) return;
    if (tasks.count <= 0) return;
    [self.condition lock];
    BOOL needSignal = NO;
    for (SGDownloadTask * obj in tasks) {
        if (![self.tasks containsObject:obj]) {
            obj.download = self.download;
            [self.tasks addObject:obj];
        }
        switch (obj.state) {
            case SGDownloadTaskStateNone:
            case SGDownloadTaskStateSuspend:
            case SGDownloadTaskStateCanceled:
            case SGDownloadTaskStateFailured:
                obj.state = SGDownloadTaskStateWaiting;
                needSignal = YES;
                break;
            default:
                break;
        }
    }
    if (needSignal) {
        [self.condition signal];
    }
    [self.condition unlock];
    [self archive];
}

- (void)addSuppendTask:(SGDownloadTask *)task
{
    if (task) {
        [self addSuppendTasks:@[task]];
    }
}

- (void)addSuppendTasks:(NSArray <SGDownloadTask *> *)tasks
{
    if (tasks.count <= 0) return;
    [self.condition lock];
    for (SGDownloadTask * obj in tasks) {
        if (![self.tasks containsObject:obj]) {
            [self.tasks addObject:obj];
        }
        switch (obj.state) {
            case SGDownloadTaskStateNone:
            case SGDownloadTaskStateWaiting:
            case SGDownloadTaskStateRunning:
                obj.state = SGDownloadTaskStateSuspend;
                break;
            default:
                break;
        }
    }
    [self.condition unlock];
    [self archive];
}

- (void)resumeAllTasks
{
    [self resumeTasks:self.tasks];
}

- (void)resumeTask:(SGDownloadTask *)task
{
    if (task) {
        [self resumeTasks:@[task]];
    }
}

- (void)resumeTasks:(NSArray<SGDownloadTask *> *)tasks
{
    if (self.closed) return;
    if (tasks.count <= 0) return;
    [self.condition lock];
    BOOL needSignal = NO;
    for (SGDownloadTask * task in tasks) {
        switch (task.state) {
            case SGDownloadTaskStateNone:
            case SGDownloadTaskStateSuspend:
            case SGDownloadTaskStateCanceled:
            case SGDownloadTaskStateFailured:
                task.state = SGDownloadTaskStateWaiting;
                needSignal = YES;
                break;
            default:
                break;
        }
    }
    if (needSignal) {
        [self.condition signal];
    }
    [self.condition unlock];
    [self archive];
}

- (void)suspendAllTasks
{
    [self suspendTasks:self.tasks];
}

- (void)suspendTask:(SGDownloadTask *)task
{
    if (task) {
        [self suspendTasks:@[task]];
    }
}

- (void)suspendTasks:(NSArray<SGDownloadTask *> *)tasks
{
    if (tasks.count <= 0) return;
    [self.condition lock];
    for (SGDownloadTask * task in tasks) {
        switch (task.state) {
            case SGDownloadTaskStateNone:
            case SGDownloadTaskStateWaiting:
            case SGDownloadTaskStateRunning:
                task.state = SGDownloadTaskStateSuspend;
                break;
            default:
                break;
        }
    }
    [self.condition unlock];
    [self archive];
}

- (void)cancelAllTasks
{
    [self cancelTasks:self.tasks];
}

- (void)cancelTask:(SGDownloadTask *)task
{
    if (task) {
        [self cancelTasks:@[task]];
    }
}

- (void)cancelTasks:(NSArray<SGDownloadTask *> *)tasks
{
    if (tasks.count <= 0) return;
    [self.condition lock];
    NSMutableArray <SGDownloadTask *> * temp = [NSMutableArray array];
    for (SGDownloadTask * task in tasks) {
        if ([self.tasks containsObject:task]) {
            task.state = SGDownloadTaskStateCanceled;
            [temp addObject:task];
        }
    }
    for (SGDownloadTask * task in temp) {
        task.download = nil;
        [self.tasks removeObject:task];
    }
    [self.condition unlock];
    [self archive];
}

- (void)archive
{
    [self.condition lock];
    [NSKeyedArchiver archiveRootObject:self.tasks toFile:self.archiverPath];
    [self.condition unlock];
}

- (void)invalidate
{
    if (self.closed) return;
    
    [self.condition lock];
    self.closed = YES;
    for (SGDownloadTask * task in self.tasks) {
        switch (task.state) {
            case SGDownloadTaskStateRunning:
                task.state = SGDownloadTaskStateWaiting;
                break;
            default:
                break;
        }
    }
    [self.condition broadcast];
    [self.condition unlock];
    [self archive];
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
    [self archive];
}

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [self invalidate];
}

@end
