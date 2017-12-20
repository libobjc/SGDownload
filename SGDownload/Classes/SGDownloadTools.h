//
//  SGDownloadTools.h
//  SGDownload
//
//  Created by Single on 2017/3/23.
//  Copyright © 2017年 single. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface SGDownloadTools : NSObject

+ (NSString *)archiverDirectoryPath;
+ (NSString *)archiverFilePathWithIdentifier:(NSString *)identifier;

+ (NSURL *)replacehHomeDirectoryForFileURL:(NSURL *)fileURL;
+ (NSString *)replacehHomeDirectoryForFilePath:(NSString *)filePath;

+ (NSInteger)sizeWithFileURL:(NSURL *)fileURL;
+ (NSError *)removeFileWithFileURL:(NSURL *)fileURL;

@end
