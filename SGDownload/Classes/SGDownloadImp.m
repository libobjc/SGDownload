//
//  SGDownloadImp.m
//  SGDownload
//
//  Created by Single on 2017/3/17.
//  Copyright © 2017年 single. All rights reserved.
//

#import "SGDownloadImp.h"

NSString * const SGDownloadDefaultIdentifier = @"SGDownloadDefaultIdentifier";

@implementation SGDownload

+ (instancetype)download
{
    return [self downloadWithIdentifier:SGDownloadDefaultIdentifier];
}

+ (instancetype)downloadWithIdentifier:(NSString *)identifier
{
    return [[self alloc] init];
}

- (instancetype)initWithIdentifier:(NSString *)identifier
{
    if (self = [super init]) {
        self->_identifier = identifier;
    }
    return self;
}

- (SGDownloadTask *)taskWithContentURL:(NSURL *)contentURL
{
    return nil;
}

- (void)downloadTask:(SGDownloadTask *)task
{
    
}

- (void)downloadTasks:(NSArray<SGDownloadTask *> *)tasks
{
    
}

@end
