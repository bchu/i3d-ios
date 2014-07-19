//
//  MotionManager.m
//  Hack
//
//  Created by Brian Chu on 7/19/14.
//  Copyright (c) 2014 Brian. All rights reserved.
//

#import "BCHMotionManager.h"

@interface BCHMotionManager ()
@property (nonatomic) double currentMaxAccelX;
@property (nonatomic) double currentMaxAccelY;
@property (nonatomic) double currentMaxAccelZ;
@property (nonatomic) double currentMaxRotX;
@property (nonatomic) double currentMaxRotY;
@property (nonatomic) double currentMaxRotZ;
@property (strong, nonatomic) CMMotionManager *motionManager;
@end

@implementation BCHMotionManager

+ (instancetype)sharedInstance
{
    static BCHMotionManager *shared;
    static dispatch_once_t pred;
    dispatch_once(&pred, ^{
        shared = [[self alloc] initPrivate];
    });
    return shared;
}

- (instancetype)initPrivate
{
    self = [super init];
    if (self) {
        self.currentMaxAccelX = 0;
        self.currentMaxAccelY = 0;
        self.currentMaxAccelZ = 0;
        self.currentMaxRotX = 0;
        self.currentMaxRotY = 0;
        self.currentMaxRotZ = 0;
        
        self.motionManager = [[CMMotionManager alloc] init];
        self.motionManager.accelerometerUpdateInterval = .2;
        self.motionManager.gyroUpdateInterval = .2;
        
        NSOperationQueue *motionQueue = [[NSOperationQueue alloc] init];
        
        // default: 0.2 (seconds)
        self.motionManager.accelerometerUpdateInterval;
        // default: 0.2 (seconds)
        self.motionManager.gyroUpdateInterval;
        // default: 0.01 (seconds)
        self.motionManager.deviceMotionUpdateInterval;
        // default: 0.025 (seconds)
        self.motionManager.magnetometerUpdateInterval;

        [self.motionManager startAccelerometerUpdatesToQueue:motionQueue
                                                 withHandler:^(CMAccelerometerData  *accelerometerData, NSError *error) {
             if(error){
                 NSLog(@"accelerometer error: %@", error);
             }
             [self handleAccelerationData:accelerometerData];
             [self outputAccelerationData:accelerometerData.acceleration];
        }];

        [self.motionManager startGyroUpdatesToQueue:motionQueue
                                        withHandler:^(CMGyroData *gyroData, NSError *error) {
            if(error){
                NSLog(@"gyro error: %@", error);
            }
            [self handleGyroData:gyroData];
            [self outputRotationData:gyroData.rotationRate];
        }];

        [self.motionManager startDeviceMotionUpdatesToQueue:motionQueue
                                                withHandler:^(CMDeviceMotion *motion, NSError *error) {
            if(error){
                NSLog(@"gyro error: %@", error);
            }
            [self handleDeviceMotionData:motion];
        }];
        
        [self.motionManager startMagnetometerUpdatesToQueue:motionQueue
                                                withHandler:^(CMMagnetometerData *magnetometerData, NSError *error) {
            if(error){
                NSLog(@"gyro error: %@", error);
            }
            [self handleMagnetometerData:magnetometerData];
        }];
    }
    return self;
}

- (void)handleAccelerationData:(CMAccelerometerData *)data
{
    
}

- (void)handleGyroData:(CMGyroData *)data
{
    
}

- (void)handleDeviceMotionData: (CMDeviceMotion *)data
{
    
}

- (void)handleMagnetometerData:(CMMagnetometerData *)data
{
    
}

-(void)outputAccelerationData:(CMAcceleration)acceleration
{
    CGFloat x = acceleration.x;
    CGFloat y = acceleration.y;
    CGFloat z = acceleration.z;
    NSLog(@"x accel: %f", x);
    NSLog(@"y accel: %f", y);
    NSLog(@"z accel: %f", z);
    if(fabs(acceleration.x) > fabs(self.currentMaxAccelX))
    {
        self.currentMaxAccelX = acceleration.x;
    }
    if(fabs(acceleration.y) > fabs(self.currentMaxAccelY))
    {
        self.currentMaxAccelY = acceleration.y;
    }
    if(fabs(acceleration.z) > fabs(self.currentMaxAccelZ))
    {
        self.currentMaxAccelZ = acceleration.z;
    }
}

-(void)outputRotationData:(CMRotationRate)rotation
{
    CGFloat x = rotation.x;
    CGFloat y = rotation.y;
    CGFloat z = rotation.z;
    NSLog(@"x rot: %f", x);
    NSLog(@"y rot: %f", y);
    NSLog(@"z rot: %f", z);
    if(fabs(rotation.x) > fabs(self.currentMaxRotX))
    {
        self.currentMaxRotX = rotation.x;
    }
    if(fabs(rotation.y) > fabs(self.currentMaxRotY))
    {
        self.currentMaxRotY = rotation.y;
    }
    if(fabs(rotation.z) > fabs(self.currentMaxRotZ))
    {
        self.currentMaxRotZ = rotation.z;
    }
}

@end
