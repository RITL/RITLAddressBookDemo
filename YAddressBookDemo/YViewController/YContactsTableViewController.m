//
//  YContactsTableViewController.m
//  YAddressBookDemo
//
//  Created by YueWen on 16/5/9.
//  Copyright © 2016年 YueWen. All rights reserved.
//

#import "YContactsTableViewController.h"
#import "YContactsManager.h"
#import "YContactObject.h"


static NSString * const reuseIdentifier = @"RightCell";


@interface YContactsTableViewController ()

@property (nonatomic, copy)NSArray <YContactObject *> *  contactObjects;

@property (nonatomic, strong) YContactsManager * contactManager;
@end

@implementation YContactsTableViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.contactManager = [YContactsManager shareInstance];
    
    
    __weak typeof(self) copy_self = self;
    
    //开始请求
    [self.contactManager requestContactsComplete:^(NSArray<YContactObject *> * _Nonnull contacts) {
        
        //开始赋值
        copy_self.contactObjects = contacts;
        
        //刷新
        [copy_self.tableView reloadData];
        
    }];
}




- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}


-(void)dealloc
{
 
}

#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {

    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {

    return self.contactObjects.count;
}


- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:reuseIdentifier forIndexPath:indexPath];
    
    //fetch Model
    YContactObject * contactObject = [self.contactObjects objectAtIndex:indexPath.row];
    
    //configture cell..
    cell.textLabel.text = contactObject.nameObject.name;
    cell.detailTextLabel.text = contactObject.phoneObject.firstObject.phoneTitle;
    
    return cell;
}



@end
