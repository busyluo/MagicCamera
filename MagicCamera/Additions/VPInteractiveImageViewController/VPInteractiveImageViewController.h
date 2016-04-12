//
//  VPInteractiveImageViewController.h
//  VPInteractiveImageViewController
//
//  Created by Vidu Pirathaparajah on 27/01/14.
//  Copyright (c) 2014 Vidu Pirathaparajah. All rights reserved.
//

#import <UIKit/UIKit.h>

@class VPInteractiveImageView;

@protocol InteractiveImageViewControllerDelegate <NSObject>

- (void) savePhoto;
- (void) discardPhoto;

@end

@interface VPInteractiveImageViewController : UIViewController
@property (nonatomic, readonly) UIImageView *imageView;

@property (nonatomic, weak) id<InteractiveImageViewControllerDelegate> delegate;

- (instancetype)initWithInteractiveImageView:(VPInteractiveImageView *)interactiveImageView NS_DESIGNATED_INITIALIZER;
- (instancetype)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil NS_UNAVAILABLE;
- (instancetype)initWithCoder:(NSCoder *)aDecoder NS_UNAVAILABLE;
- (instancetype)init NS_UNAVAILABLE;

@end
