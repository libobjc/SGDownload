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

@optional
- (void)taskStateDidChange:(SGDownloadTask *)task;
- (void)taskProgressDidChange:(SGDownloadTask *)task;

@end

@interface SGDownloadTask : NSObject

+ (instancetype)taskWithTitle:(NSString *)title contentURL:(NSURL *)contentURL fileURL:(NSURL *)fileURL;

@property (nonatomic, weak) SGDownload * download;
@property (nonatomic, weak) id <SGDownloadTaskDelegate> delegate;

@property (nonatomic, assign, readonly) SGDownloadTaskState state;

@property (nonatomic, copy, readonly) NSString * title;
@property (nonatomic, copy, readonly) NSURL * contentURL;
@property (nonatomic, copy, readonly) NSURL * fileURL;

@property (nonatomic, assign, readonly) BOOL fileDidRemoved;
@property (nonatomic, assign, readonly) BOOL fileIsValid;

@property (nonatomic, assign) BOOL replaceHomeDirectoryIfNeed;      // default is YES;

@property (nonatomic, assign, readonly) float progress;
@property (nonatomic, assign, readonly) int64_t bytesWritten;
@property (nonatomic, assign, readonly) int64_t totalBytesWritten;
@property (nonatomic, assign, readonly) int64_t totalBytesExpectedToWrite;

// about resume
@property (nonatomic, strong, readonly) NSData * resumeInfoData;
@property (nonatomic, assign, readonly) int64_t resumeFileOffset;
@property (nonatomic, assign, readonly) int64_t resumeExpectedTotalBytes;

@property (nonatomic, strong, readonly) NSError * error;

@end
