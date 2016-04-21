//
//  ForegroundView.m
//  MagicCamera
//
//  Created by Xavier on 4/6/16.
//  Copyright © 2016 busyluo. All rights reserved.
//

#import "ForegroundView.h"
#import "PathModel.h"

typedef NS_ENUM( NSInteger, ClosetPointSide ) {
    ClosetPointTop,
    ClosetPointRigth,
    ClosetPointBottom,
    ClosetPointLeft,
};

typedef struct ClosestPoint {
    ClosetPointSide side;
    CGPoint point;
}ClosestPoint;


@interface ForegroundView () {
    CGPoint beginPoint;
    CGPoint endPoint;
}

@property (nonatomic) BOOL rewritePath;

@end

@implementation ForegroundView

@synthesize firstPath;
@synthesize secondPath;

- (instancetype)initWithFrame:(CGRect)frame {
    if (self = [super initWithFrame:frame]) {
        pathArray = [NSMutableArray array];
        closePathArray = [NSMutableArray array];
        self.backgroundColor = [UIColor whiteColor];
        self.userInteractionEnabled = YES;
    }
    return self;
}

- (void)drawRect:(CGRect)rect {
    /*
     for (PathModel *pathModel in pathArray) {
     CGContextRef context = UIGraphicsGetCurrentContext();
     
     [[UIColor blueColor] setStroke];
     CGContextSetLineWidth(context, 3);
     CGContextAddPath(context, pathModel.path);
     
     CGContextDrawPath(context, kCGPathStroke);
     }*/
    CGContextRef context = UIGraphicsGetCurrentContext();
    if(firstPath != nil) {
        
        CGContextAddPath(context, firstPath);
        [[UIColor redColor] setStroke];
        CGContextSetLineWidth(context, 3);
        CGContextDrawPath(context, kCGPathStroke);
        
        CGContextAddPath(context, secondPath);
        [[UIColor greenColor] setStroke];
        CGContextSetLineWidth(context, 2);
        CGContextDrawPath(context, kCGPathStroke);
    } else if (drawingPath != nil) {
        
        CGContextAddPath(context, drawingPath);
        
        [[UIColor blueColor] setStroke];
        CGContextSetLineWidth(context, 3);
        CGContextDrawPath(context, kCGPathStroke);
    }
    
}

#pragma mark - touches
- (void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event {
    NSLog(@"touchesBegan");
    UITouch *touch = [touches anyObject];
    CGPoint p = [touch locationInView:self];
    beginPoint = p;
    
    drawingPath = CGPathCreateMutable();
    CGPathMoveToPoint(drawingPath, NULL, p.x, p.y);
    
    _rewritePath = NO;
}

- (void)touchesMoved:(NSSet *)touches withEvent:(UIEvent *)event {
    //删除之前的路径
    CGPathRelease(firstPath);
    firstPath = nil;
    CGPathRelease(secondPath);
    secondPath = nil;
    _rewritePath = YES;
    
    UITouch *touch = [touches anyObject];
    CGPoint p = [touch locationInView:self];
    
    if (p.y > self.frame.size.height) {
        p.y  = self.frame.size.height;
    }else if (p.x < 0){
        p.y = 0;
    }
    
    //点加至线上
    CGPathAddLineToPoint(drawingPath, NULL, p.x, p.y);
    //移动->重新绘图
    [self setNeedsDisplay];
    
    NSLog(@"%.1f,%.1f", p.x, p.y);
}

- (void)touchesEnded:(NSSet *)touches withEvent:(UIEvent *)event {
    
    endPoint = [[touches anyObject] locationInView:self];
    if (endPoint.y > self.frame.size.height) {
        endPoint.y  = self.frame.size.height;
    }else if (endPoint.x < 0){
        endPoint.y = 0;
    }
    
    //生成两个封闭的Path
    if(_rewritePath) {
        [self generateClosePath];
    }else if(firstPath){
        bool inPath = CGPathContainsPoint(firstPath, NULL, endPoint, YES);
        if (inPath) {
            NSLog(@"In first path");
            [self.delegate tapFirstPath];
        }else{
            NSLog(@"In second path");
            [self.delegate tapSecondPath];
        }
    } else {
        NSLog(@"focus in %.1f,%.1f", endPoint.x, endPoint.y);
        [self.delegate setFoucusAtPoint:endPoint];
    }
    
    [self setNeedsDisplay];
    CGPathRelease(drawingPath);
    drawingPath = nil;
}

-(void)touchesCancelled:(NSSet *)touches withEvent:(UIEvent *)event {
    [self touchesEnded:touches withEvent:event];
}

- (ClosestPoint) getClosestPointOnMargin:(CGPoint) point {
    CGRect frame = self.frame;
    ClosestPoint closestPoint;
    
    bool atRight = point.x > frame.size.width / 2.0;
    bool atBottom = point.y > frame.size.height / 2.0;
    
    CGFloat closestX = atRight ? frame.size.width - point.x : point.x;
    CGFloat closestY = atBottom ? frame.size.height - point.y : point.y;
    
    if (closestX < closestY) {
        closestPoint.point.y = point.y;
        closestPoint.point.x = atRight ? frame.size.width : 0;
        closestPoint.side = atRight ? ClosetPointRigth : ClosetPointLeft;
    } else {
        closestPoint.point.x = point.x;
        closestPoint.point.y = atBottom ? frame.size.height : 0;
        closestPoint.side = atBottom ? ClosetPointBottom : ClosetPointTop;
    }
    
    return closestPoint;
}

- (void) generateClosePath {
    firstPath = CGPathCreateMutableCopy(drawingPath);
    secondPath = CGPathCreateMutableCopy(drawingPath);
    
    ClosestPoint endPointClosestPoint = [self getClosestPointOnMargin:endPoint];
    ClosestPoint beginPointClosestPoint = [self getClosestPointOnMargin:beginPoint];
    
    bool firstPathSameSide = false, secondPathSameSide = false;
    if(beginPointClosestPoint.side == endPointClosestPoint.side){
        switch (beginPointClosestPoint.side) {
            case ClosetPointTop:
                if(beginPointClosestPoint.point.x > endPointClosestPoint.point.x)
                    secondPathSameSide = true;
                else
                    firstPathSameSide = true;
                break;
            case ClosetPointLeft:
                if(beginPointClosestPoint.point.y > endPointClosestPoint.point.y)
                    firstPathSameSide = true;
                else
                    secondPathSameSide = true;
                break;
            case ClosetPointBottom:
                if(beginPointClosestPoint.point.x > endPointClosestPoint.point.x)
                    firstPathSameSide = true;
                else
                    secondPathSameSide = true;
                break;
            case ClosetPointRigth:
                if(beginPointClosestPoint.point.y > endPointClosestPoint.point.y)
                    secondPathSameSide = true;
                else
                    firstPathSameSide = true;
                break;
        }
    }
    
    //first
    CGPathAddLineToPoint(firstPath, NULL, endPointClosestPoint.point.x, endPointClosestPoint.point.y);
    CGRect frame = self.frame;
    ClosetPointSide curSide = endPointClosestPoint.side;
    while (curSide != beginPointClosestPoint.side || firstPathSameSide) {
        switch (curSide) {
            case ClosetPointTop:
                CGPathAddLineToPoint(firstPath, NULL, 0, 0);
                curSide = ClosetPointLeft;
                break;
            case ClosetPointLeft:
                CGPathAddLineToPoint(firstPath, NULL, 0, frame.size.height);
                curSide = ClosetPointBottom;
                break;
            case ClosetPointBottom:
                CGPathAddLineToPoint(firstPath, NULL, frame.size.width, frame.size.height);
                curSide = ClosetPointRigth;
                break;
            case ClosetPointRigth:
                CGPathAddLineToPoint(firstPath, NULL, frame.size.width, 0);
                curSide = ClosetPointTop;
                break;
        }
        firstPathSameSide = false;
    }
    CGPathAddLineToPoint(firstPath, NULL, beginPointClosestPoint.point.x, beginPointClosestPoint.point.y);
    CGPathCloseSubpath(firstPath);
    
    //second
    CGPathAddLineToPoint(secondPath, NULL, endPointClosestPoint.point.x, endPointClosestPoint.point.y);
    curSide = endPointClosestPoint.side;
    while (curSide != beginPointClosestPoint.side || secondPathSameSide) {
        switch (curSide) {
            case ClosetPointTop:
                CGPathAddLineToPoint(secondPath, NULL, frame.size.width, 0);
                curSide = ClosetPointRigth;
                break;
            case ClosetPointRigth:
                CGPathAddLineToPoint(secondPath, NULL, frame.size.width, frame.size.height);
                curSide = ClosetPointBottom;
                break;
            case ClosetPointBottom:
                CGPathAddLineToPoint(secondPath, NULL, 0, frame.size.height);
                
                curSide = ClosetPointLeft;
                break;
            case ClosetPointLeft:
                CGPathAddLineToPoint(secondPath, NULL, 0, 0);
                curSide = ClosetPointTop;
                break;
        }
        secondPathSameSide = false;
    }
    CGPathAddLineToPoint(secondPath, NULL, beginPointClosestPoint.point.x, beginPointClosestPoint.point.y);
    CGPathCloseSubpath(secondPath);
}

- (void) reset {
    //删除之前的路径
    CGPathRelease(firstPath);
    firstPath = nil;
    CGPathRelease(secondPath);
    secondPath = nil;
    _rewritePath = YES;
    [self setNeedsDisplay];
}

@end
