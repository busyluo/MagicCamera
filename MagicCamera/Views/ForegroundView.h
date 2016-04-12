//
//  ForegroundView.h
//  MagicCamera
//
//  Created by Xavier on 4/6/16.
//  Copyright © 2016 busyluo. All rights reserved.
//

#import <UIKit/UIKit.h>

@protocol CameraHandleDelegate <NSObject>

- (void) setFoucusAtPoint:(CGPoint)point;
- (void) tapFirstPath;
- (void) tapSecondPath;

@end

@interface ForegroundView : UIView {
    CGMutablePathRef drawingPath;
    
    NSMutableArray *pathArray;
    NSMutableArray *closePathArray;
}

@property (nonatomic) CGMutablePathRef firstPath;
@property (nonatomic) CGMutablePathRef secondPath;
@property (nonatomic, weak) id<CameraHandleDelegate> delegate;

- (void) reset;

@end
