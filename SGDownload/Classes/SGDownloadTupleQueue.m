//
//  SGDownloadTupleQueue.m
//  SGDownload
//
//  Created by Single on 2017/3/21.
//  Copyright © 2017年 single. All rights reserved.
//

#import "SGDownloadTupleQueue.h"
#import "SGDownloadTask.h"
#import "SGDownloadTaskPrivate.h"
#import "SGDownloadTuple.h"

@interface SGDownloadTupleQueue ()

@property (nonatomic, strong) NSLock * tupleLock;

@end

@implementation SGDownloadTupleQueue

- (instancetype)init
{
    if (self = [super init]) {
        self->_tuples = [NSMutableArray array];
        self.tupleLock = [[NSLock alloc] init];
    }
    return self;
}

- (SGDownloadTuple *)tupleWithDownloadTask:(SGDownloadTask *)downloadTask
{
    [self.tupleLock lock];
    SGDownloadTuple * tuple = nil;
    for (SGDownloadTuple * obj in self.tuples) {
        if (obj.downloadTask == downloadTask) {
            tuple = obj;
            break;
        }
    }
    [self.tupleLock unlock];
    return tuple;
}

- (NSArray<SGDownloadTuple *> *)tuplesWithDownloadTasks:(NSArray<SGDownloadTask *> *)downloadTasks
{
    [self.tupleLock lock];
    NSMutableArray * temp = [NSMutableArray array];
    for (SGDownloadTuple * obj in self.tuples) {
        if ([downloadTasks containsObject:obj.downloadTask]) {
            [temp addObject:obj];
        }
    }
    [self.tupleLock unlock];
    if (temp.count > 0) {
        return temp;
    } else {
        return nil;
    }
}

- (SGDownloadTuple *)tupleWithDownloadTask:(SGDownloadTask *)downloadTask sessionTask:(NSURLSessionDownloadTask *)sessionTask
{
    if (!downloadTask) {
        return nil;
    }
    SGDownloadTuple * tuple = [self tupleWithDownloadTask:downloadTask];
    if (tuple) {
        return tuple;
    }
    [self.tupleLock lock];
    tuple = [SGDownloadTuple tupleWithDownloadTask:downloadTask sessionTask:sessionTask];
    [self.tuples addObject:tuple];
    [self.tupleLock unlock];
    return tuple;
}

- (void)addTuple:(SGDownloadTuple *)tuple
{
    [self.tupleLock lock];
    if (![self.tuples containsObject:tuple]) {
        [self.tuples addObject:tuple];
    }
    [self.tupleLock unlock];
}

- (void)removeTupleWithSesstionTask:(NSURLSessionTask *)sessionTask
{
    if (!sessionTask) return;
    
    [self.tupleLock lock];
    SGDownloadTuple * tuple = nil;
    for (SGDownloadTuple * obj in self.tuples) {
        if (obj.sessionTask == sessionTask) {
            tuple = obj;
            break;
        }
    }
    if (tuple) {
        [self.tuples removeObject:tuple];
    }
    [self.tupleLock unlock];
}

- (void)removeTuple:(SGDownloadTuple *)tuple
{
    if (tuple) {
        [self removeTuples:@[tuple]];
    }
}

- (void)removeTuples:(NSArray<SGDownloadTuple *> *)tuples
{
    if (tuples.count <= 0) return;
    [self.tupleLock lock];
    if (self.tuples == tuples) {
        [self.tuples removeAllObjects];
    } else {
        for (SGDownloadTuple * obj in tuples) {
            if ([self.tuples containsObject:obj]) {
                [self.tuples removeObject:obj];
            }
        }
    }
    [self.tupleLock unlock];
}

- (void)cancelDownloadTask:(SGDownloadTask *)downloadTask resume:(BOOL)resume completionHandler:(void(^)(SGDownloadTuple * tuple))completionHandler
{
    SGDownloadTuple * tuple = [self tupleWithDownloadTask:downloadTask];
    [self cancelTuple:tuple resume:resume completionHandler:completionHandler];
}

- (void)cancelDownloadTasks:(NSArray <SGDownloadTask *> *)downloadTasks resume:(BOOL)resume completionHandler:(void(^)(NSArray <SGDownloadTuple *> * tuples))completionHandler
{
    NSArray <SGDownloadTuple *> * tuples = [self tuplesWithDownloadTasks:downloadTasks];
    [self cancelTuples:tuples resume:resume completionHandler:completionHandler];
}

- (void)cancelAllTupleResume:(BOOL)resume completionHandler:(void(^)(NSArray <SGDownloadTuple *> * tuples))completionHandler
{
    [self cancelTuples:self.tuples resume:resume completionHandler:completionHandler];
}

- (void)cancelTuple:(SGDownloadTuple *)tuple resume:(BOOL)resume completionHandler:(void(^)(SGDownloadTuple * tuple))completionHandler
{
    if (tuple) {
        [self cancelTuples:@[tuple] resume:resume completionHandler:^(NSArray<SGDownloadTuple *> * tuples) {
            if (completionHandler && tuples.firstObject) {
                completionHandler(tuples.firstObject);
            }
        }];
    } else {
        if (completionHandler) {
            completionHandler(nil);
        }
    }
}

- (void)cancelTuples:(NSArray <SGDownloadTuple *> *)tuples resume:(BOOL)resume completionHandler:(void(^)(NSArray <SGDownloadTuple *> * tuples))completionHandler
{
    [self.tupleLock lock];
    if (tuples.count <= 0) {
        if (completionHandler) {
            completionHandler(nil);
        }
        [self.tupleLock unlock];
        return;
    }
    if (resume) {
        dispatch_group_t group = dispatch_group_create();
        for (SGDownloadTuple * obj in tuples) {
            if (obj.sessionTask.state == NSURLSessionTaskStateRunning || obj.sessionTask.state == NSURLSessionTaskStateSuspended) {
                dispatch_group_enter(group);
                [obj.sessionTask cancelByProducingResumeData:^(NSData * _Nullable resumeData) {
                    obj.downloadTask.resumeInfoData = resumeData;
                    dispatch_group_leave(group);
                }];
            }
        }
        dispatch_queue_t queue = [[NSOperationQueue currentQueue] underlyingQueue];
        dispatch_group_notify(group, queue, ^{
            if (completionHandler) {
                completionHandler(tuples);
            }
        });
    } else {
        for (SGDownloadTuple * obj in tuples) {
            [obj.sessionTask cancel];
        }
        if (completionHandler) {
            completionHandler(tuples);
        }
    }
    [self.tupleLock unlock];
}

@end
