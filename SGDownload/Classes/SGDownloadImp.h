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

NS_ASSUME_NONNULL_BEGIN

extern NSString * const SGDownloadDefaultIdentifier;

@interface SGDownload : NSObject

+ (instancetype)new NS_UNAVAILABLE;
- (instancetype)init NS_UNAVAILABLE;

+ (instancetype)download;    // default download manager.
+ (instancetype)downloadWithIdentifier:(NSString *)identifier;

@property (nonatomic, copy, readonly) NSString * identifier;

@property (nonatomic, strong, readonly) NSArray <SGDownloadTask *> * tasks;

- (nullable SGDownloadTask *)taskWithContentURL:(NSURL *)contentURL;    // if return nil, there is no task of the contentURL;

- (void)downloadTask:(SGDownloadTask *)task;
- (void)downloadTasks:(NSArray <SGDownloadTask *> *)tasks;

- (void)quit;

@end

NS_ASSUME_NONNULL_END
