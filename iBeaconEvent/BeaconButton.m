//
//  BeaconButton.m
//  iBeaconEvent
//
//  Created by Stephen Keep on 07/04/2014.
//  Copyright (c) 2014 Stephen Keep. All rights reserved.
//

#import "BeaconButton.h"
#import <QuartzCore/QuartzCore.h>

static CGFloat const kDashedPhase           = (0.0f);
static CGFloat const kDashedLinesLength[]   = {4.0f, 2.0f};
static size_t const kDashedCount            = (2.0f);

@interface BeaconButton ()

@property (strong, nonatomic) UIView *circle;

@end

@implementation BeaconButton



- (id)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        self.userInteractionEnabled = NO;
        
    }
    return self;
}

- (void) setDistance:(NSString *)distance {
    _distance = distance;
    [self setNeedsDisplay];
}

- (void) setSelected:(BOOL)selected {
    if (!_collected) {
        
        _selected = selected;
        
        if (_selected) {
            
            self.circle = [[UIView alloc] initWithFrame:CGRectMake(self.frame.origin.x + 9.0f, self.frame.origin.y + 9.0f, self.frame.size.width - 18.0f, self.frame.size.width - 18.0f)];
            _circle.layer.borderColor = [UIColor whiteColor].CGColor;
            _circle.layer.borderWidth = 1.0f;
            _circle.layer.cornerRadius = self.circle.frame.size.width / 2;
            [self addSubview:_circle];
            [self performSelector:@selector(pulse) withObject:nil afterDelay:0.0f];
            
        } else {
            
            [self.circle removeFromSuperview];
            _distance = @"";
        }

        [self setNeedsDisplay];
    } else {
        _selected = NO;
    }
}

- (void) setCollected:(BOOL)collected {
    _collected = collected;
    
    if (_collected) {
        _distance = @"tick";
    }
    
    [self setNeedsDisplay];
}

- (void) pulse {
    
    [UIView animateWithDuration:1.0f delay:0.0f options:UIViewAnimationOptionCurveEaseOut animations:^{
        
        self.circle.transform = CGAffineTransformScale(self.circle.transform, 3.0f, 3.0f);
        self.circle.alpha = 0.0f;
        
    } completion:^(BOOL completed){
        
        self.circle.transform = CGAffineTransformIdentity;
        self.circle.alpha = 1.0f;
        
        if (_selected) {
            [self pulse];
        }
        
    }];
}


- (void)drawRect:(CGRect)rect
{
    [[UIColor colorWithRed:236/255.0f green:28/255.0f blue:35/255.0f alpha:1.0f]setFill];
    [[UIColor whiteColor] setStroke];
    UIRectFill(rect);
    
    CGRect circleRect = CGRectMake(rect.origin.x + 9.0f, rect.origin.y + 9.0f, rect.size.width - 18.0f, rect.size.width - 18.0f);
    CGContextRef ctx = UIGraphicsGetCurrentContext();
    CGContextAddEllipseInRect(ctx, circleRect);
    
    CGRect imgRect = CGRectMake(rect.size.width/2 - 30.0f, circleRect.size.height/2 - 22.0f, 60.0f, 60.0f);
    UIImage *img = [UIImage imageNamed:[NSString stringWithFormat:@"%@.png",[_title lowercaseString]]];
    [img drawInRect:imgRect];
    
    if (_collected || _selected) {
        [[UIColor colorWithWhite:1.0f alpha:0.8f] setFill];
        CGContextFillPath(ctx);
    }
    
    if (! _selected) {
        CGContextSetLineDash(ctx, kDashedPhase, kDashedLinesLength, kDashedCount) ;
    }
    
    CGContextStrokePath(ctx);
    
    if (_selected || _distance) {
        CGRect titleRect = CGRectMake(0, (circleRect.size.height/2) - 15.0f, rect.size.width, 38.0f);
        NSMutableParagraphStyle *style = [[NSParagraphStyle defaultParagraphStyle] mutableCopy];
        UIFont *font = [UIFont fontWithName:@"Lobster" size:36.0f];
        [style setAlignment:NSTextAlignmentCenter];
        NSDictionary *attr = [NSDictionary dictionaryWithObjectsAndKeys:font,NSFontAttributeName,style,NSParagraphStyleAttributeName,[UIColor colorWithRed:236/255.0f green:28/255.0f blue:35/255.0f alpha:1.0f],NSForegroundColorAttributeName, nil];
        [_distance drawInRect:titleRect withAttributes:attr];
    }
    
    //ROTATE THE VIEW
    CGContextConcatCTM(ctx, CGAffineTransformMakeRotation(DEGREES_TO_RADIANS(-25)));
    CGContextConcatCTM(ctx, CGAffineTransformMakeTranslation(-30, 0));
    
    CGRect titleRect = CGRectMake(0, rect.size.height - 38.0f, rect.size.width, 30.0f);
    NSMutableParagraphStyle *style = [[NSParagraphStyle defaultParagraphStyle] mutableCopy];
    UIFont *font = [UIFont fontWithName:@"Lobster" size:22.0f];
    [style setAlignment:NSTextAlignmentCenter];
    NSDictionary *attr = [NSDictionary dictionaryWithObjectsAndKeys:font,NSFontAttributeName,style,NSParagraphStyleAttributeName,[UIColor whiteColor],NSForegroundColorAttributeName, nil];
    [self.title drawInRect:titleRect withAttributes:attr];
    
    
    
}


@end
