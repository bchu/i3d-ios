//
//  BCHDataManager.h
//  Hack
//
//  Created by Brian Chu on 7/20/14.
//  Copyright (c) 2014 Brian. All rights reserved.
//

@import UIKit;
#import "BCHMotionManager.h"

@class SRWebSocket;
@class AFHTTPRequestOperationManager;

@interface BCHDataManager : NSObject
// SRWebSocket retains itself between open and close
@property (weak, nonatomic) SRWebSocket *webSocket;
@property (weak, nonatomic) SRWebSocket *webSocketSecondary;
@property (strong, nonatomic) AFHTTPRequestOperationManager *httpManager;

+ (instancetype)sharedInstance;
- (void)attemptReconnection: (SRWebSocket *)webSocket;
- (void)postMotionUpdate:(MotionData)data otherParams:(NSDictionary *)otherParams;
- (void)postScreencastImageData:(NSData *)data;
@end
