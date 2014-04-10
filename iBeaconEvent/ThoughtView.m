//
//  ThoughtView.m
//  iBeaconEvent
//
//  Created by Stephen Keep on 10/04/2014.
//  Copyright (c) 2014 Stephen Keep. All rights reserved.
//

#import "ThoughtView.h"

@implementation ThoughtView

- (id)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        self.userInteractionEnabled = NO;
        self.backgroundColor = [UIColor clearColor];
    }
    return self;
}

-(void)drawRect:(CGRect)rect {
    CGContextRef ctx = UIGraphicsGetCurrentContext();
    CGContextSetRGBFillColor(ctx, 1.0, 1.0, 1.0, 1.0);
    CGContextFillEllipseInRect(ctx, CGRectMake(0.0, 0.0, 70.0, 50.0)); //oval shape
    CGContextBeginPath(ctx);
    CGContextMoveToPoint(ctx, 8.0, 40.0);
    CGContextAddLineToPoint(ctx, 6.0, 50.0);
    CGContextAddLineToPoint(ctx, 18.0, 45.0);
    CGContextClosePath(ctx);
    CGContextFillPath(ctx);
}

@end
