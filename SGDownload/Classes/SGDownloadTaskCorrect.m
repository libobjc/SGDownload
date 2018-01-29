//
//  SGDownloadTaskCorrect.m
//  SGDownload
//
//  Created by Single on 2018/1/29.
//  Copyright © 2018年 single. All rights reserved.
//

#import "SGDownloadTaskCorrect.h"

#if TARGET_OS_IOS
#import <UIKit/UIKit.h>
#endif

@implementation SGDownloadTaskCorrect

+ (NSURLSessionDownloadTask *)downloadTaskWithSession:(NSURLSession *)session resumeData:(NSData *)resumeData
{
#if TARGET_OS_IOS
    float systemVersion = [UIDevice currentDevice].systemVersion.floatValue;
    if (systemVersion >= 10.0 || systemVersion < 10.2)
    {
        NSMutableDictionary * resumeDictionary = [self dictionaryWithData:resumeData];
        
        static NSString * originalRequestKey = @"NSURLSessionResumeOriginalRequest";
        static NSString * currentRequestKey = @"NSURLSessionResumeCurrentRequest";
        resumeDictionary[originalRequestKey] = [self correctRequestData:[resumeDictionary objectForKey:originalRequestKey]];
        resumeDictionary[currentRequestKey] = [self correctRequestData:[resumeDictionary objectForKey:currentRequestKey]];
        
        resumeData = [NSPropertyListSerialization dataWithPropertyList:resumeDictionary format:NSPropertyListXMLFormat_v1_0 options:0 error:nil];
        
        NSURLSessionDownloadTask * task = [session downloadTaskWithResumeData:resumeData];
        
        if (task.originalRequest == nil)
        {
            NSData * originalRequestData = [resumeDictionary objectForKey:originalRequestKey];
            NSURLRequest * originalRequest = [NSKeyedUnarchiver unarchiveObjectWithData:originalRequestData];
            if (originalRequest)
            {
                [task setValue:originalRequest forKey:@"originalRequest"];
            }
        }
        
        if (task.currentRequest == nil)
        {
            NSData * currentRequestData = [resumeDictionary objectForKey:currentRequestKey];
            NSURLRequest * currentRequest = [NSKeyedUnarchiver unarchiveObjectWithData:currentRequestData];
            if (currentRequest)
            {
                [task setValue:currentRequest forKey:@"currentRequest"];
            }
        }
        return task;
    }
#endif
    return [session downloadTaskWithResumeData:resumeData];
}

+ (NSMutableDictionary *)dictionaryWithData:(NSData *)data
{
    id obj = nil;
    id keyedUnarchiver = [[NSKeyedUnarchiver alloc] initForReadingWithData:data];
    @try
    {
        obj = [keyedUnarchiver decodeTopLevelObjectForKey:@"NSKeyedArchiveRootObjectKey" error:nil];
        if (obj == nil)
        {
            obj = [keyedUnarchiver decodeTopLevelObjectForKey:NSKeyedArchiveRootObjectKey error:nil];
        }
    }
    @catch(NSException * exception)
    {
        
    }
    [keyedUnarchiver finishDecoding];
    NSMutableDictionary * resumeDictionary = [obj mutableCopy];
    if (resumeDictionary == nil)
    {
        resumeDictionary = [NSPropertyListSerialization propertyListWithData:data options:NSPropertyListMutableContainersAndLeaves format:nil error:nil];
    }
    return resumeDictionary;
}

+ (NSData *)correctRequestData:(NSData *)data
{
    if (!data)
    {
        return nil;
    }
    if ([NSKeyedUnarchiver unarchiveObjectWithData:data] != nil)
    {
        return data;
    }
    NSMutableDictionary * archive = [[NSPropertyListSerialization propertyListWithData:data
                                                                               options:NSPropertyListMutableContainersAndLeaves
                                                                                format:nil
                                                                                 error:nil] mutableCopy];
    if (!archive)
    {
        return nil;
    }
    int k = 0;
    id objects = archive[@"$objects"];
    while ([objects[1] objectForKey:[NSString stringWithFormat:@"$%d", k]] != nil)
    {
        k += 1;
    }
    int i = 0;
    while ([archive[@"$objects"][1] objectForKey:[NSString stringWithFormat:@"__nsurlrequest_proto_prop_obj_%d", i]] != nil)
    {
        NSMutableArray * arr = archive[@"$objects"];
        NSMutableDictionary * dic = arr[1];
        id obj = [dic objectForKey:[NSString stringWithFormat:@"__nsurlrequest_proto_prop_obj_%d", i]];
        if (obj)
        {
            [dic setValue:obj forKey:[NSString stringWithFormat:@"$%d",i + k]];
            [dic removeObjectForKey:[NSString stringWithFormat:@"__nsurlrequest_proto_prop_obj_%d", i]];
            [arr replaceObjectAtIndex:1 withObject:dic];
            archive[@"$objects"] = arr;
        }
        i++;
    }
    if ([archive[@"$objects"][1] objectForKey:@"__nsurlrequest_proto_props"] != nil)
    {
        NSMutableArray * arr = archive[@"$objects"];
        NSMutableDictionary * dic = arr[1];
        id obj = [dic objectForKey:@"__nsurlrequest_proto_props"];
        if (obj)
        {
            [dic setValue:obj forKey:[NSString stringWithFormat:@"$%d", i + k]];
            [dic removeObjectForKey:@"__nsurlrequest_proto_props"];
            [arr replaceObjectAtIndex:1 withObject:dic];
            archive[@"$objects"] = arr;
        }
    }
    if ([archive[@"$top"] objectForKey:@"NSKeyedArchiveRootObjectKey"] != nil)
    {
        [archive[@"$top"] setObject:archive[@"$top"][@"NSKeyedArchiveRootObjectKey"] forKey: NSKeyedArchiveRootObjectKey];
        [archive[@"$top"] removeObjectForKey:@"NSKeyedArchiveRootObjectKey"];
    }
    NSData * result = [NSPropertyListSerialization dataWithPropertyList:archive
                                                                 format:NSPropertyListBinaryFormat_v1_0
                                                                options:0
                                                                  error:nil];
    return result;
}

@end
