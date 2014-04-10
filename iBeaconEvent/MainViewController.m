//
//  MainViewController.m
//  iBeaconEvent
//
//  Created by Stephen Keep on 07/04/2014.
//  Copyright (c) 2014 Stephen Keep. All rights reserved.
//

#import "MainViewController.h"
#import "BeaconButton.h"
#import "BeaconServices.h"
#import "GlassView.h"
#import "TitleView.h"
#import "FinishView.h"
#import "EAGLView.h"
#import "ES1Renderer.h"
#import "ParticleEmitter.h"
#import "UIImage+ResizeMagick.h"
#import "AFNetworking.h"


@interface MainViewController () <UINavigationControllerDelegate, UIImagePickerControllerDelegate>

@property (strong, nonatomic) NSMutableArray *collected;
@property (strong, nonatomic) NSNumber *selected;
@property (strong, nonatomic) GlassView *gview;
@property (strong, nonatomic) FinishView *fview;
@property (strong, nonatomic) EAGLView *glView;
@property (strong, nonatomic) UIImagePickerController *imagePicker;

@end

@implementation MainViewController

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
        // Custom initialization
    }
    return self;
}

- (void) setupUITitle {
    TitleView *titleView = [[TitleView alloc] initWithFrame:CGRectMake(0, 30, 320, 100)];
    [self.view addSubview:titleView];
}

- (void) setupUIGlass {
    
    self.gview = [[GlassView alloc] initWithFrame:CGRectMake(0, 80, 320, 320)];
    [self.view addSubview:self.gview];
    
}

- (void)setupUIButtons {
    
    NSArray *ingredients = @[@"Booze", @"Ice", @"Juice"];
    
    float beacons = ingredients.count,
          width = (self.view.frame.size.width / beacons),
          height = 140.0f,
          y = self.view.frame.size.height - height;
    
    for (int i = 0; i < beacons; i++) {
        UIButton *button = [UIButton buttonWithType:UIButtonTypeCustom];
        button.frame = CGRectMake((i * width), y, width, height);
        button.tag = i + 100;
        BeaconButton *bbutton = [[BeaconButton alloc] initWithFrame:CGRectMake(0, 0, width, height)];
        bbutton.title = [ingredients objectAtIndex:i];
        bbutton.tag = i + 200;
        bbutton.collected = [[self.collected objectAtIndex:i] boolValue];
        [button addSubview:bbutton];
        [button addTarget:self action:@selector(didPressIngredientButton:) forControlEvents:UIControlEventTouchUpInside];
        [self.view addSubview:button];
    }
    
    UIButton *button = (UIButton *)[self.view viewWithTag:100 + [self.selected intValue]];
    [self.view bringSubviewToFront:button];
    
}

- (void) setupUIFinish {
    self.fview = [[FinishView alloc] initWithFrame:self.view.frame];
    [self.view addSubview:_fview];
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    self.view.backgroundColor = [UIColor colorWithRed:236/255.0f green:28/255.0f blue:35/255.0f alpha:1.0f];

    //self.collected = [@[@YES, @YES, @YES] mutableCopy];
    //[self saveFound];
    
    [self getFound];
    [self setupUIGlass];
    [self setupUITitle];
    [self setupUIButtons];
    [self setupUIFinish];
    [self selectNextAvailableIngredient];
    [self checkEnteredRegion];
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(didUpdateDistance:) name:@"com.redant.distanceChanged" object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(didEnterRegion:) name:@"com.redant.entered" object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(applicationWillResign) name:UIApplicationWillResignActiveNotification object:NULL];
}

-(void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    [self checkAllIngredientsFound];
    
    if ([self getEntered]) {
        [self didEnterRegion:nil];
    }

}

- (void)viewDidUnload
{
    if (_glView) {
        [_glView stopAnimation];
        _glView = nil;
    }
    [super viewDidUnload];
}

-(void)applicationWillResign {
    if (_glView) {
        [_glView stopAnimation];
        _glView = nil;
    }
}

-(void) didPressIngredientButton:(UIButton *)button {
    
    //if the finish view is not being shown then enable the buttons
    if (!self.fview.show) {
        
        BeaconButton *bbutton = (BeaconButton *)[self.view viewWithTag:100 + button.tag];
        
        if (!bbutton.collected) {
            for (int i = 0; i < 3; i++) {
                BeaconButton *fbutton = (BeaconButton *)[self.view viewWithTag:200 + i];
                if (fbutton == bbutton) {
                    
                    [self setSelectedBeaconButton:fbutton withPosition:i];
                    [self.view bringSubviewToFront:button];
                    
                } else {
                    fbutton.selected = NO;
                }
            }
        }
    }
}

-(void) didEnterRegion:(NSNotification *)notif {
    
    if ([self countFound] < self.collected.count) {
        self.fview.show = NO;
    }
    
}

-(void) didUpdateDistance:(NSNotification *)notif {
    
    int distancei = roundf([notif.object floatValue]);
    
    if (distancei < 2) {
        
        [self foundIngredient];
        
    } else if (![[self.collected objectAtIndex:[self.selected intValue]] boolValue]) {
        
        BeaconButton *bbutton = (BeaconButton *)[self.view viewWithTag:200 + [self.selected intValue]];
        
        if (distancei > 100) {
            bbutton.distance = [NSString stringWithFormat:@"%@", [self textForProximity:distancei]];
        } else {
            bbutton.distance = [NSString stringWithFormat:@"%im", distancei];
        }

    }
    
}

- (NSString *)textForProximity:(int)proximity
{
    switch (proximity) {
        case 111:
            return @"Warm";
            break;
        case 222:
            return @"Hot";
            break;
        case 333:
            return @"Boiling";
            break;
            
        default:
            return @"Cold";
            break;
    }
}

-(void)selectNextAvailableIngredient {
    
    for (int i = 0; i < self.collected.count; i++) {
        if (![[self.collected objectAtIndex:i] boolValue]) {
            
            UIButton *button = (UIButton *)[self.view viewWithTag:100 + i];
            BeaconButton *bbutton = (BeaconButton *)[self.view viewWithTag:200 + i];
            
            [self setSelectedBeaconButton:bbutton withPosition:i];
            
            [self.view bringSubviewToFront:button];
            
            break;
        }
    }
}

-(void)setSelectedBeaconButton:(BeaconButton *)bbutton withPosition:(int)position {
    
    self.selected = [NSNumber numberWithInt:position];
    [BeaconServices selectBeacon:position];
    bbutton.distance = [NSString stringWithFormat:@"%@", [self textForProximity:-1]];
    bbutton.selected = YES;
}

-(void) foundIngredient {
    
    BeaconButton *bbutton = (BeaconButton *)[self.view viewWithTag:200 + [self.selected intValue]];
    bbutton.collected = YES;
    bbutton.selected = NO;
    [self.collected replaceObjectAtIndex:[self.selected intValue] withObject:@YES];
   
    int found = [self countFound];
    [self.gview animateWave:found];
    
    if (found == self.collected.count) {
        [self checkAllIngredientsFound];
    } else {
        [self selectNextAvailableIngredient];
    }
    
    [self saveFound];

}

-(int) countFound {
    
    int found = 0;
    for (int i = 0; i < self.collected.count; i++) {
        if ([[self.collected objectAtIndex:i] boolValue]) {
            found++;
        }
    }
    
    return found;
}

-(void)checkAllIngredientsFound {
    
    int found = [self countFound];
    if (found == self.collected.count && !self.fview.show) {
        
        [BeaconServices stopBeacons];
        
        self.fview.title = @"Winning";
        self.fview.description = @"You have found all of the ingredients, tap to take a selfie and collect your free drink!";
        self.fview.ok = @"ok";
        self.fview.show = YES;
        [self.view bringSubviewToFront:self.fview];
        [self startAnimation];
        
        self.imagePicker = [[UIImagePickerController alloc] init];
        
        [self addSelfieButton];
        
    }
}

-(void) addSelfieButton {
    UIButton *button = [UIButton buttonWithType:UIButtonTypeCustom];
    button.frame = CGRectMake(0, 110, 320, 290);
    [button addTarget:self action:@selector(takePicture:) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:button];
}

-(void)checkEnteredRegion {
    
    if (![self getEntered]) {
        self.fview.title = @"iBeacons Event";
        self.fview.description = @"When you are at the event the game will start!";
        self.fview.show = YES;
        [self.view bringSubviewToFront:self.fview];
    }
    
}

/**
 *
 * Save any found beacons to NSUSERDEFAULTS
 *
 */

- (BOOL)getEntered {
    return [[[NSUserDefaults standardUserDefaults] objectForKey:@"com.redant.entered"] boolValue];
}

- (void)getFound {
    self.collected = [[[NSUserDefaults standardUserDefaults] objectForKey:@"com.redant.collected"] mutableCopy];
    if (!self.collected) {
        self.collected = [@[@NO, @NO, @NO] mutableCopy];
        [self saveFound];
    }
}

- (void)saveFound {
    [[NSUserDefaults standardUserDefaults] setObject:self.collected forKey:@"com.redant.collected"];
    [[NSUserDefaults standardUserDefaults] synchronize];
}

/**
 *
 * Start Bubble Animation
 *
 */

static float defaultPath[41][2] = {
    {0.0, 580.0},
    {320.0, 580.0},
    {0.0, 580.0},
    {320.0, 580.0},
    {0.0, 580.0},
    {320.0, 580.0},
    {0.0, 580.0},
    {320.0, 580.0},
    {0.0, 580.0},
    {320.0, 580.0},
    {0.0, 580.0},
    {320.0, 580.0},
    {0.0, 580.0},
    {320.0, 580.0},
    {0.0, 580.0},
    {320.0, 580.0},
    {0.0, 580.0},
    {320.0, 580.0},
    {0.0, 580.0},
    {320.0, 580.0},
    {0.0, 580.0},
    {320.0, 580.0},
    {0.0, 580.0},
    {320.0, 580.0},
    {0.0, 580.0},
    {320.0, 580.0},
    {0.0, 580.0},
    {320.0, 580.0},
    {0.0, 580.0},
    {320.0, 580.0},
    {0.0, 580.0},
    {320.0, 580.0},
    {0.0, 580.0},
    {320.0, 580.0},
    {0.0, 580.0},
    {320.0, 580.0},
    {0.0, 580.0},
    {320.0, 580.0},
    {0.0, 580.0},
    {320.0, 580.0},
    {0.0, 580.0}
    
};

- (void)startAnimation {
    
    self.glView = [[EAGLView alloc] initWithFrame:[UIScreen mainScreen].bounds];
    _glView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight | UIViewAutoresizingFlexibleBottomMargin;
    [self.view addSubview:_glView];
    [_glView startAnimation];

    
    ((ES1Renderer*)_glView.renderer).emitter.speed = 20.0f;
    ((ES1Renderer*)_glView.renderer).emitter.speedVariance = 120.0f;
    ((ES1Renderer*)_glView.renderer).emitter.particleLifespan = 2.0f;
    ((ES1Renderer*)_glView.renderer).emitter.particleLifespanVariance = 120.0f;
    ((ES1Renderer*)_glView.renderer).emitter.maxParticles = 100.0f;
    ((ES1Renderer*)_glView.renderer).emitter.duration = 4.0f;
    ((ES1Renderer*)_glView.renderer).emitter.gravity = Vector2fMake(0.0f, 100.0f);
    
    CGMutablePathRef myPath = CGPathCreateMutable();
    
    for (int i = 0; i < 41; i++) {
        CGPoint point = CGPointMake(defaultPath[i][0], self.view.bounds.size.height - defaultPath[i][1]);
        
        if (i == 0) {
            CGPathMoveToPoint(myPath, NULL, point.x, point.y);
        } else {
            CGPathAddLineToPoint(myPath, NULL, point.x, point.y);
        }
    }
    
    CGPathCloseSubpath( myPath );
    [_glView.renderer starPathAnimationAt:myPath];
    CGPathRelease(myPath);
}

/**
 *
 * Take a selfie
 *
 */

-(void) takePicture:(id) sender
{
    if([UIImagePickerController isSourceTypeAvailable:UIImagePickerControllerSourceTypeCamera])
    {
        [_imagePicker setSourceType:UIImagePickerControllerSourceTypeCamera];
        _imagePicker.cameraDevice = UIImagePickerControllerCameraDeviceFront;

    }
    else
    {
        [_imagePicker setSourceType:UIImagePickerControllerSourceTypePhotoLibrary];
    }
    [_imagePicker setDelegate:self];
    [self presentViewController:_imagePicker animated:YES completion:nil];
    [sender removeFromSuperview];
}

-(void)imagePickerController:(UIImagePickerController *)picker didFinishPickingMediaWithInfo:(NSDictionary *)info {
    
    UIImage *img = [[info objectForKey:UIImagePickerControllerOriginalImage] resizedImageByMagick: @"604x604#"];
    
    self.fview.selfie = img;
    self.fview.ok = nil;
    self.fview.description = @"Thanks, someone will deliver your drink soon!";
    [picker dismissViewControllerAnimated:YES completion:nil];
    
    NSData *data = UIImageJPEGRepresentation(img, 0.6);
    NSString *encoded = [data base64EncodedStringWithOptions:kNilOptions];

    //[self sendEmail:encoded];
}

-(void)imagePickerControllerDidCancel:(UIImagePickerController *)picker {
    [self addSelfieButton];
    [picker dismissViewControllerAnimated:YES completion:nil];
}

-(void)sendEmail:(NSString *)image {
    
    AFHTTPRequestOperationManager *manager = [AFHTTPRequestOperationManager manager];
    
    NSString *html = [NSString stringWithFormat:@"<img src='data:image/png;base64, %@' width='302px' height='302px'/>", image];
    
    NSDictionary *to = @{@"email": @"stephen.keep@redant.com", @"name":@"Stephen Keep", @"type":@"to"};
    NSDictionary *message = @{@"from_email": @"retailosdev@redant.com", @"autotext": @"true", @"subject": @"Free Drink", @"html": html, @"to": @[to]};
    NSDictionary *parameters = @{@"key": @"qXkX37-1JLhbbRPPKODWMg", @"message": message};
    
    [manager POST:@"https://mandrillapp.com/api/1.0/messages/send.json" parameters:parameters success:^(AFHTTPRequestOperation *operation, id responseObject) {
        NSLog(@"JSON: %@", responseObject);
    } failure:^(AFHTTPRequestOperation *operation, NSError *error) {
        NSLog(@"Error: %@", error);
    }];
    
}

@end
