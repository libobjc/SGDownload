# SGDownload

SGDownload 是一个文件下载器。非常适合用于视频下载，支持后台，锁屏下载。同时支持 iOS、macOS、tvOS 三个平台。

## 功能特点

- 使用 NSCondition 条件变量控制并发数、调度下载任务。
- 封装任务队列（block queue）来管理下载任务。
- 如下载过程中 App 崩溃，已唤醒的任务继续下载，并在下次启动 App 时同步状态。

## 使用示例

```obj-c

// 在 AppDelegate 中添加如下代码。
- (void)application:(UIApplication *)application handleEventsForBackgroundURLSession:(NSString *)identifier completionHandler:(void (^)())completionHandler
{
    [SGDownload handleEventsForBackgroundURLSession:identifier completionHandler:completionHandler];
}

// 启动下载
self.download = [SGDownload download];
[self.download run];
SGDownloadTask * task = [self.download taskWithContentURL:contentURL];
if (!task)
{
    task = [SGDownloadTask taskWithTitle:@“title”
                              contentURL:contentURL
                                 fileURL:fileURL];
}
[self.download addDownloadTask:task];

```

## 效果演示

### iOS

![iOS 效果演示](https://github.com/libobjc/resource/blob/master/SGDownload/SGDownload-iOS.gif?raw=true)

### macOS

![macOS 效果演示](https://github.com/libobjc/resource/blob/master/SGDownload/SGDownload-macOS.gif?raw=true)
