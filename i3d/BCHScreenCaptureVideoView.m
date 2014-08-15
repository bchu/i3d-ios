//
//ScreenCaptureView.m
//
#import "BCHScreenCaptureVideoView.h"
#import "BCHVideoWriter.h"

#import <AFNetworking/AFNetworking.h>
#import <SocketRocket/SRWebSocket.h>

@interface BCHScreenCaptureVideoView () <AVCaptureVideoDataOutputSampleBufferDelegate, SRWebSocketDelegate>
@property (strong, nonatomic) NSArray *videoQueue;
@property (strong, nonatomic) BCHVideoWriter *queuedWriter;
@property (strong, nonatomic) BCHVideoWriter *currentWriter;
@property (strong, nonatomic) BCHVideoWriter *uploadingWriter;

// readwrite redeclaration
@property (readwrite, getter = isStarted, nonatomic) BOOL started;

@property (weak, nonatomic) SRWebSocket *webSocket;
@property (strong, nonatomic) NSObject *resignObserver;
@property (strong, nonatomic) NSObject *activeObserver;
@end

@implementation BCHScreenCaptureVideoView

- (void)initialize
{
    // Initialization code
    self.clearsContextBeforeDrawing = YES;
    // default: 10 fps
    self.frameRate = 10.0f;

    self.queuedWriter = [[BCHVideoWriter alloc] init];
    self.currentWriter = [[BCHVideoWriter alloc] init];

    // default:
    self.url = @"";
}
- (instancetype)initWithCoder:(NSCoder *)aDecoder
{
    if (self = [super initWithCoder:aDecoder]) { [self initialize]; }
    return self;
}
- (instancetype)initWithFrame:(CGRect)frame
{
    if (self = [super initWithFrame:frame]) { [self initialize]; }
    return self;
}
- (id)init
{
    if (self = [super init]) { [self initialize]; }
    return self;
}

# pragma mark - Recording Lifecycle

- (void)start
{
    self.started = YES;
    [self.currentWriter setUpWriterWithSize:self.bounds.size url:[self tempFileURL]];
    [self.currentWriter startRecording];

    self.webSocket = [self createWebSocket];
    // block is run synchronously
    self.resignObserver = [[NSNotificationCenter defaultCenter] addObserverForName:UIApplicationWillResignActiveNotification object:nil queue:nil usingBlock:^(NSNotification *note) {
        [self stop];
        [self addActiveObserver];
    }];
    [self addActiveObserver];
}

- (SRWebSocket *)createWebSocket
{
    // webSocket retains itself on open:
    SRWebSocket *socket = [[SRWebSocket alloc] initWithURL:[NSURL URLWithString:self.url]];
    socket.delegate = self;
    [socket open];
    return socket;
}

- (void)addActiveObserver
{
    self.activeObserver = [[NSNotificationCenter defaultCenter] addObserverForName:UIApplicationDidBecomeActiveNotification object:nil queue:nil usingBlock:^(NSNotification *note) {
        [self deregisterListeners];
        [self start];
    }];
}

- (void)deregisterListeners
{
    [[NSNotificationCenter defaultCenter] removeObserver:self.activeObserver];
    [[NSNotificationCenter defaultCenter] removeObserver:self.resignObserver];
}

- (void)stop
{
    if (!self.isStarted) {
        return;
    }

    self.started = NO;
    [self deregisterListeners];

    [self.currentWriter stopRecording];

    // do some checks on whether upload has finished, and if it hasn't, create some sort of upload queue
    self.uploadingWriter = self.currentWriter;
    self.currentWriter = self.queuedWriter;
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        self.queuedWriter = [[BCHVideoWriter alloc] init];
        [self.queuedWriter setUpWriterWithSize:self.bounds.size url:[self tempFileURL]];
    });
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        [self.uploadingWriter upload];
    });
}

- (void)shiftWriters
{
    [self.queuedWriter startRecording];
    [self.currentWriter stopRecording];

    // do some checks on whether upload has finished, and if it hasn't, create some sort of upload queue
    self.uploadingWriter = self.currentWriter;
    self.currentWriter = self.queuedWriter;
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        self.queuedWriter = [[BCHVideoWriter alloc] init];
        [self.queuedWriter setUpWriterWithSize:self.bounds.size url:[self tempFileURL]];
    });
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        [self.uploadingWriter upload];
    });
}

- (void)dealloc
{
    [self stop];
}

- (NSURL*) tempFileURL
{
    static NSUInteger count;
    NSString *name = [NSString stringWithFormat:@"BCHTempVideo-%lu.mp4", count++];
    NSString* outputPath = [[NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) firstObject] stringByAppendingPathComponent:name];
    NSLog(@"%@", outputPath);
    NSURL* outputURL = [[NSURL alloc] initFileURLWithPath:outputPath];
    NSFileManager* fileManager = [NSFileManager defaultManager];
    if ([fileManager fileExistsAtPath:outputPath]) {
        NSError* error;
        if ([fileManager removeItemAtPath:outputPath error:&error] == NO) {
            NSLog(@"Could not delete old recording file at path:  %@", outputPath);
        }
    }
    return outputURL;
}

#pragma mark - Recording frames

//static int frameCount = 0;            //debugging
- (void) drawRect:(CGRect)rect {
    NSDate* start = [NSDate date];
    
    // BRIAN NOTE: Original code that uses createBitmapContextOfSize:
//    CGContextRef context = [self createBitmapContextOfSize:self.frame.size];
//    
//    //not sure why this is necessary...image renders upside-down and mirrored
//    CGAffineTransform flipVertical = CGAffineTransformMake(1, 0, 0, -1, 0, self.frame.size.height);
//    CGContextConcatCTM(context, flipVertical);
//    
//    [self.layer renderInContext:context];
//    
//    CGImageRef cgImage = CGBitmapContextCreateImage(context);
//    UIImage* background = [UIImage imageWithCGImage: cgImage];
//    CGImageRelease(cgImage);
//    
//    self.currentScreen = background;
    
    // BRIAN NOTE: MY CODE:
    CGSize imageSize = self.bounds.size;
    UIGraphicsBeginImageContextWithOptions(imageSize, YES, 1);
    [self drawViewHierarchyInRect:self.bounds afterScreenUpdates:YES];
    UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    // END MY CODE

    // NOTE:  to record a scrollview while it is scrolling you need to implement your UIScrollViewDelegate such that it calls
    //       'setNeedsDisplay' on the ScreenCaptureView.
    if (self.currentWriter.recording) {
        float millisElapsed = [[NSDate date] timeIntervalSinceDate:self.currentWriter.startedAt] * 1000.0;
        [self.currentWriter writeVideoFrameAtTime:CMTimeMake((int)millisElapsed, 1000) image:image];
    }
    
    float processingSeconds = [[NSDate date] timeIntervalSinceDate:start];
    float delayRemaining = (1.0 / self.frameRate) - processingSeconds;
    
    // BRIAN NOTE: Original code that uses createBitmapContextOfSize:
//    CGContextRelease(context);
    
    //redraw at the specified framerate
    [self performSelector:@selector(setNeedsDisplay) withObject:nil afterDelay:delayRemaining > 0.0 ? delayRemaining : 0.01];
}

#pragma mark - Socket handling

- (void)attemptReconnection: (SRWebSocket *)webSocket
{
    CGFloat seconds = 3;
    dispatch_time_t delay = dispatch_time(DISPATCH_TIME_NOW, NSEC_PER_SEC * seconds);
    dispatch_after(delay, dispatch_get_main_queue(), ^(void){
        if (!self.webSocket) {
            self.webSocket = [self createWebSocket];
        }
    });
}

- (void)applicationDidBecomeActive: (NSNotification *)notification
{
    [self attemptReconnection:nil];
}

- (void)webSocket:(SRWebSocket *)webSocket didFailWithError:(NSError *)error
{
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