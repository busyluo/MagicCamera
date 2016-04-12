//
//  CameraViewController.h
//  MagicCamera
//
//  Created by Xavier on 4/4/16.
//  Copyright © 2016 busyluo. All rights reserved.
//

#import <UIKit/UIKit.h>

@protocol SideViewControllerDelegate <NSObject>

- (void) shouldDisableGesture;
- (void) shouldEnableGesture;
- (void) showLeftViewController;
@end

@interface CameraViewController : UIViewController

@property (weak, nonatomic) id<SideViewControllerDelegate> sideViewControllerDelegate;

@end
