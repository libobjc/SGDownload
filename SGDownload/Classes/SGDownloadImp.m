//
//  SGDownloadImp.m
//  SGDownload
//
//  Created by Single on 2017/3/17.
//  Copyright © 2017年 single. All rights reserved.
//

#import "SGDownloadImp.h"

NSString * const SGDownloadDefaultIdentifier = @"SGDownloadDefaultIdentifier";

@interface SGDownload ()

@property (nonatomic, strong) NSCondition * condition;

@end

@implementation SGDownload

+ (instancetype)download
{
    return [self downloadWithIdentifier:SGDownloadDefaultIdentifier];
}

+ (instancetype)downloadWithIdentifier:(NSString *)identifier
{
    return [[self alloc] initWithIdentifier:identifier];
}

- (instancetype)initWithIdentifier:(NSString *)identifier
{
    if (self = [super init]) {
        self->_identifier = identifier;
        self.condition = [[NSCondition alloc] init];
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

- (void)quit
{
    [self.condition lock];

    [self.condition broadcast];
    [self.condition unlock];
}

@end
