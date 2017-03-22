//
//  SGDownloadConfiguration.m
//  SGDownload
//
//  Created by Single on 2017/3/22.
//  Copyright © 2017年 single. All rights reserved.
//

#import "SGDownloadConfiguration.h"
#import "SGDownloadImp.h"

@implementation SGDownloadConfiguration

+ (instancetype)defaultConfiguration
{
    return [self defaultConfigurationWithDownloadIdentifier:SGDownloadDefaultIdentifier];
}

+ (instancetype)backgroundConfiguration
{
    return [self backgroundConfigurationWithDownloadIdentifier:SGDownloadDefaultIdentifier];
}

+ (instancetype)defaultConfigurationWithDownloadIdentifier:(NSString *)downloadIdentifier
{
    SGDownloadConfiguration * configuration = [[SGDownloadConfiguration alloc] init];
    
    configuration.downloadIdentifier = downloadIdentifier;
    configuration.maxConcurrentOperationCount = 1;
    configuration.sessionConfiguration = [NSURLSessionConfiguration defaultSessionConfiguration];
    configuration.delegateQueue = [[NSOperationQueue alloc] init];
    configuration.delegateQueue.maxConcurrentOperationCount = 1;
    configuration.delegateQueue.qualityOfService = NSQualityOfServiceUserInteractive;
    
    return configuration;
}

+ (instancetype)backgroundConfigurationWithDownloadIdentifier:(NSString *)downloadIdentifier
{
    SGDownloadConfiguration * configuration = [[SGDownloadConfiguration alloc] init];
    
    configuration.downloadIdentifier = downloadIdentifier;
    configuration.maxConcurrentOperationCount = 1;
    configuration.sessionConfiguration = [NSURLSessionConfiguration backgroundSessionConfigurationWithIdentifier:downloadIdentifier];
    configuration.delegateQueue = [[NSOperationQueue alloc] init];
    configuration.delegateQueue.maxConcurrentOperationCount = 1;
    configuration.delegateQueue.qualityOfService = NSQualityOfServiceUserInteractive;
    
    return configuration;
}

@end
