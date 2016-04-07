//
//  PathModel.m
//  MagicCamera
//
//  Created by Xavier on 4/6/16.
//  Copyright © 2016 busyluo. All rights reserved.
//

#import "PathModel.h"

@implementation PathModel

- (void)dealloc {
    CGPathRelease(_path);
}

- (void)setPath:(CGMutablePathRef)path {
    if (_path != path) {
        _path = (CGMutablePathRef)CGPathRetain(path);
    }
}

@end
