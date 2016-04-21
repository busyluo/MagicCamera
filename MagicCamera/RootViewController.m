//
//  ViewController.m
//  MagicCamera
//
//  Created by Xavier on 4/4/16.
//  Copyright © 2016 busyluo. All rights reserved.
//

#import "RootViewController.h"
#import "LeftViewController.h"


@interface RootViewController () 

@property (strong, nonatomic) LeftViewController *sideViewController;

@end

@implementation RootViewController

#pragma mark - life cycle

- (instancetype)initWithRootViewController:(UIViewController *)rootViewController{
    self = [super initWithRootViewController:rootViewController];
    if (self){
        [self setLeftViewEnabledWithWidth:150.f
                        presentationStyle:LGSideMenuPresentationStyleScaleFromLittle
                     alwaysVisibleOptions:LGSideMenuAlwaysVisibleOnNone];
        
        self.leftViewStatusBarStyle = UIStatusBarStyleDefault;
        self.leftViewStatusBarVisibleOptions = LGSideMenuStatusBarVisibleOnNone;
        self.leftViewBackgroundImage = [UIImage imageNamed:@"leftviewbackground"];
        
        _sideViewController = [LeftViewController new];
        _sideViewController.tableView.backgroundColor = [UIColor clearColor];
        _sideViewController.tintColor = [UIColor whiteColor];
        [self.leftView addSubview:_sideViewController.view];
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

#pragma mark - Rotate
- (BOOL)shouldAutorotate {
    return YES;
}

- (UIInterfaceOrientationMask)supportedInterfaceOrientations {
    return UIInterfaceOrientationMaskPortrait;
}

#pragma mark - CameraViewController Delegate

- (void)shouldDisableGesture {
    [self disableGesture];
}

- (void)shouldEnableGesture {
    [self enableGesture];
}

- (void)showLeftViewController {
    [self showLeftViewAnimated:YES completionHandler:nil];
}

@end
