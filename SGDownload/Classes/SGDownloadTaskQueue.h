//
//  SGDownloadTaskQueue.h
//  SGDownload
//
//  Created by Single on 2017/3/17.
//  Copyright © 2017年 single. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "SGDownloadTask.h"
@class SGDownload;

NS_ASSUME_NONNULL_BEGIN

@interface SGDownloadTaskQueue : NSObject

+ (instancetype)queueWithDownload:(SGDownload *)download;

@property (nonatomic, weak, readonly) SGDownload * download;

@property (nonatomic, strong, readonly) NSMutableArray <SGDownloadTask *> * tasks;
- (NSMutableArray <SGDownloadTask *> *)tasksWithState:(SGDownloadTaskState)state;

- (nullable SGDownloadTask *)taskWithContentURL:(NSURL *)contentURL;
- (void)setTaskState:(SGDownloadTask *)task state:(SGDownloadTaskState)state;

- (nullable SGDownloadTask *)downloadTaskSync;
- (void)downloadTask:(SGDownloadTask *)task;
- (void)downloadTasks:(NSArray <SGDownloadTask *> *)tasks;

- (void)resumeAllTasks;
- (void)resumeTask:(SGDownloadTask *)task;
- (void)resumeTasks:(NSArray<SGDownloadTask *> *)tasks;

- (void)suspendAllTasks;
- (void)suspendTask:(SGDownloadTask *)task;
- (void)suspendTasks:(NSArray<SGDownloadTask *> *)tasks;

- (void)cancelAllTasks;
- (void)cancelTask:(SGDownloadTask *)task;
- (void)cancelTasks:(NSArray<SGDownloadTask *> *)tasks;

- (void)invalidate;
- (void)archive;

@end

NS_ASSUME_NONNULL_END
