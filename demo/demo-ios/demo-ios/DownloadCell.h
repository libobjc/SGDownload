//
//  DownloadCell.h
//  demo-ios
//
//  Created by Single on 2017/3/23.
//  Copyright © 2017年 Single. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <SGDownload/SGDownload.h>

@interface DownloadCell : UITableViewCell

@property (nonatomic, strong) SGDownloadTask * downloadTask;

@end
