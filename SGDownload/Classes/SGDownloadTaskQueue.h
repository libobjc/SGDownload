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

- (nullable SGDownloadTask *)taskForContentURL:(NSURL *)contentURL;
- (nullable NSArray <SGDownloadTask *> *)tasksForAll;
- (nullable NSArray <SGDownloadTask *> *)tasksForRunning;
- (nullable NSArray <SGDownloadTask *> *)tasksForRunningOrWatting;
- (nullable NSArray <SGDownloadTask *> *)tasksForState:(SGDownloadTaskState)state;

- (void)setTaskState:(SGDownloadTask *)task state:(SGDownloadTaskState)state;

- (nullable SGDownloadTask *)downloadTaskSync;
- (void)addDownloadTask:(SGDownloadTask *)task;
- (void)addDownloadTasks:(NSArray <SGDownloadTask *> *)tasks;

- (void)addSuppendTask:(SGDownloadTask *)task;
- (void)addSuppendTasks:(NSArray <SGDownloadTask *> *)tasks;

- (void)resumeAllTasks;
- (void)resumeTask:(SGDownloadTask *)task;
- (void)resumeTasks:(NSArray <SGDownloadTask *> *)tasks;

- (void)suspendAllTasks;
- (void)suspendTask:(SGDownloadTask *)task;
- (void)suspendTasks:(NSArray <SGDownloadTask *> *)tasks;

- (void)cancelAllTasks;
- (void)cancelTask:(SGDownloadTask *)task;
- (void)cancelTasks:(NSArray <SGDownloadTask *> *)tasks;

- (void)deleteAllTaskFiles;
- (void)deleteTaskFile:(SGDownloadTask *)task;
- (void)deleteTaskFiles:(NSArray <SGDownloadTask *> *)tasks;

- (void)invalidate;
- (void)archive;

@end

NS_ASSUME_NONNULL_END
