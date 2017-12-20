//
//  SGDownloadImp.h
//  SGDownload
//
//  Created by Single on 2017/3/17.
//  Copyright © 2017年 single. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <TargetConditionals.h>
#import "SGDownloadTask.h"


NS_ASSUME_NONNULL_BEGIN


extern NSString * const SGDownloadDefaultIdentifier;    // default identifier.


@class SGDownload;

@protocol SGDownloadDelegate <NSObject>

@optional;
- (void)downloadDidCompleteAllRunningTasks:(SGDownload *)download;      // maybe finished, canceled and failured.
- (void)download:(SGDownload *)download taskStateDidChange:(SGDownloadTask *)task;
- (void)download:(SGDownload *)download taskProgressDidChange:(SGDownloadTask *)task;

@end


@interface SGDownload : NSObject


+ (instancetype)new NS_UNAVAILABLE;
- (instancetype)init NS_UNAVAILABLE;

+ (instancetype)download;    // default download manager.
+ (instancetype)downloadWithIdentifier:(NSString *)identifier;


- (void)run;
- (void)invalidate;     // if


@property (nonatomic, copy, readonly) NSString * identifier;
@property (nonatomic, strong, readonly) NSURLSessionConfiguration * sessionConfiguration;

@property (nonatomic, weak) id <SGDownloadDelegate> delegate;
@property (nonatomic, assign) NSUInteger maxConcurrentOperationCount;       // defalut is 1.


- (nullable SGDownloadTask *)taskForContentURL:(NSURL *)contentURL;
- (nullable NSArray <SGDownloadTask *> *)tasksForAll;
- (nullable NSArray <SGDownloadTask *> *)tasksForRunningOrWatting;
- (nullable NSArray <SGDownloadTask *> *)tasksForState:(SGDownloadTaskState)state;


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

- (void)cancelAllTasksAndDeleteFiles;
- (void)cancelTaskAndDeleteFile:(SGDownloadTask *)task;
- (void)cancelTasksAndDeleteFiles:(NSArray <SGDownloadTask *> *)tasks;


#if TARGET_OS_IOS || TARGET_OS_TV
/**
 *  Must be called when the AppDelegate receives the following callback.
 *
 *  - (void)application:(UIApplication *)application handleEventsForBackgroundURLSession:(NSString *)identifier completionHandler:(void (^)(void))completionHandler
 */
+ (void)handleEventsForBackgroundURLSession:(NSString *)identifier completionHandler:(void (^)(void))completionHandler;
#endif


@end


NS_ASSUME_NONNULL_END
