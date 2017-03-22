//
//  SGDownloadTuple.m
//  SGDownload
//
//  Created by Single on 2017/3/21.
//  Copyright © 2017年 single. All rights reserved.
//

#import "SGDownloadTuple.h"

@implementation SGDownloadTuple

+ (instancetype)tupleWithDownloadTask:(SGDownloadTask *)downloadTask sessionTask:(NSURLSessionDownloadTask *)sessionTask
{
    return [[self alloc] initWithDownloadTask:downloadTask sessionTask:sessionTask];
}

- (instancetype)initWithDownloadTask:(SGDownloadTask *)downloadTask sessionTask:(NSURLSessionDownloadTask *)sessionTask
{
    if (self = [super init]) {
        self.downlaodTask = downloadTask;
        self.sessionTask = sessionTask;
    }
    return self;
}

- (void)dealloc
{
    NSLog(@"SGDownloadTuple release");
}

@end
