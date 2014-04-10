//
//  BeaconButton.h
//  iBeaconEvent
//
//  Created by Stephen Keep on 07/04/2014.
//  Copyright (c) 2014 Stephen Keep. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface BeaconButton : UIView

@property (strong, nonatomic) NSString* title;
@property (strong, nonatomic) NSString* distance;
@property (nonatomic) BOOL selected;
@property (nonatomic) BOOL collected;

@end
