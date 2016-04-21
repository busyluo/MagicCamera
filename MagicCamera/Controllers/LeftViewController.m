//
//  SideViewController.m
//  MagicCamera
//
//  Created by Xavier on 4/4/16.
//  Copyright © 2016 busyluo. All rights reserved.
//

#import "LeftViewController.h"
#import "AppDelegate.h"
#import "LeftViewCell.h"

@interface LeftViewController ()

@property (strong, nonatomic) NSArray *titlesArray;
@property (strong, nonatomic) NSArray *imagesArray;

@end

@implementation LeftViewController

- (instancetype)init {
    self = [super initWithStyle:UITableViewStylePlain];
    if (self) {
        _titlesArray = @[@"帮助",
                        @"关于"];
        
        _imagesArray = @[ @"leftviewbackground",
                         @"leftviewbackground"];
        
        assert(_imagesArray.count == _titlesArray.count);
        
        [self.tableView registerClass:[LeftViewCell class] forCellReuseIdentifier:@"cell"];
        self.tableView.separatorStyle = UITableViewCellSeparatorStyleNone;
        self.tableView.contentInset = UIEdgeInsetsMake(150.f, 0.f, 0.f, 0.f);
        self.tableView.showsVerticalScrollIndicator = NO;
    }
    return self;
}

#pragma mark - UITableView DataSource

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return _titlesArray.count;
}

#pragma mark - UITableView Delegate

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    
    LeftViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"cell"];
    
    cell.textLabel.text = _titlesArray[indexPath.row];
    cell.separatorView.hidden =  indexPath.row == _titlesArray.count-1;
    //cell.userInteractionEnabled = (indexPath.row != 1);
    cell.tintColor = _tintColor;
    
    //cell.imageView.image = [UIImage imageNamed:[self.imagesArray objectAtIndex:indexPath.row]];
    
    return cell;
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    return 55.f;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    
}

@end
