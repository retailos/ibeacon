//
//  TitleView.m
//  iBeaconEvent
//
//  Created by Stephen Keep on 08/04/2014.
//  Copyright (c) 2014 Stephen Keep. All rights reserved.
//

#import "TitleView.h"
#import <Social/Social.h>

@implementation TitleView

- (id)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        self.userInteractionEnabled = NO;
        self.backgroundColor = [UIColor clearColor];
    }
    return self;
}

- (void)drawRect:(CGRect)rect
{
    [[UIColor clearColor] setFill];
    UIRectFill(rect);
    
    //ROTATE THE VIEW
    CGContextRef ctx = UIGraphicsGetCurrentContext();
    CGContextConcatCTM(ctx, CGAffineTransformMakeRotation(DEGREES_TO_RADIANS(5)));
    CGContextConcatCTM(ctx, CGAffineTransformMakeTranslation(10, 10));
    
    CGRect titleRect = CGRectMake(80, 12, rect.size.width, 100.0f);
    NSMutableParagraphStyle *style = [[NSParagraphStyle defaultParagraphStyle] mutableCopy];
    UIFont *font = [UIFont fontWithName:@"Lobster" size:22.0f];
    [style setAlignment:NSTextAlignmentCenter];
    NSDictionary *attr = [NSDictionary dictionaryWithObjectsAndKeys:font,NSFontAttributeName,style,NSParagraphStyleAttributeName,[UIColor whiteColor],NSForegroundColorAttributeName, nil];
    [@"Want iBeacons?" drawInRect:titleRect withAttributes:attr];
    
    
    if ([SLComposeViewController isAvailableForServiceType:SLServiceTypeTwitter])
    {
    
        CGContextConcatCTM(ctx, CGAffineTransformMakeRotation(DEGREES_TO_RADIANS(-10)));
        CGContextConcatCTM(ctx, CGAffineTransformMakeTranslation(10, 10));
        titleRect = CGRectMake(-110, 26, rect.size.width, 100.0f);
        [@"Tweet this!" drawInRect:titleRect withAttributes:attr];
    }
    
    
}

@end
