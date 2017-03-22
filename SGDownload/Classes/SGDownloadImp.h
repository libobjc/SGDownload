//
//  SGDownloadImp.h
//  SGDownload
//
//  Created by Single on 2017/3/17.
//  Copyright © 2017年 single. All rights reserved.
//

#import <Foundation/Foundation.h>
@class SGDownload;
@class SGDownloadTask;
@class SGDownloadConfiguration;

NS_ASSUME_NONNULL_BEGIN

@protocol SGDownloadDelegate <NSObject>

- (void)download:(SGDownload *)download taskDidFinished:(SGDownloadTask *)task;
- (void)download:(SGDownload *)download task:(SGDownloadTask *)task didFailuredWithError:(NSError *)error;
- (void)download:(SGDownload *)download task:(SGDownloadTask *)task didWriteData:(int64_t)bytesWritten totalBytesWritten:(int64_t)totalBytesWritten totalBytesExpectedToWrite:(int64_t)totalBytesExpectedToWrite;

@end

extern NSString * const SGDownloadDefaultIdentifier;

@interface SGDownload : NSObject

+ (instancetype)new NS_UNAVAILABLE;
- (instancetype)init NS_UNAVAILABLE;

+ (instancetype)download;    // default download manager and default configuration.
+ (instancetype)downloadWithIdentifier:(NSString *)identifier;
+ (instancetype)downloadWithConfiguration:(SGDownloadConfiguration *)configuration;    // default download manager.

@property (nonatomic, strong, readonly) SGDownloadConfiguration * configuration;
@property (nonatomic, copy, readonly) NSString * identifier;

@property (nonatomic, weak) id <SGDownloadDelegate> delegate;
@property (nonatomic, strong, readonly) NSArray <SGDownloadTask *> * tasks;

- (nullable SGDownloadTask *)taskWithContentURL:(NSURL *)contentURL;    // if return nil, there is no task of the contentURL;

- (void)downloadTask:(SGDownloadTask *)task;
- (void)downloadTasks:(NSArray <SGDownloadTask *> *)tasks;

- (void)resumeAllTasks;
- (void)resumeTask:(SGDownloadTask *)task;
- (void)resumeTasks:(NSArray <SGDownloadTask *> *)tasks;

- (void)suspendAllTasks;
- (void)suspendTask:(SGDownloadTask *)task;
- (void)suspendTasks:(NSArray <SGDownloadTask *> *)tasks;

- (void)cancelAllTasks;
- (void)cancelTask:(SGDownloadTask *)task;
- (void)cancelTasks:(NSArray <SGDownloadTask *> *)tasks;

- (void)handleEventsForBackgroundURLSession:(NSString *)identifier completionHandler:(void (^)())completionHandler;

- (void)invalidate;

@end

NS_ASSUME_NONNULL_END
