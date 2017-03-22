//
//  SGDownloadTuple.h
//  SGDownload
//
//  Created by Single on 2017/3/21.
//  Copyright © 2017年 single. All rights reserved.
//

#import <Foundation/Foundation.h>
@class SGDownloadTask;

@interface SGDownloadTuple : NSObject

+ (instancetype)tupleWithDownloadTask:(SGDownloadTask *)downloadTask sessionTask:(NSURLSessionDownloadTask *)sessionTask;

@property (nonatomic, strong) SGDownloadTask * downloadTask;
@property (nonatomic, strong) NSURLSessionDownloadTask * sessionTask;

@end
