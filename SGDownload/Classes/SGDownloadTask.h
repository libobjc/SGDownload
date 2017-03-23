//
//  SGDownloadTask.h
//  SGDownload
//
//  Created by Single on 2017/3/17.
//  Copyright © 2017年 single. All rights reserved.
//

#import <Foundation/Foundation.h>
@class SGDownload;
@class SGDownloadTask;

typedef NS_ENUM(NSUInteger, SGDownloadTaskState) {
    SGDownloadTaskStateNone,
    SGDownloadTaskStateWaiting,
    SGDownloadTaskStateRunning,
    SGDownloadTaskStateSuspend,
    SGDownloadTaskStateFinished,
    SGDownloadTaskStateCanceled,
    SGDownloadTaskStateFailured,
};

@protocol SGDownloadTaskDelegate <NSObject>

- (void)taskStateDidChange:(SGDownloadTask *)task current:(SGDownloadTaskState)current previous:(SGDownloadTaskState)previous;
- (void)taskProgressDidChange:(SGDownloadTask *)task current:(int64_t)current total:(int64_t)total;

@end

@interface SGDownloadTask : NSObject

+ (instancetype)taskWithTitle:(NSString *)title contentURL:(NSURL *)contentURL fileURL:(NSURL *)fileURL;

@property (nonatomic, weak) SGDownload * download;
@property (nonatomic, weak) id <SGDownloadTaskDelegate> delegate;

@property (nonatomic, assign) SGDownloadTaskState state;

@property (nonatomic, copy) NSString * title;
@property (nonatomic, copy) NSURL * contentURL;
@property (nonatomic, copy) NSURL * fileURL;
@property (nonatomic, assign) BOOL replaceHomeDirectoryIfNeed;      // default is YES;

@property (nonatomic, assign) int64_t bytesWritten;
@property (nonatomic, assign) int64_t totalBytesWritten;
@property (nonatomic, assign) int64_t totalBytesExpectedToWrite;

// about resume
@property (nonatomic, strong) NSData * resumeInfoData;
@property (nonatomic, assign) int64_t resumeFileOffset;
@property (nonatomic, assign) int64_t resumeExpectedTotalBytes;

@property (nonatomic, strong) NSError * error;

@end
