//
//  GlassView.m
//  iBeaconEvent
//
//  Created by Stephen Keep on 08/04/2014.
//  Copyright (c) 2014 Stephen Keep. All rights reserved.
//

#import "GlassView.h"



@interface GlassView ()

@property (strong, nonatomic) UIImageView *waves;

@end

@implementation GlassView

- (id)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        
        [self setupWaves];
        
        UIImage *img = [UIImage imageNamed:@"glass.png"];
        UIImageView *iView = [[UIImageView alloc] initWithFrame:self.bounds];
        [iView setImage:img];
        [self addSubview:iView];
        
        self.clipsToBounds = YES;
        
    }
    return self;
}

-(void) setupWaves {
    
    UIImage *img = [UIImage imageNamed:@"waves.png"];
    self.waves = [[UIImageView alloc] initWithFrame:CGRectMake(0, 230, 223, 152)];
    [_waves setImage:img];
    [self addSubview:_waves];
    
}

- (void) animateWave:(int)divide {
    
    float x, y;
    
    if (divide == 1) {
        x = 40;
        y = 174;
    } else if (divide == 2) {
        x = 80;
        y = 124;
    } else {
        x = 110;
        y = 94;
    }
    
    
    [UIView animateWithDuration:1.0f delay:0.0f options:UIViewAnimationOptionCurveEaseOut animations:^{
        
        _waves.frame = CGRectMake(x, y, 223, 152);
        
    } completion:^(BOOL completed){
        
    }];
}



@end
