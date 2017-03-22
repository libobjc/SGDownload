//
//  SGDownloadConfiguration.h
//  SGDownload
//
//  Created by Single on 2017/3/22.
//  Copyright © 2017年 single. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface SGDownloadConfiguration : NSObject

+ (instancetype)defaultConfiguration;
+ (instancetype)backgroundConfiguration;

+ (instancetype)defaultConfigurationWithDownloadIdentifier:(NSString *)downloadIdentifier;
+ (instancetype)backgroundConfigurationWithDownloadIdentifier:(NSString *)downloadIdentifier;

@property (nonatomic, copy) NSString * downloadIdentifier;
@property (nonatomic, assign) NSUInteger maxConcurrentOperationCount;               // defalut is 1.
@property (nonatomic, strong) NSURLSessionConfiguration * sessionConfiguration;     // default is default NSURLSessionConfiguration.
@property (nonatomic, strong) NSOperationQueue * delegateQueue;                     // default is a new operation queue.

@end
