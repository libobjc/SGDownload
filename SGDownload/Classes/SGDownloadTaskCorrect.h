//
//  SGDownloadTaskCorrect.h
//  SGDownload
//
//  Created by Single on 2018/1/29.
//  Copyright © 2018年 single. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface SGDownloadTaskCorrect : NSObject

+ (NSURLSessionDownloadTask *)downloadTaskWithSession:(NSURLSession *)session resumeData:(NSData *)resumeData;

@end
