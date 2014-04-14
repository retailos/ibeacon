//
//  FinishView.m
//  iBeaconEvent
//
//  Created by Stephen Keep on 08/04/2014.
//  Copyright (c) 2014 Stephen Keep. All rights reserved.
//

#import "FinishView.h"


@interface FinishView ()

@end

@implementation FinishView



- (id)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        self.userInteractionEnabled = NO;
        self.backgroundColor = [UIColor clearColor];
        self.alpha = 0.0f;
    }
    return self;
}

- (void) setDescription:(NSString *)description {
    
    _description = description;
    [self setNeedsDisplay];
    
}

- (void) setOk:(NSString *)ok {
    
    _ok = ok;
    [self setNeedsDisplay];
    
}

- (void) setShow:(BOOL)show {
    
    _show = show;
    [self setNeedsDisplay];
    
    [UIView animateWithDuration:0.3f delay:0.0f options:UIViewAnimationOptionCurveEaseOut animations:^{
        
        self.alpha = _show;
        
    } completion:^(BOOL completed){
        
    }];

}

- (void)drawRect:(CGRect)rect
{
    
    
    if (_show) {
        
        [[UIColor colorWithWhite:0.0f alpha:0.8f] setFill];
        UIRectFill(rect);
        
        //ROTATE THE VIEW
        CGContextRef ctx = UIGraphicsGetCurrentContext();
        CGContextConcatCTM(ctx, CGAffineTransformMakeRotation(DEGREES_TO_RADIANS(-10)));
        CGContextConcatCTM(ctx, CGAffineTransformMakeTranslation(-10, 40));
        
        CGRect bannerRect = CGRectMake(-10.0f, 110.0f, 260, 260);
        [[UIColor whiteColor] setStroke];
        [[UIColor colorWithRed:236/255.0f green:28/255.0f blue:35/255.0f alpha:1.0f] setFill];
        //CGContextFillRect(ctx, bannerRect);
        UIBezierPath *rounded = [UIBezierPath bezierPathWithRoundedRect:bannerRect cornerRadius: 130];
        [rounded fillWithBlendMode: kCGBlendModeNormal alpha:1.0f];
        
        CGRect titleRect = CGRectMake(-30.0f, 94.0f, rect.size.width, 100.0f);
        NSMutableParagraphStyle *style = [[NSParagraphStyle defaultParagraphStyle] mutableCopy];
        UIFont *font = [UIFont fontWithName:@"Lobster" size:36.0f];
        [style setAlignment:NSTextAlignmentCenter];
        NSDictionary *attr = [NSDictionary dictionaryWithObjectsAndKeys:font, NSFontAttributeName, style, NSParagraphStyleAttributeName, [UIColor whiteColor],NSForegroundColorAttributeName, nil];
        [self.title drawInRect:titleRect withAttributes:attr];
        
        
        CGRect descRect = CGRectMake(-30.0f, 170.0f, 300, 180.0f);
        font = [UIFont fontWithName:@"Lobster" size:28.0f];
        [style setAlignment:NSTextAlignmentCenter];
        attr = [NSDictionary dictionaryWithObjectsAndKeys:font, NSFontAttributeName, style, NSParagraphStyleAttributeName, [UIColor whiteColor],NSForegroundColorAttributeName, nil];
        [self.description drawInRect:descRect withAttributes:attr];
        
        //DISPLAY OK
        if (self.ok) {
            [[UIColor whiteColor] setFill];
            CGRect butRect = CGRectMake(160.0f, 318.0f, 80, 80);
            UIBezierPath *roundedRect = [UIBezierPath bezierPathWithRoundedRect:butRect cornerRadius: 40];
            [roundedRect fillWithBlendMode: kCGBlendModeNormal alpha:1.0f];
            butRect = CGRectMake(160.0f, 338.0f, 80, 80);
            attr = [NSDictionary dictionaryWithObjectsAndKeys:font, NSFontAttributeName, style, NSParagraphStyleAttributeName, [UIColor colorWithRed:236/255.0f green:28/255.0f blue:35/255.0f alpha:1.0f],NSForegroundColorAttributeName, nil];
            [self.ok drawInRect:butRect withAttributes:attr];
        }
        
        //DISPLAY SELFIE
        if (self.selfie) {
            CGContextConcatCTM(ctx, CGAffineTransformMakeRotation(DEGREES_TO_RADIANS(20)));
            CGRect imgRect = CGRectMake(80.0f, 280.0f, 160, 160);
            UIBezierPath *path = [UIBezierPath bezierPathWithRoundedRect:imgRect cornerRadius: 80];
            [[UIColor whiteColor] setStroke];
            [path setLineWidth:8.0];
            [path stroke];
            [path addClip];

            [self.selfie drawInRect:imgRect];
        }
        


    }

}

@end
