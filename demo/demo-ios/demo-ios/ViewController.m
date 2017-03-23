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
    NSMutableArray <SGDownloadTask *> * tasks = [NSMutableArray array];
    for (int i = 1; i<=10; i++)
    {
        NSString * URLString = [NSString stringWithFormat:@"http://120.25.226.186:32812/resources/videos/minion_%02d.mp4", i];
        NSURL * contentURL = [NSURL URLWithString:URLString];
        SGDownloadTask * task = [self.download taskWithContentURL:contentURL];
        if (!task)
        {
            task = [SGDownloadTask taskWithTitle:[NSString stringWithFormat:@"%d", i]
                                      contentURL:contentURL
                                         fileURL:[NSURL fileURLWithPath:[NSHomeDirectory() stringByAppendingPathComponent:[NSString stringWithFormat:@"Documents/%d.mp4", i]]]];
        }
        [tasks addObject:task];
    }
    [self.download downloadTasks:tasks];
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
    [self.tableView reloadData];
}

- (IBAction)suspendAction:(id)sender
{
    [self.download suspendAllTasks];
    [self.tableView reloadData];
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return self.download.tasks.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    DownloadCell * cell = [tableView dequeueReusableCellWithIdentifier:@"cell"];
    cell.downloadTask = [self.download.tasks objectAtIndex:indexPath.row];
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    SGDownloadTask * task = [self.download.tasks objectAtIndex:indexPath.row];
    
    switch (task.state) {
        case SGDownloadTaskStateNone:
        case SGDownloadTaskStateFailured:
            [self.download downloadTask:task];
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
    [self.tableView reloadData];
}

- (void)dealloc
{
    [self.download invalidate];
}

@end
