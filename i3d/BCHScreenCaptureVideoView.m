
#import "BCHScreenCaptureVideoView.h"
#import "BCHVideoWriter.h"
#import "BCHDataManager.h"

#import <AFNetworking/AFNetworking.h>

static NSUInteger BCH_TICK_SECONDS = 1;
static CGFloat BCH_DEFAULT_FRAME_RATE = 30;

@interface BCHScreenCaptureVideoView () <AVCaptureVideoDataOutputSampleBufferDelegate>
@property (strong, nonatomic) NSArray *videoQueue;
@property (strong, nonatomic) BCHVideoWriter *queuedWriter;
@property (strong, nonatomic) BCHVideoWriter *currentWriter;
@property (strong, nonatomic) BCHVideoWriter *uploadingWriter;

// readwrite redeclaration
@property (readwrite, getter = isStarted, nonatomic) BOOL started;

@property (strong, nonatomic) BCHDataManager *dataManager;
@property (strong, nonatomic) NSObject *resignObserver;
@property (strong, nonatomic) NSObject *activeObserver;
@end

@implementation BCHScreenCaptureVideoView

- (void)initialize
{
    // Initialization code
    self.clearsContextBeforeDrawing = YES;
    self.frameRate = BCH_DEFAULT_FRAME_RATE;
    self.currentWriter = [[BCHVideoWriter alloc] init];
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

    self.dataManager = [BCHDataManager sharedInstance];
    // block is run synchronously
    self.resignObserver = [[NSNotificationCenter defaultCenter] addObserverForName:UIApplicationWillResignActiveNotification object:nil queue:nil usingBlock:^(NSNotification *note) {
        [self stop];
        // only listen to UIApplicationDidBecomeActiveNotification if you previously resigned and stopped:
        [self addActiveObserver];
    }];

    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        self.queuedWriter = [[BCHVideoWriter alloc] init];
        [self.queuedWriter setUpWriterWithSize:self.bounds.size url:[self tempFileURL]];
    });
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(BCH_TICK_SECONDS * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [self nextTick];
    });
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

    BCHVideoWriter *currentWriter = self.currentWriter;
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        [currentWriter stopRecordingThenUploadWithManager:self.dataManager];
    });

    // do some checks on whether upload has finished, and if it hasn't, create some sort of upload queue
    self.uploadingWriter = self.currentWriter;
    self.currentWriter = self.queuedWriter;
}

- (void)nextTick
{
    if (self.isStarted) {
        NSLog(@"shiftWriters");
        [self shiftWriters];
    }
}

- (void)shiftWriters
{
    BCHVideoWriter *uploadingWriter = self.currentWriter;
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        [uploadingWriter stopRecordingThenUploadWithManager:self.dataManager]; // responsible for HUGE amount of cpu usage
    });
    // do some checks on whether upload has finished, and if it hasn't, create some sort of upload queue
    self.uploadingWriter = uploadingWriter;

    self.currentWriter = self.queuedWriter;
    [self.currentWriter startRecording];
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        self.queuedWriter = [[BCHVideoWriter alloc] init];
        // TODO: recycle writers instead of re-setting them up
        [self.queuedWriter setUpWriterWithSize:self.bounds.size url:[self tempFileURL]]; // responsible for large amount of memory usage
    });

    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(BCH_TICK_SECONDS * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [self nextTick];
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

- (void) drawRect:(CGRect)rect {
    [self captureRun];

    //    [self performSelectorInBackground:@selector(setNeedsDisplay) withObject:self];
}

//UIView *snap;
- (void)captureRun
{
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSDate* start = [NSDate date];
        CGSize imageSize = self.bounds.size;
        // scale must be 1:
        UIGraphicsBeginImageContextWithOptions(imageSize, YES, 1);
        [self drawViewHierarchyInRect:self.bounds afterScreenUpdates:NO];
        UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
        UIGraphicsEndImageContext();

        if (self.currentWriter.recording) {
            float millisElapsed = [[NSDate date] timeIntervalSinceDate:self.currentWriter.startedAt] * 1000.0;
            [self.currentWriter writeVideoFrameAtTime:CMTimeMake((int)millisElapsed, 1000) image:image];
        }

        CGFloat processingSeconds = [[NSDate date] timeIntervalSinceDate:start];
        CGFloat delayRemaining = (1.0 / self.frameRate) - processingSeconds;

        CGFloat delay = delayRemaining > 0.0 ? delayRemaining : 0.01;
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delay * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            [self setNeedsDisplay];
        });
//        dispatch_async(dispatch_get_main_queue(),^{
//            [self setNeedsDisplay];
//        });
    });
}

/*
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
*/

@end