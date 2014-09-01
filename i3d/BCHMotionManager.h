//
//  MotionManager.h
//  Hack
//
//  Created by Brian Chu on 7/19/14.
//  Copyright (c) 2014 Brian. All rights reserved.
//
@import UIKit;

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

@interface BCHMotionManager : NSObject
@property (strong, nonatomic) NSOperationQueue *motionQueue;
+ (instancetype)sharedInstance;
@end
