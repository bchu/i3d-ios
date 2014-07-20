//
//  BCHDataManager.m
//  Hack
//
//  Created by Brian Chu on 7/20/14.
//  Copyright (c) 2014 Brian. All rights reserved.
//

#import <SocketRocket/SRWebSocket.h>
#import <AFNetworking/AFNetworking.h>
#import "BCHDataManager.h"

static NSString *const BCH_API_HOST = @"http://df49858.ngrok.com";

static NSString *const BCH_API_HOST_SECONDARY = @"http://ngrok.com:56515";
static NSString *const BCH_API_HOST_SOCKET = @"ws://ngrok.com:51860";

static NSString *const BCH_API_PATH_IMAGE = @"/screencast";
static NSString *const BCH_API_PATH_SOCKET = @"/updateWS";
static NSString *const BCH_API_PATH_HTTP = @"/update";

@interface BCHDataManager () <SRWebSocketDelegate>
@end

@implementation BCHDataManager

+ (instancetype)sharedInstance
{
    static BCHDataManager *shared;
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
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(applicationDidBecomeActive:)
                                                     name:UIApplicationDidBecomeActiveNotification object:nil];
        
//        SRWebSocket *webSocket = [[SRWebSocket alloc] initWithURL:[NSURL URLWithString:BCH_API_SOCKET_URL]];
//        webSocket.delegate = self;
//        [webSocket open];
//        self.webSocket = webSocket;
        self.webSocketSecondary = [self createWebSocket:BCH_API_HOST_SOCKET];
        self.httpManager = [AFHTTPRequestOperationManager manager];
    }
    return self;
}

- (SRWebSocket *)createWebSocket:(NSString *)url
{
    SRWebSocket *socket = [[SRWebSocket alloc] initWithURL:[NSURL URLWithString:url]];
    socket.delegate = self;
    [socket open];
    return socket;
}

- (void)postMotionUpdate:(MotionData)data otherParams:(NSDictionary *)otherParams
{
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
                                 @"quaternion":@[@(data.x), @(data.y), @(data.z), @(data.w)],
                                 @"accelerationX":@(data.accelX),
                                 @"accelerationY":@(data.accelY),
                                 @"accelerationZ":@(data.accelZ)
                                 };
    NSData *jsonData = [NSJSONSerialization dataWithJSONObject:parameters options:0 error:nil];
    if (self.webSocket.readyState == SR_OPEN) {
        [self.webSocket send:[[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding]];
    }
    else {
        AFHTTPRequestOperation *operation = [manager POST:[BCH_API_HOST stringByAppendingString:BCH_API_PATH_HTTP] parameters:parameters success:^(AFHTTPRequestOperation *operation, id responseObject) {
        } failure:^(AFHTTPRequestOperation *operation, NSError *error) {
            //        NSLog(@"\nError: %@", error);
        }];
    }
    
    if (self.webSocketSecondary.readyState == SR_OPEN) {
        [self.webSocketSecondary send:[[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding]];
    }
    else {
        AFHTTPRequestOperation *operationSecondary = [manager POST:[BCH_API_HOST_SECONDARY stringByAppendingString:BCH_API_PATH_HTTP] parameters:parameters success:^(AFHTTPRequestOperation *operation, id responseObject) {
        } failure:^(AFHTTPRequestOperation *operation, NSError *error) {
            //        NSLog(@"\nError: %@", error);
        }];
    }
}

- (void)postScreencastImageData:(NSData *)data
{
    // Form the URL request
    if (self.webSocket.readyState == SR_OPEN) {
        [self.webSocket send:data];
    }
    else {
        NSMutableURLRequest *request = [[AFHTTPRequestSerializer serializer] multipartFormRequestWithMethod:@"POST" URLString:[BCH_API_HOST stringByAppendingString:BCH_API_PATH_IMAGE] parameters:nil constructingBodyWithBlock:^(id<AFMultipartFormData> formData) {
            [formData appendPartWithFileData:data name:@"image" fileName:@"original.jpg" mimeType:@"image/jpeg"];
        } error:nil];
        
        AFHTTPRequestOperation *operation = [[AFHTTPRequestOperation alloc] initWithRequest:request];
        [self.httpManager.operationQueue addOperation:operation];
    }
    
    
    if (self.webSocketSecondary.readyState == SR_OPEN) {
        [self.webSocketSecondary send:data];
    }
    else {
        NSMutableURLRequest *secondRequest = [[AFHTTPRequestSerializer serializer] multipartFormRequestWithMethod:@"POST" URLString:[BCH_API_HOST_SECONDARY stringByAppendingString:BCH_API_PATH_IMAGE] parameters:nil constructingBodyWithBlock:^(id<AFMultipartFormData> formData) {
            [formData appendPartWithFileData:data name:@"image" fileName:@"original.jpg" mimeType:@"image/jpeg"];
        } error:nil];
        
        // Add the operations
        AFHTTPRequestOperation *operationSecondary = [[AFHTTPRequestOperation alloc] initWithRequest:secondRequest];
        [self.httpManager.operationQueue addOperation:operationSecondary];
    }
}

- (void)attemptReconnection: (SRWebSocket *)webSocket
{
    if (!self.webSocket) {
        self.webSocket = [self createWebSocket:BCH_API_HOST_SOCKET];
    }
    if (!self.webSocketSecondary) {
        self.webSocketSecondary = [self createWebSocket:BCH_API_HOST_SOCKET];
    }
}

- (void)applicationDidBecomeActive: (NSNotification *)notification
{
    [self attemptReconnection:nil];
}

- (void)webSocket:(SRWebSocket *)webSocket didFailWithError:(NSError *)error
{
    NSLog(@"websocket failed: %@", error);
    [self attemptReconnection:webSocket];
}

- (void)webSocketDidOpen:(SRWebSocket *)webSocket
{
    NSLog(@"opened socket: %@", webSocket);
}

- (void)webSocket:(SRWebSocket *)webSocket didReceiveMessage:(id)message
{
    NSLog(@"received");
}

- (void)webSocket:(SRWebSocket *)webSocket didCloseWithCode:(NSInteger)code reason:(NSString *)reason wasClean:(BOOL)wasClean
{
    NSLog(@"closed: code:%li, reason:%@", (long)code, reason);
}
@end
