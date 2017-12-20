//
//  ViewController.m
//  demo-ios
//
//  Created by Single on 2017/3/23.
//  Copyright © 2017年 Single. All rights reserved.
//

#import "ViewController.h"
#import <SGDownload/SGDownload.h>
#import "DownloadCell.h"

@interface ViewController () <UITableViewDelegate, UITableViewDataSource, SGDownloadDelegate>

@property (weak, nonatomic) IBOutlet UITableView * tableView;
@property (nonatomic, strong) SGDownload * download;

@end

@implementation ViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
    [self UILayout];
    [self configDownload];
    [self addDownloadTask];
}

- (void)UILayout
{
    self.automaticallyAdjustsScrollViewInsets = NO;
    self.view.backgroundColor = [UIColor whiteColor];
}

- (void)configDownload
{
    self.download = [SGDownload download];
    self.download.delegate = self;
    self.download.maxConcurrentOperationCount = 3;
    [self.download run];
}

- (void)addDownloadTask
{
    for (int i = 0; i < 6; i++)
    {
        NSString * URLString = [NSString stringWithFormat:@"http://oxl6mxy2t.bkt.clouddn.com/SGDownload/Okay-%d.mp4", i];
        NSURL * contentURL = [NSURL URLWithString:URLString];
        SGDownloadTask * task = [self.download taskForContentURL:contentURL];
        if (!task)
        {
            task = [SGDownloadTask taskWithContentURL:contentURL
                                                title:[NSString stringWithFormat:@"%d", i]
                                              fileURL:[NSURL fileURLWithPath:[NSHomeDirectory() stringByAppendingPathComponent:[NSString stringWithFormat:@"Documents/%d.mp4", i]]]];
            [self.download addDownloadTask:task];
        }
    }
    [self.tableView reloadData];
}

- (IBAction)cancelAction:(id)sender
{
    [self.download cancelAllTasks];
    [self.tableView reloadData];
}

- (IBAction)resumeAction:(id)sender
{
    [self.download resumeAllTasks];
}

- (IBAction)suspendAction:(id)sender
{
    [self.download suspendAllTasks];
}


#pragma mark - SGDownload

- (void)downloadDidCompleteAllRunningTasks:(SGDownload *)download
{
    NSLog(@"%s", __func__);
}


#pragma mark - TableView

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return self.download.tasksForAll.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    DownloadCell * cell = [tableView dequeueReusableCellWithIdentifier:@"cell"];
    cell.downloadTask = [self.download.tasksForAll objectAtIndex:indexPath.row];
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    SGDownloadTask * task = [self.download.tasksForAll objectAtIndex:indexPath.row];
    
    switch (task.state) {
        case SGDownloadTaskStateNone:
        case SGDownloadTaskStateFailured:
            [self.download addDownloadTask:task];
            break;
        case SGDownloadTaskStateWaiting:
        case SGDownloadTaskStateRunning:
            [self.download suspendTask:task];
            break;
        case SGDownloadTaskStateSuspend:
            [self.download resumeTask:task];
            break;
        default:
            break;
    }
}

- (UITableViewCellEditingStyle)tableView:(UITableView *)tableView editingStyleForRowAtIndexPath:(NSIndexPath *)indexPath
{
    return UITableViewCellEditingStyleDelete;
}

- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath
{
    return YES;
}

- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath
{
    [self.download cancelTask:[self.download.tasksForAll objectAtIndex:indexPath.row]];
    [self.tableView deleteRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationTop];
}

- (void)dealloc
{
    [self.download invalidate];
}

@end
