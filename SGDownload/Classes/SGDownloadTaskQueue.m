//
//  SGDownloadTaskQueue.m
//  SGDownload
//
//  Created by Single on 2017/3/17.
//  Copyright © 2017年 single. All rights reserved.
//

#import "SGDownloadTaskQueue.h"
#import "SGDownloadTask.h"

@interface SGDownloadTaskQueue ()

@property (nonatomic, copy) NSString * archiverPath;
@property (nonatomic, strong) NSCondition * condition;
@property (nonatomic, assign) BOOL closed;

@end

@implementation SGDownloadTaskQueue

+ (instancetype)queueWithIdentifier:(NSString *)identifier
{
    return [[self alloc] initWithIdentifier:identifier];
}

+ (NSString *)archiverPathWithIdentifier:(NSString *)identifier
{
    return [NSHomeDirectory() stringByAppendingPathComponent:[NSString stringWithFormat:@"Documents/%@.SGDownloadArchiver", identifier]];
}

- (instancetype)initWithIdentifier:(NSString *)identifier
{
    if (self = [super init]) {
        self->_identifier = identifier;
        self->_archiverPath = [self.class archiverPathWithIdentifier:identifier];
        self->_tasks = [NSKeyedUnarchiver unarchiveObjectWithFile:self.archiverPath];
        if (!self->_tasks) {
            self->_tasks = [NSMutableArray array];
        }
        self.condition = [[NSCondition alloc] init];
    }
    return self;
}

- (SGDownloadTask *)taskWithContentURL:(NSURL *)contentURL
{
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

- (SGDownloadTask *)downloadTaskSync
{
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
    if (tasks.count <= 0) return;
    [self.condition lock];
    if (self.closed) {
        [self.condition unlock];
        return;
    }
    BOOL needSignal = NO;
    for (SGDownloadTask * obj in tasks) {
        if (![self.tasks containsObject:obj]) {
            [self.tasks addObject:obj];
        }
        switch (obj.state) {
            case SGDownloadTaskStateNone:
            case SGDownloadTaskStateSuspend:
            case SGDownloadTaskStateCanceled:
            case SGDownloadTaskStateFaiulred:
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
    [self.condition lock];
    if (self.closed) {
        [self.condition unlock];
        return;
    }
    BOOL needSignal = NO;
    for (SGDownloadTask * task in tasks) {
        switch (task.state) {
            case SGDownloadTaskStateNone:
            case SGDownloadTaskStateSuspend:
            case SGDownloadTaskStateCanceled:
            case SGDownloadTaskStateFaiulred:
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
    [self.condition lock];
    if (self.closed) {
        [self.condition unlock];
        return;
    }
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
    [self.condition lock];
    if (self.closed) {
        [self.condition unlock];
        return;
    }
    NSMutableArray <SGDownloadTask *> * temp = [NSMutableArray array];
    for (SGDownloadTask * task in tasks) {
        if ([self.tasks containsObject:task]) {
            task.state = SGDownloadTaskStateCanceled;
            [temp addObject:task];
        }
    }
    for (SGDownloadTask * task in temp) {
        [self.tasks removeObject:task];
    }
    [self.condition unlock];
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
}

- (void)dealloc
{
    NSLog(@"SGDownloadTaskQueue release");
}

@end
