//
//  DownloadCell.m
//  demo-ios
//
//  Created by Single on 2017/3/23.
//  Copyright © 2017年 Single. All rights reserved.
//

#import "DownloadCell.h"

@interface DownloadCell () <SGDownloadTaskDelegate>

@property (weak, nonatomic) IBOutlet UIProgressView * progressView;
@property (weak, nonatomic) IBOutlet UILabel * progressLabel;
@property (weak, nonatomic) IBOutlet UILabel * stateLabel;
@property (weak, nonatomic) IBOutlet UILabel * titleLabel;

@end

@implementation DownloadCell

- (void)setDownloadTask:(SGDownloadTask *)downloadTask
{
    if (_downloadTask != downloadTask) {
        _downloadTask.delegate = nil;
        _downloadTask = downloadTask;
        _downloadTask.delegate = self;
        [self refreshState];
        [self refreshProgress];
    }
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
    self.titleLabel.text = _downloadTask.title;
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
    self.stateLabel.text = text;
}

- (void)refreshProgress
{
    float progress = self.downloadTask.progress;
    int64_t current = self.downloadTask.totalBytesWritten;
    int64_t total = self.downloadTask.totalBytesExpectedToWrite;
    NSString * text = [NSString stringWithFormat:@"%lld / %lld", current, total];
    self.progressView.progress = progress;
    self.progressLabel.text = text;
}

@end
