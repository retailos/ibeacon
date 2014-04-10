//
//  FinishView.h
//  iBeaconEvent
//
//  Created by Stephen Keep on 08/04/2014.
//  Copyright (c) 2014 Stephen Keep. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface FinishView : UIView

@property (strong, nonatomic) NSString* title;
@property (strong, nonatomic) NSString* description;
@property (strong, nonatomic) UIImage *selfie;
@property (strong, nonatomic) NSString *ok;

@property (nonatomic) BOOL show;

@end
