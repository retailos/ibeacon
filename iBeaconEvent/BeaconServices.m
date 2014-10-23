//
//  ARLocationServices.m
//  Topshop
//
//  Created by Stephen Keep on 04/06/2013.
//  Copyright (c) 2013 Red Ant Ltd. All rights reserved.
//

#import "BeaconServices.h"
#import "ESTBeaconManager.h"

@interface BeaconServices () <CLLocationManagerDelegate, ESTBeaconManagerDelegate>

@property (nonatomic, strong) CLLocationManager* locationManager;
@property (nonatomic, strong) ESTBeaconManager* beaconManager;
@property (nonatomic) int selectedBeacon;
@property (nonatomic) BOOL entered;
@property (strong, nonatomic) NSArray *beacons;
@property (strong, nonatomic) ESTBeaconRegion *beaconRegion;
@property (strong, nonatomic) NSArray *ingredients;
@property (strong, nonatomic) NSMutableArray *notified;

@end

@implementation BeaconServices

PureSingleton(BeaconServices)

- (id)init {
    self = [super init];
    
    if(self) {
        
        [self getEntered];
        
        NSUUID *uuid = [[NSUUID alloc] initWithUUIDString:@"B9407F30-F5F8-466E-AFF9-25556B57FE6D"];
        
        self.ingredients = @[@"Booze", @"Ice", @"Juice"];
        self.notified = [@[@NO, @NO, @NO] mutableCopy];
        
        CBCentralManager* testBluetooth = [[CBCentralManager alloc] initWithDelegate:nil queue: nil];
        
        // create manager instance
        self.beaconManager = [[ESTBeaconManager alloc] init];
        self.beaconManager.delegate = self;
        
        // create sample region object (you can additionaly pass major / minor values)
        self.beaconRegion = [[ESTBeaconRegion alloc] initWithProximityUUID:uuid identifier:@"MyBeacon"];
        self.beaconRegion.notifyEntryStateOnDisplay = YES;
        self.beaconRegion.notifyOnEntry = YES;
        self.beaconRegion.notifyOnExit = YES;
                             
        [self.beaconManager startRangingBeaconsInRegion:self.beaconRegion];
        [self.beaconManager startMonitoringForRegion:self.beaconRegion];
        
        self.entered = YES;
        [self saveEntered];
        
        if (!self.entered) {
            
            // create location region object (you can additionaly pass major / minor values)
            CLLocationCoordinate2D center = CLLocationCoordinate2DMake(51.507400, -0.219894);
            CLLocationDistance radius = 200; // 200 meters
            CLCircularRegion *region = [[CLCircularRegion alloc] initWithCenter:center radius:radius identifier:@"Event"];
            
            self.locationManager = [[CLLocationManager alloc] init];
            _locationManager.delegate = self;
            [_locationManager startUpdatingLocation];
            [self.locationManager startMonitoringForRegion:region];
        }
         
    }
    
    return self;
}


+ (void)setupBeacons:(NSArray *)beacons {
    [[BeaconServices shared] setBeacons:beacons];
}

+ (void)selectBeacon:(int)beacon {
    [[BeaconServices shared] selectBeacon:beacon];
}

+ (void)sendLocalNotification:(NSString *)message {
    [[BeaconServices shared] sendLocalNotification:message];
}

+ (void)stopBeacons {
    //[[BeaconServices shared] stopBeacons];
}

- (void) selectBeacon:(int)beacon {
    self.selectedBeacon = beacon;
}

- (void) stopBeacons {
    [self.beaconManager stopMonitoringForRegion:self.beaconRegion];
    [self.beaconManager stopRangingBeaconsInRegion:self.beaconRegion];
}

-(BOOL)locationEnabled {
    
    if (CLLocationManager.authorizationStatus == kCLAuthorizationStatusAuthorized) {
        return YES;
    } else if (CLLocationManager.authorizationStatus == kCLAuthorizationStatusDenied) {
        UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Location Service Disabled"
                                                        message:@"To re-enable, please go to Settings and turn on Location Service for this app."
                                                       delegate:nil
                                              cancelButtonTitle:@"OK"
                                              otherButtonTitles:nil];
        [alert show];
        
        return NO;
    }
    
    return NO;
    
}

- (void)beaconManager:(ESTBeaconManager *)manager didRangeBeacons:(NSArray *)beacons inRegion:(ESTBeaconRegion *)region {
    
    for (ESTBeacon *beacon in beacons) {
        NSString *major = [NSString stringWithFormat:@"%@",beacon.major];
        
        int beaconIndex = (int)[self.beacons indexOfObject:major];
        
        if (self.selectedBeacon == beaconIndex) {
 
            [self postDistanceOfSelectedBeacon:beacon];
            
            if (!self.entered) {
                self.entered = YES;
                [self saveEntered];
            }
            
        }
        
        [self shouldSendNotificationForIndex:beaconIndex withDistance:beacon.distance];
    
    }
}

- (void) postDistanceOfSelectedBeacon:(ESTBeacon *)beacon {
    
    int distancei = roundf([beacon.distance floatValue]);
    
    if (distancei != -1) {
        [[NSNotificationCenter defaultCenter] postNotificationName:@"com.redant.distanceChanged" object:beacon.distance];
    } else {
        [[NSNotificationCenter defaultCenter] postNotificationName:@"com.redant.distanceChanged" object:[self numberForProximity:beacon.proximity]];
    }
}

- (NSNumber *)numberForProximity:(CLProximity)proximity
{
    switch (proximity) {
        case CLProximityFar:
            return @111;
            break;
        case CLProximityNear:
            return @222;
            break;
        case CLProximityImmediate:
            return @333;
            break;
        default:
            return @444;
            break;
    }
}


- (void)locationManager:(CLLocationManager *)manager didEnterRegion:(CLRegion *)region {
    if ([region.identifier isEqualToString:@"Event"]) {
        self.entered = YES;
        [self saveEntered];
        [self sendLocalNotification:@"Welcome to the iBeacons Event"];
    }
}

- (void)shouldSendNotificationForIndex:(int)beaconIndex withDistance:(NSNumber *)distance {
    
    UIApplicationState state = [[UIApplication sharedApplication] applicationState];
    
    if ((state == UIApplicationStateBackground || state == UIApplicationStateInactive) && ![[self.notified objectAtIndex:beaconIndex] boolValue])
    {
        if (![self isFound:beaconIndex]) {
            int distancei = roundf([distance floatValue]);
            if (distancei > -1 && distancei < 4) {
                [BeaconServices sendLocalNotification:[NSString stringWithFormat:@"You are near the %@ iBeacon", [_ingredients objectAtIndex:beaconIndex]]];
                [self.notified replaceObjectAtIndex:beaconIndex withObject:@YES];
            }
        }
    }
}

- (void) sendLocalNotification:(NSString *)message {
    
    UILocalNotification *notification = [[UILocalNotification alloc]init];
    notification.repeatInterval = NSDayCalendarUnit;
    [notification setAlertBody:message];
    [notification setFireDate:[NSDate dateWithTimeIntervalSinceNow:1]];
    [notification setTimeZone:[NSTimeZone  defaultTimeZone]];
    [[UIApplication sharedApplication] setScheduledLocalNotifications:[NSArray arrayWithObject:notification]];
    
}

/**
 *
 * Save any found beacons to NSUSERDEFAULTS
 *
 */

-(void)getEntered {
    self.entered = [[[NSUserDefaults standardUserDefaults] objectForKey:@"com.redant.entered"] boolValue];
}

-(void)saveEntered {
    [[NSUserDefaults standardUserDefaults] setObject:[NSNumber numberWithBool:self.entered] forKey:@"com.redant.entered"];
    [[NSUserDefaults standardUserDefaults] synchronize];
    [[NSNotificationCenter defaultCenter] postNotificationName:@"com.redant.entered" object:nil];
}

- (BOOL)isFound:(int)position {
    NSArray *collected = [[NSUserDefaults standardUserDefaults] objectForKey:@"com.redant.collected"];
    return [[collected objectAtIndex:position] boolValue];
}



@end
