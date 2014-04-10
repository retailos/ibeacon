//
//  ARLocationServices.h
//  Topshop
//
//  Created by Stephen Keep on 04/06/2013.
//  Copyright (c) 2013 Red Ant Ltd. All rights reserved.
//

#import <Foundation/Foundation.h>


@interface BeaconServices : NSObject


+ (void)setupBeacons:(NSArray *)beacons;
+ (void)selectBeacon:(int)beacon;
+ (void)sendLocalNotification:(NSString *)message;
+ (void)stopBeacons;

@end
