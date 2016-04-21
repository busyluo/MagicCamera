//
//  LeftViewCell.m
//  MagicCamera
//
//  Created by Xavier on 4/12/16.
//  Copyright © 2016 busyluo. All rights reserved.
//

#import "LeftViewCell.h"

@interface LeftViewCell ()

@end

@implementation LeftViewCell

- (instancetype)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier
{
    self = [super initWithStyle:style reuseIdentifier:reuseIdentifier];
    if (self)
    {
        self.selectionStyle = UITableViewCellSelectionStyleNone;
        
        self.backgroundColor = [UIColor clearColor];
        
        self.textLabel.font = [UIFont boldSystemFontOfSize:16.f];
        
        // -----
        
        _separatorView = [UIView new];
        [self addSubview:_separatorView];
    }
    return self;
}

- (void)layoutSubviews
{
    [super layoutSubviews];
    
    self.textLabel.textColor = _tintColor;
    _separatorView.backgroundColor = [_tintColor colorWithAlphaComponent:0.4];
    
    CGFloat height = ([UIScreen mainScreen].scale == 1.f ? 1.f : 0.5);
    
    _separatorView.frame = CGRectMake(0.f, self.frame.size.height-height, self.frame.size.width*0.9, height);
}

- (void)setHighlighted:(BOOL)highlighted animated:(BOOL)animated
{
    if (highlighted)
        self.textLabel.textColor = [UIColor colorWithRed:0.f green:0.5 blue:1.f alpha:1.f];
    else
        self.textLabel.textColor = _tintColor;
}

@end

