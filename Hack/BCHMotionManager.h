//
//  MotionManager.h
//  Hack
//
//  Created by Brian Chu on 7/19/14.
//  Copyright (c) 2014 Brian. All rights reserved.
//

@import CoreMotion;
@import UIKit;

@protocol BCHMotionManagerDelegate
- (void)motionDataDidChange:(NSDictionary *)data;
@end

@interface BCHMotionManager : NSObject
@property (strong, nonatomic) id<BCHMotionManagerDelegate> delegate;
+ (instancetype)sharedInstance;
@end
