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

        _sideViewController = [LeftViewController new];
        
        [self setLeftViewEnabledWithWidth:250.f
                        presentationStyle:LGSideMenuPresentationStyleScaleFromLittle
                     alwaysVisibleOptions:LGSideMenuAlwaysVisibleOnNone];
        
        self.leftViewStatusBarStyle = UIStatusBarStyleDefault;
        self.leftViewStatusBarVisibleOptions = LGSideMenuStatusBarVisibleOnNone;

        //[self addChildViewController:_sideViewController];
        [self.leftView addSubview:_sideViewController.view];
        
        
    }
    return self;
}

- (void)loadView{
    [super loadView];
    
    
}


- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
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
