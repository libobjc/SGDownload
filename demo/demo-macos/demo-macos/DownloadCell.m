//
//  DownloadCell.m
//  demo-macos
//
//  Created by Single on 2017/3/24.
//  Copyright © 2017年 Single. All rights reserved.
//

#import "DownloadCell.h"

@interface DownloadCell () <SGDownloadTaskDelegate>

@end

@implementation DownloadCell

- (void)setDownloadTask:(SGDownloadTask *)downloadTask
{
    if (_downloadTask != downloadTask) {
        _downloadTask.delegate = nil;
        _downloadTask = downloadTask;
        _downloadTask.delegate = self;
        [self refresh];
    }
}

- (void)refresh
{
    [self refreshState];
    [self refreshProgress];
}

- (void)taskStateDidChange:(SGDownloadTask *)task
{
    [self refreshState];
}

- (void)taskProgressDidChange:(SGDownloadTask *)task
{
    [self refreshProgress];
}

- (void)refreshState
{
    self.titleView.stringValue = self.downloadTask.title;
    self.URLView.stringValue = self.downloadTask.contentURL.absoluteString;
    
    NSString * text = nil;
    switch (self.downloadTask.state) {
        case SGDownloadTaskStateNone:
            text = @"None";
            break;
        case SGDownloadTaskStateWaiting:
            text = @"Waiting...";
            break;
        case SGDownloadTaskStateRunning:
            text = @"Running...";
            break;
        case SGDownloadTaskStateSuspend:
            text = @"Suspend";
            break;
        case SGDownloadTaskStateFinished:
            text = @"Finished";
            break;
        case SGDownloadTaskStateCanceled:
            text = @"Canceled";
            break;
        case SGDownloadTaskStateFailured:
            text = @"Failured";
            break;
    }
    self.stateView.stringValue = text;
}

- (void)refreshProgress
{
    self.progressView.stringValue = [NSString stringWithFormat:@"%.2f%%", self.downloadTask.progress * 100];
}

@end
