//
//  SGDownloadTask.m
//  SGDownload
//
//  Created by Single on 2017/3/17.
//  Copyright © 2017年 single. All rights reserved.
//

#import "SGDownloadTask.h"
#import "SGDownloadImp.h"
#import "SGDownloadTools.h"

@interface SGDownloadTask ()

@property (nonatomic, copy) NSURL * realFileURL;

@end

@implementation SGDownloadTask

+ (instancetype)taskWithTitle:(NSString *)title contentURL:(NSURL *)contentURL fileURL:(NSURL *)fileURL
{
    return [[self alloc] initWithTitle:title contentURL:contentURL fileURL:fileURL];
}

- (instancetype)initWithTitle:(NSString *)title contentURL:(NSURL *)contentURL fileURL:(NSURL *)fileURL
{
    if (self = [super init]) {
        self.title = title;
        self.contentURL = contentURL;
        self.fileURL = fileURL;
        self.replaceHomeDirectoryIfNeed = YES;
    }
    return self;
}

- (instancetype)initWithCoder:(NSCoder *)aDecoder
{
    if (self = [super init]) {
        self.state = [[aDecoder decodeObjectForKey:@"state"] unsignedIntegerValue];
        
        self.title = [aDecoder decodeObjectForKey:@"title"];
        self.contentURL = [aDecoder decodeObjectForKey:@"contentURL"];
        self.fileURL = [aDecoder decodeObjectForKey:@"fileURL"];
        self.replaceHomeDirectoryIfNeed = [[aDecoder decodeObjectForKey:@"replaceHomeDirectoryIfNeed"] boolValue];
        
        self.bytesWritten = [[aDecoder decodeObjectForKey:@"bytesWritten"] longLongValue];
        self.totalBytesWritten = [[aDecoder decodeObjectForKey:@"totalBytesWritten"] longLongValue];
        self.totalBytesExpectedToWrite = [[aDecoder decodeObjectForKey:@"totalBytesExpectedToWrite"] longLongValue];
        
        self.resumeInfoData = [aDecoder decodeObjectForKey:@"resumeInfoData"];
        self.resumeFileOffset = [[aDecoder decodeObjectForKey:@"resumeFileOffset"] longLongValue];
        self.resumeExpectedTotalBytes = [[aDecoder decodeObjectForKey:@"resumeExpectedTotalBytes"] longLongValue];
        
        self.error = [aDecoder decodeObjectForKey:@"error"];
    }
    return self;
}

- (void)encodeWithCoder:(NSCoder *)aCoder
{
    [aCoder encodeObject:@(self.state) forKey:@"state"];
    
    [aCoder encodeObject:self.title forKey:@"title"];
    [aCoder encodeObject:self.contentURL forKey:@"contentURL"];
    [aCoder encodeObject:self.fileURL forKey:@"fileURL"];
    [aCoder encodeObject:@(self.replaceHomeDirectoryIfNeed) forKey:@"replaceHomeDirectoryIfNeed"];
    
    [aCoder encodeObject:@(self.bytesWritten) forKey:@"bytesWritten"];
    [aCoder encodeObject:@(self.totalBytesWritten) forKey:@"totalBytesWritten"];
    [aCoder encodeObject:@(self.totalBytesExpectedToWrite) forKey:@"totalBytesExpectedToWrite"];
    
    [aCoder encodeObject:self.resumeInfoData forKey:@"resumeInfoData"];
    [aCoder encodeObject:@(self.resumeFileOffset) forKey:@"resumeFileOffset"];
    [aCoder encodeObject:@(self.resumeExpectedTotalBytes) forKey:@"resumeExpectedTotalBytes"];
    
    [aCoder encodeObject:self.error forKey:@"error"];
}

- (void)setState:(SGDownloadTaskState)state
{
    if (_state != state) {
        _state = state;
        if ([self.delegate respondsToSelector:@selector(taskStateDidChange:)]) {
            [self.delegate taskStateDidChange:self];
        }
        if ([self.download.delegate respondsToSelector:@selector(download:taskStateDidChange:)]) {
            [self.download.delegate download:self.download taskStateDidChange:self];
        }
    }
    if (_state != SGDownloadTaskStateFailured) {
        self.error = nil;
    }
    if (_state == SGDownloadTaskStateFinished) {
        self.resumeInfoData = nil;
    }
    self.resumeFileOffset = 0;
    self.resumeExpectedTotalBytes = 0;
}

- (void)setTotalBytesWritten:(int64_t)totalBytesWritten
{
    if (_totalBytesWritten != totalBytesWritten) {
        _totalBytesWritten = totalBytesWritten;
        if ([self.delegate respondsToSelector:@selector(taskProgressDidChange:)]) {
            [self.delegate taskProgressDidChange:self];
        }
        if ([self.download.delegate respondsToSelector:@selector(download:taskProgressDidChange:)]) {
            [self.download.delegate download:self.download taskProgressDidChange:self];
        }
    }
}

- (void)setResumeFileOffset:(int64_t)resumeFileOffset
{
    if (_resumeFileOffset != resumeFileOffset) {
        _resumeFileOffset = resumeFileOffset;
        if (_resumeFileOffset > 0) {
            if ([self.delegate respondsToSelector:@selector(taskProgressDidChange:)]) {
                [self.delegate taskProgressDidChange:self];
            }
            if ([self.download.delegate respondsToSelector:@selector(download:taskProgressDidChange:)]) {
                [self.download.delegate download:self.download taskProgressDidChange:self];
            }
        }
    }
}

- (NSURL *)fileURL
{
    if (self.replaceHomeDirectoryIfNeed) {
        if (!self.realFileURL) {
            self.realFileURL = [SGDownloadTools replacehHomeDirectoryForFileURL:_fileURL];
        }
        return self.realFileURL;
    } else {
        return _fileURL;
    }
}

- (void)dealloc
{
    NSLog(@"SGDownloadTask release");
}

@end
