//
//  SGDownloadTupleQueue.h
//  SGDownload
//
//  Created by Single on 2017/3/21.
//  Copyright © 2017年 single. All rights reserved.
//

#import <Foundation/Foundation.h>
@class SGDownloadTask;
@class SGDownloadTuple;

@interface SGDownloadTupleQueue : NSObject

@property (nonatomic, strong, readonly) NSMutableArray * tuples;

- (SGDownloadTuple *)tupleWithDownloadTask:(SGDownloadTask *)downloadTask;
- (NSArray <SGDownloadTuple *> *)tuplesWithDownloadTasks:(NSArray <SGDownloadTask *> *)downloadTasks;
- (SGDownloadTuple *)tupleWithDownloadTask:(SGDownloadTask *)downloadTask sessionTask:(NSURLSessionDownloadTask *)sessionTask;

- (void)addTuple:(SGDownloadTuple *)tuple;
- (void)removeTupleWithSesstionTask:(NSURLSessionTask *)sessionTask;
- (void)removeTuple:(SGDownloadTuple *)tuple;
- (void)removeTuples:(NSArray <SGDownloadTuple *> *)tuples;

- (void)cancelDownloadTask:(SGDownloadTask *)downloadTask resume:(BOOL)resume completionHandler:(void(^)(SGDownloadTuple * tuple))completionHandler;
- (void)cancelDownloadTasks:(NSArray <SGDownloadTask *> *)downloadTasks resume:(BOOL)resume completionHandler:(void(^)(NSArray <SGDownloadTuple *> * tuples))completionHandler;

- (void)cancelAllTupleResume:(BOOL)resume completionHandler:(void(^)(NSArray <SGDownloadTuple *> * tuples))completionHandler;
- (void)cancelTuple:(SGDownloadTuple *)tuple resume:(BOOL)resume completionHandler:(void(^)(SGDownloadTuple * tuple))completionHandler;
- (void)cancelTuples:(NSArray <SGDownloadTuple *> *)tuples resume:(BOOL)resume completionHandler:(void(^)(NSArray <SGDownloadTuple *> * tuples))completionHandler;

@end
