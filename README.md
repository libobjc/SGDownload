# SGDownload

## English Document

SGDownload is a big files download manager based on NSURLSession, support background download, multitasking download. iOS, macOS, and tvOS.

## 中文文档

SGDownload 是一个文件下载器。非常适合用于视频下载，支持后台，锁屏下载。同时支持 iOS、macOS、tvOS 三个平台。

## 功能特点

- 使用 NSCondition 条件变量控制并发数、调度下载任务。
- 封装任务队列（block queue）来管理下载任务。
- 如下载过程中 App 崩溃，已唤醒的任务继续下载，并在下次启动 App 时同步状态。
