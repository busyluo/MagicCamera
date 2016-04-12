//
//  PreviewView.h
//  MagicCamera
//
//  Created by Xavier on 4/6/16.
//  Copyright © 2016 busyluo. All rights reserved.
//

#import <UIKit/UIKit.h>

@class AVCaptureSession;

@interface PreviewView : UIView

@property (nonatomic) AVCaptureSession *session;

@end
