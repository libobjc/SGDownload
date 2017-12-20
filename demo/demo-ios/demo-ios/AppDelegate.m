//
//  AppDelegate.m
//  demo-ios
//
//  Created by Single on 2017/3/23.
//  Copyright © 2017年 Single. All rights reserved.
//

#import "AppDelegate.h"
#import <SGDownload/SGDownload.h>

@interface AppDelegate ()

@end

@implementation AppDelegate

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions
{
    return YES;
}

- (void)application:(UIApplication *)application handleEventsForBackgroundURLSession:(NSString *)identifier completionHandler:(nonnull void (^)(void))completionHandler
{
    [SGDownload handleEventsForBackgroundURLSession:identifier completionHandler:completionHandler];
}

@end
