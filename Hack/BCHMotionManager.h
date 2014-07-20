//
//  MotionManager.h
//  Hack
//
//  Created by Brian Chu on 7/19/14.
//  Copyright (c) 2014 Brian. All rights reserved.
//

@import CoreMotion;
@import UIKit;
#import <AFNetworking/AFNetworking.h>
#import <SocketRocket/SRWebSocket.h>

@protocol BCHMotionManagerDelegate
- (void)motionDataDidChange:(NSDictionary *)data;
@end

@interface BCHMotionManager : NSObject
@property (strong, nonatomic) id<BCHMotionManagerDelegate> delegate;
// SRWebSocket retains itself between open and close
@property (weak, nonatomic) SRWebSocket *webSocket;
@property (weak, nonatomic) SRWebSocket *webSocketSecondary;
@property (strong, nonatomic) AFHTTPRequestOperationManager *httpManager;
+ (instancetype)sharedInstance;
@end
