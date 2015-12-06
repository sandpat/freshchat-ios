//
//  HLListViewController.m
//  
//
//  Created by Aravinth Chandran on 23/09/15.
//
//

#import "HLListViewController.h"
#import "HLMacros.h"
#import "HLContainerController.h"
#import "FDMessageController.h"
#import "HLChannelViewController.h"

@implementation HLListViewController

-(void)willMoveToParentViewController:(UIViewController *)parent{
    self.view.backgroundColor = [UIColor whiteColor];
    [self setSubviews];
}

-(void)setSubviews{
    self.tableView = [[UITableView alloc]init];
    self.tableView.tableFooterView = [UIView new];
    self.tableView.translatesAutoresizingMaskIntoConstraints = NO;
    self.tableView.dataSource = self;
    self.tableView.delegate = self;
    
    self.footerView = [[FDMarginalView alloc] init];
    self.footerView.translatesAutoresizingMaskIntoConstraints = NO;
    self.footerView.marginalLabel.text = HLLocalizedString(@"CATEGORIES_LIST_VIEW_FOOTER_LABEL");
    self.footerView.marginalLabel.userInteractionEnabled=YES;
    UIGestureRecognizer *tapGesture = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(handleTapGesture:)];
    [self.footerView.marginalLabel addGestureRecognizer: tapGesture];

    [self.view addSubview:self.footerView];
    [self.view addSubview:self.tableView];
    
    NSDictionary *views = @{@"tableView" : self.tableView, @"footerView" : self.footerView };
    [self.view addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"H:|[tableView]|" options:0 metrics:nil views:views]];
    
    if ([self canDisplayFooterView]) {
        [self.view addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"H:|[footerView]|" options:0 metrics:nil views:views]];
        [self.view addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"V:|[tableView][footerView(40)]|" options:0 metrics:nil views:views]];
    }else{
        [self.view addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"V:|[tableView]|" options:0 metrics:nil views:views]];
    }
}

-(BOOL)canDisplayFooterView{
    return YES;
}

-(void)handleTapGesture: (UIGestureRecognizer*) recognizer{
    HLContainerController *preferredController = nil;
    HLChannelViewController *channelViewController = [[HLChannelViewController alloc]init];
    preferredController = [[HLContainerController alloc]initWithController:channelViewController];
    UINavigationController *navigationController = [[UINavigationController alloc]initWithRootViewController:preferredController];
    [self presentViewController:navigationController animated:YES completion:nil];
}

-(UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath{
    return nil;
}

@end