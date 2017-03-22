//
//  SGDownloadConfiguration.m
//  SGDownload
//
//  Created by Single on 2017/3/22.
//  Copyright © 2017年 single. All rights reserved.
//

#import "SGDownloadConfiguration.h"

@implementation SGDownloadConfiguration

+ (instancetype)defaultConfiguration
{
    SGDownloadConfiguration * configuration = [[SGDownloadConfiguration alloc] init];
    
    configuration.maxConcurrentOperationCount = 1;
    configuration.sessionConfiguration = [NSURLSessionConfiguration defaultSessionConfiguration];
    configuration.delegateQueue = [[NSOperationQueue alloc] init];
    configuration.delegateQueue.maxConcurrentOperationCount = 1;
    configuration.delegateQueue.qualityOfService = NSQualityOfServiceUserInteractive;
    
    return configuration;
}

@end
