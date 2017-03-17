//
//  SGDownloadTask.h
//  SGDownload
//
//  Created by Single on 2017/3/17.
//  Copyright © 2017年 single. All rights reserved.
//

#import <Foundation/Foundation.h>

typedef NS_ENUM(NSUInteger, SGDownloadTaskState) {
    SGDownloadTaskStateNone,
    SGDownloadTaskStateWaiting,
    SGDownloadTaskStateRunning,
    SGDownloadTaskStateSuspend,
    SGDownloadTaskStateFinished,
    SGDownloadTaskStateCanceled,
    SGDownloadTaskStateFaiulred,
};

@interface SGDownloadTask : NSObject

@property (nonatomic, assign) SGDownloadTaskState state;

@property (nonatomic, copy) NSURL * contentURL;

@end
