//
//  DownloadCell.h
//  demo-macos
//
//  Created by Single on 2017/3/24.
//  Copyright © 2017年 Single. All rights reserved.
//

#import <AppKit/AppKit.h>
#import <SGDownload/SGDownload.h>

@interface DownloadCell : NSTableRowView

@property (nonatomic, strong) SGDownloadTask * downloadTask;

@property (nonatomic, strong) NSTextField * titleView;
@property (nonatomic, strong) NSTextField * URLView;
@property (nonatomic, strong) NSTextField * stateView;
@property (nonatomic, strong) NSTextField * progressView;

- (void)refresh;

@end
