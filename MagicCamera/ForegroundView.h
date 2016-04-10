//
//  ForegroundView.h
//  MagicCamera
//
//  Created by Xavier on 4/6/16.
//  Copyright © 2016 busyluo. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface ForegroundView : UIView {
    CGMutablePathRef drawingPath;
    
    NSMutableArray *pathArray;
    NSMutableArray *closePathArray;
}

@property (nonatomic) CGMutablePathRef firstPath;
@property (nonatomic) CGMutablePathRef secondPath;

@end
