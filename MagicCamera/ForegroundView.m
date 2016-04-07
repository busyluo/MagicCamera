//
//  ForegroundView.m
//  MagicCamera
//
//  Created by Xavier on 4/6/16.
//  Copyright © 2016 busyluo. All rights reserved.
//

#import "ForegroundView.h"
#import "PathModel.h"

@implementation ForegroundView


- (instancetype)initWithFrame:(CGRect)frame {
    if (self = [super initWithFrame:frame]) {
        pathArray = [NSMutableArray array];
        self.backgroundColor = [UIColor whiteColor];
        self.userInteractionEnabled = YES;
    }
    return self;
}

- (void)drawRect:(CGRect)rect {
    for (PathModel *pathModel in pathArray) {
        CGContextRef context = UIGraphicsGetCurrentContext();
        
        [[UIColor blueColor] setStroke];
        CGContextSetLineWidth(context, 3);
        CGContextAddPath(context, pathModel.path);
        
        CGContextDrawPath(context, kCGPathStroke);
    }
    
    if (drawingPath != nil) {
        CGContextRef context = UIGraphicsGetCurrentContext();
        
        CGContextAddPath(context, drawingPath);
        
        [[UIColor redColor] setStroke];
        CGContextSetLineWidth(context, 3);
        
        CGContextDrawPath(context, kCGPathStroke);
        
    }
}

#pragma mark - touches
- (void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event {
    NSLog(@"touchesBegan");
    UITouch *touch = [touches anyObject];
    CGPoint p = [touch locationInView:self];
    
    drawingPath = CGPathCreateMutable();
    CGPathMoveToPoint(drawingPath, NULL, p.x, p.y);
}

- (void)touchesMoved:(NSSet *)touches withEvent:(UIEvent *)event {
    UITouch *touch = [touches anyObject];
    CGPoint p = [touch locationInView:self];
    
    //点加至线上
    CGPathAddLineToPoint(drawingPath, NULL, p.x, p.y);
    //移动->重新绘图
    [self setNeedsDisplay];
    
    NSLog(@"%.1f,%.1f", p.x, p.y);
}

- (void)touchesEnded:(NSSet *)touches withEvent:(UIEvent *)event {
    NSLog(@"touchesEnded");
    
    PathModel *model = [[PathModel alloc] init];
    model.path = drawingPath;
    
    [pathArray addObject:model];
    CGPathRelease(drawingPath);
    drawingPath = nil;
    
    [self setNeedsDisplay];
}

-(void)touchesCancelled:(NSSet *)touches withEvent:(UIEvent *)event {
    [self touchesEnded:touches withEvent:event];
}


@end
