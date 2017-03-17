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

@property (nonatomic, copy) NSString * archiverPath;
@property (nonatomic, assign) BOOL destoryToken;

@end

@implementation SGDownload

+ (instancetype)download
{
    return [self downloadWithIdentifier:SGDownloadDefaultIdentifier];
}

+ (instancetype)downloadWithIdentifier:(NSString *)identifier
{
    return [[self alloc] init];
}

+ (NSString *)archiverPathWithIdentifier:(NSString *)identifier
{
    return [NSHomeDirectory() stringByAppendingPathComponent:[NSString stringWithFormat:@"Documents/%@.SGDownloadArchiver", identifier]];
}

- (instancetype)initWithIdentifier:(NSString *)identifier
{
    if (self = [super init]) {
        self->_identifier = identifier;
        self->_archiverPath = [self.class archiverPathWithIdentifier:identifier];
        self->_tasks = [NSKeyedUnarchiver unarchiveObjectWithFile:self.archiverPath];
        if (!self->_tasks) {
            self->_tasks = [NSMutableArray array];
        }
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
    self.destoryToken = YES;
    [NSKeyedArchiver archiveRootObject:self.tasks toFile:self.archiverPath];
}

@end
