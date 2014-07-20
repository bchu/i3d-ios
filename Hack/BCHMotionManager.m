//
//  MotionManager.m
//  Hack
//
//  Created by Brian Chu on 7/19/14.
//  Copyright (c) 2014 Brian. All rights reserved.
//

#import "BCHMotionManager.h"
#import <AFNetworking/AFNetworking.h>

static NSString *const BCH_API_SOCKET_URL = @"http://df49858.ngrok.com/updateWS";
static NSString *const BCH_API_SOCKET_URL_SECONDARY = @"http://d2e05a5.ngrok.com/updateWS";
static NSString *const BCH_API_URL = @"http://df49858.ngrok.com/update";
static NSString *const BCH_API_URL_SECONDARY = @"http://d2e05a5.ngrok.com/update";
static NSString *const BCH_API_IMAGE = @"http://df49858.ngrok.com/screencast";
static NSString *const BCH_API_IMAGE_SECONDARY = @"http://d2e05a5.ngrok.com/screencast";

typedef struct MotionData {
    double x;
    double y;
    double z;
    double w;
    double rotX;
    double rotY;
    double rotZ;
    double accelX;
    double accelY;
    double accelZ;
} MotionData;

@interface BCHMotionManager () <SRWebSocketDelegate>
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
        SRWebSocket *webSocket = [[SRWebSocket alloc] initWithURL:[NSURL URLWithString:BCH_API_SOCKET_URL]];
        webSocket.delegate = self;
        [webSocket open];
        self.webSocket = webSocket;
        SRWebSocket *webSocketSecondary = [[SRWebSocket alloc] initWithURL:[NSURL URLWithString:BCH_API_SOCKET_URL_SECONDARY]];
        [webSocketSecondary open];
        webSocketSecondary.delegate = self;
        self.webSocketSecondary = webSocketSecondary;
        self.httpManager = [AFHTTPRequestOperationManager manager];
        
        self.currentMaxAccelX = 0;
        self.currentMaxAccelY = 0;
        self.currentMaxAccelZ = 0;
        self.currentMaxRotX = 0;
        self.currentMaxRotY = 0;
        self.currentMaxRotZ = 0;
        
        self.motionManager = [[CMMotionManager alloc] init];
        NSOperationQueue *motionQueue = [[NSOperationQueue alloc] init];
        

        // default: 0.2 (seconds)
//        self.motionManager.accelerometerUpdateInterval;
        // default: 0.2 (seconds)
//        self.motionManager.gyroUpdateInterval;
        // default: 0.01 (seconds)
        self.motionManager.deviceMotionUpdateInterval = 0.1;
        // default: 0.025 (seconds)
//        self.motionManager.magnetometerUpdateInterval;


        /*
        [self.motionManager startAccelerometerUpdatesToQueue:motionQueue
                                                 withHandler:^(CMAccelerometerData  *accelerometerData, NSError *error) {
             if(error){
                 NSLog(@"accelerometer error: %@", error);
             }
             [self handleAccelerationData:accelerometerData.acceleration];
             [self outputAccelerationData:accelerometerData.acceleration];
        }];

        [self.motionManager startGyroUpdatesToQueue:motionQueue
                                        withHandler:^(CMGyroData *gyroData, NSError *error) {
            if(error){
                NSLog(@"gyro error: %@", error);
            }
            [self handleGyroData:gyroData.rotationRate];
            [self outputRotationData:gyroData.rotationRate];
        }];
        
        [self.motionManager startMagnetometerUpdatesToQueue:motionQueue
                                                withHandler:^(CMMagnetometerData *magnetometerData, NSError *error) {
                                                    if(error){
                                                        NSLog(@"gyro error: %@", error);
                                                    }
                                                    [self handleMagnetometerData:magnetometerData];
                                                }];
        */
        // default is CMAttitudeReferenceFrameXArbitraryZVertical
        [self.motionManager startDeviceMotionUpdatesUsingReferenceFrame:CMAttitudeReferenceFrameXArbitraryCorrectedZVertical
                                                                toQueue:motionQueue
                                                            withHandler:^(CMDeviceMotion *motion, NSError *error) {
            if(error){
                NSLog(@"gyro error: %@", error);
            }
            [self handleDeviceMotionData:motion];
        }];
        

    }
    return self;
}

- (void)handleDeviceMotionData:(CMDeviceMotion *)data
{
    MotionData params;
    NSMutableDictionary *otherParams = [NSMutableDictionary dictionary];
    
    CMAttitude *attitude = data.attitude;
    CMRotationRate rotationRate = data.rotationRate;
    CMAcceleration userAccelerationVector = data.userAcceleration;

    CMAcceleration gravityAccelerationVector = data.gravity;
    CMMagneticField calibratedMagneticField = data.magneticField.field;

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
    
    [self postUpdate:params otherParams:otherParams];
}

- (void)postUpdate:(MotionData)data otherParams:(NSDictionary *)otherParams
{
//    NSLog(@"\nrotX: %f \nrotY: %f\nrotZ: %f \n", data.rotX, data.rotY, data.rotZ);
//    NSLog(@"\naccelX: %f \naccelY: %f\naccelZ: %f \n", data.accelX, data.accelY, data.accelZ);
    static AFHTTPRequestOperationManager *manager;
    if (!manager) {
        manager = [AFHTTPRequestOperationManager manager];
    }

    // default is form-encoded request, change to use JSON
    manager.requestSerializer = [AFJSONRequestSerializer serializer];
    NSDictionary *parameters = @{
                                     @"rotationRateX": @(data.rotX),
                                     @"rotationRateY": @(data.rotY),
                                     @"rotationRateZ": @(data.rotZ),
                                     @"quaternion":@[@(data.x), @(data.y), @(data.z), @(data.w)]
                                 };
    AFHTTPRequestOperation *operation = [manager POST:BCH_API_URL parameters:parameters success:^(AFHTTPRequestOperation *operation, id responseObject) {
    } failure:^(AFHTTPRequestOperation *operation, NSError *error) {
        NSLog(@"\nError: %@", error);
    }];
    AFHTTPRequestOperation *operationSecondary = [manager POST:BCH_API_URL_SECONDARY parameters:parameters success:^(AFHTTPRequestOperation *operation, id responseObject) {
    } failure:^(AFHTTPRequestOperation *operation, NSError *error) {
        NSLog(@"\nError: %@", error);
    }];
}




- (void)handleAccelerationData:(CMAcceleration)data
{

    CGFloat x = data.x;
    CGFloat y = data.y;
    CGFloat z = data.z;
}

- (void)handleGyroData:(CMRotationRate)data
{
    /*
     The X-axis rotation rate in radians per second. The sign follows the right hand rule: If the right hand is wrapped around the X axis such that the tip of the thumb points toward positive X, a positive rotation is one toward the tips of the other four fingers.
     The Y-axis rotation rate in radians per second. The sign follows the right hand rule: If the right hand is wrapped around the Y axis such that the tip of the thumb points toward positive Y, a positive rotation is one toward the tips of the other four fingers.
     The Z-axis rotation rate in radians per second. The sign follows the right hand rule: If the right hand is wrapped around the Z axis such that the tip of the thumb points toward positive Z, a positive rotation is one toward the tips of the other four fingers
     */
    CGFloat x = data.x;
    CGFloat y = data.y;
    CGFloat z = data.z;
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
