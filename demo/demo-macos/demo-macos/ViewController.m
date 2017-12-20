//
//  ViewController.m
//  demo-macos
//
//  Created by Single on 2017/3/24.
//  Copyright © 2017年 Single. All rights reserved.
//

#import "ViewController.h"
#import <SGDownload/SGDownload.h>
#import "DownloadCell.h"

@interface ViewController () <NSTableViewDelegate, NSTableViewDataSource, SGDownloadDelegate>

@property (weak) IBOutlet NSTableView * tableView;
@property (nonatomic, strong) SGDownload * download;

@end

@implementation ViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
    [self configDownload];
}

- (void)configDownload
{
    self.download = [SGDownload download];
    self.download.delegate = self;
    self.download.maxConcurrentOperationCount = 3;
    [self.download run];
}

- (IBAction)addAction:(NSButton *)sender
{
    NSString * documentsPath = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES).firstObject;
    NSString * desPath = [documentsPath stringByAppendingPathComponent:@"SGDownloadData"];
    
    for (int i = 0; i < 6; i++)
    {
        NSString * URLString = [NSString stringWithFormat:@"http://oxl6mxy2t.bkt.clouddn.com/SGDownload/Okay-%d.mp4", i];
        NSURL * contentURL = [NSURL URLWithString:URLString];
        SGDownloadTask * task = [self.download taskWithContentURL:contentURL];
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

- (IBAction)cancelAction:(NSButton *)sender
{
    [self.download cancelAllTasks];
    [self.tableView reloadData];
}

- (IBAction)resumeAction:(NSButton *)sender
{
    [self.download resumeAllTasks];
}

- (IBAction)suspendAction:(NSButton *)sender
{
    [self.download suspendAllTasks];
}


#pragma mark - SGDownload

- (void)downloadDidCompleteAllRunningTasks:(SGDownload *)download
{
    NSLog(@"%s", __func__);
}


#pragma mark - TableView

- (NSInteger)numberOfRowsInTableView:(NSTableView *)tableView
{
    return self.download.tasks.count;
}

- (NSTableRowView *)tableView:(NSTableView *)tableView rowViewForRow:(NSInteger)row
{
    static NSString * const rowViewIdentifier = @"DownloadCell";
    DownloadCell * rowView = [tableView makeViewWithIdentifier:rowViewIdentifier owner:self];
    if (!rowView) {
        rowView = [[DownloadCell alloc] initWithFrame:NSZeroRect];
        rowView.identifier = rowViewIdentifier;
        rowView.backgroundColor = [NSColor yellowColor];
    }
    rowView.downloadTask = [self.download.tasks objectAtIndex:row];
    return rowView;
}

- (NSView *)tableView:(NSTableView *)tableView viewForTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row
{
    DownloadCell * rowView = [tableView rowViewAtRow:row makeIfNecessary:NO];
    NSTextField * view = [tableView makeViewWithIdentifier:tableColumn.title owner:self];
    if (!view) {
        view = [[NSTextField alloc] init];
        view.bezeled = NO;
        view.drawsBackground = NO;
        view.lineBreakMode = NSLineBreakByTruncatingTail;
        view.maximumNumberOfLines = 1;
        view.editable = NO;
    }
    if ([tableColumn.title isEqualToString:@"Title"]) {
        rowView.titleView = view;
    } else if ([tableColumn.title isEqualToString:@"URL"]) {
        view.selectable = YES;
        rowView.URLView = view;
    } else if ([tableColumn.title isEqualToString:@"State"]) {
        rowView.stateView = view;
    } else if ([tableColumn.title isEqualToString:@"Progress"]) {
        rowView.progressView = view;
    }
    [rowView refresh];
    return view;
}

- (CGFloat)tableView:(NSTableView *)tableView heightOfRow:(NSInteger)row
{
    return 25;
}

- (IBAction)tableViewDidDoubleClick:(NSTableView *)sender
{
    SGDownloadTask * task = [self.download.tasks objectAtIndex:sender.selectedRow];
    
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

@end
