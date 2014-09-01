//
//  MotionManager.m
//  Hack
//
//  Created by Brian Chu on 7/19/14.
//  Copyright (c) 2014 Brian. All rights reserved.
//

#import "BCHMotionManager.h"
#import "BCHDataManager.h"
@import CoreMotion;

@interface BCHMotionManager ()
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
        // start connections:
        [BCHDataManager sharedInstance];

        self.motionManager = [[CMMotionManager alloc] init];
        self.motionQueue = [[NSOperationQueue alloc] init];
        self.motionQueue.qualityOfService = NSQualityOfServiceBackground;
        
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(applicationBackground:) name:UIApplicationDidEnterBackgroundNotification object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(applicationForeground:) name:UIApplicationDidBecomeActiveNotification object:nil];
        [self applicationForeground:nil];
        
        // default: 0.2 (seconds)
//        self.motionManager.accelerometerUpdateInterval;
        // default: 0.2 (seconds)
//        self.motionManager.gyroUpdateInterval;
        // default: 0.01 (seconds)
        // 0.016s is 60 fps
        // 0.033 is 30 fps
        self.motionManager.deviceMotionUpdateInterval = 0.033;
        // default: 0.025 (seconds)
//        self.motionManager.magnetometerUpdateInterval;


    }
    return self;
}

- (void)applicationBackground:(NSNotification *)notification
{
    [self.motionManager stopDeviceMotionUpdates];
}

- (void)applicationForeground:(NSNotification *)notification
{
    // default is CMAttitudeReferenceFrameXArbitraryZVertical
    [self.motionManager startDeviceMotionUpdatesUsingReferenceFrame:CMAttitudeReferenceFrameXArbitraryCorrectedZVertical
                                                            toQueue:self.motionQueue
                                                        withHandler:^(CMDeviceMotion *motion, NSError *error) {
                                                            if(error){
                                                                NSLog(@"gyro error: %@", error);
                                                            }
                                                            [self handleDeviceMotionData:motion];
                                                        }];
}

- (void)handleDeviceMotionData:(CMDeviceMotion *)data
{
    MotionData params;
    NSMutableDictionary *otherParams = [NSMutableDictionary dictionary];
    
    CMAttitude *attitude = data.attitude;
    CMRotationRate rotationRate = data.rotationRate;
    CMAcceleration userAccelerationVector = data.userAcceleration;

//    CMAcceleration gravityAccelerationVector = data.gravity;
//    CMMagneticField calibratedMagneticField = data.magneticField.field;

    CMQuaternion quaternion = attitude.quaternion;
    params.x = quaternion.x;
    params.y = quaternion.y;
    params.z = quaternion.z;
    params.w = quaternion.w;
    
    /*
     This property yields a measurement of the device’s rate of rotation around three axes.
     
     The X-axis rotation rate in radians per second. The sign follows the right hand rule: If the right hand is wrapped around the X axis such that the tip of the thumb points toward positive X, a positive rotation is one toward the tips of the other four fingers.
     The Y-axis rotation rate in radians per second. The sign follows the right hand rule: If the right hand is wrapped around the Y axis such that the tip of the thumb points toward positive Y, a positive rotation is one toward the tips of the other four fingers.
     The Z-axis rotation rate in radians per second. The sign follows the right hand rule: If the right hand is wrapped around the Z axis such that the tip of the thumb points toward positive Z, a positive rotation is one toward the tips of the other four fingers
     */
    double rotX = rotationRate.x;
    double rotY = rotationRate.y;
    double rotZ = rotationRate.z;
    params.rotX = rotX;
    params.rotY = rotY;
    params.rotZ = rotZ;
    
    /*
     X-axis acceleration in G's (gravitational force).
     Y-axis acceleration in G's (gravitational force).
     Z-axis acceleration in G's (gravitational force).
     */
    double accelX = userAccelerationVector.x;
    double accelY = userAccelerationVector.y;
    double accelZ = userAccelerationVector.z;
    params.accelX = accelX;
    params.accelY = accelY;
    params.accelZ = accelZ;
    
    [[BCHDataManager sharedInstance] postMotionUpdate:params otherParams:otherParams];
}

@end
