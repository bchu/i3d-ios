//
//ScreenCaptureView.m
//
#import "BCHScreenCaptureView.h"
@import QuartzCore;
#import <MobileCoreServices/UTCoreTypes.h>
#import <AssetsLibrary/AssetsLibrary.h>

#import "BCHDataManager.h"

@interface BCHScreenCaptureView() <AVCaptureVideoDataOutputSampleBufferDelegate>
- (void) writeVideoFrameAtTime:(CMTime)time;
@end

@implementation BCHScreenCaptureView

@synthesize currentScreen, frameRate, delegate;

- (void)initialize
{
    // Initialization code
//    self.clearsContextBeforeDrawing = YES;
    self.frameRate = 10.0f;     //10 frames per seconds
    bitmapData = NULL;

//    [self startRecording];
    [self captureRun];
}

- (instancetype)initWithCoder:(NSCoder *)aDecoder
{
    if (self = [super initWithCoder:aDecoder]) {
        [self initialize];
    }
    return self;
}

- (instancetype)initWithFrame:(CGRect)frame
{
    if (self = [super initWithFrame:frame]) {
        [self initialize];
    }
    return self;
}

- (id) init {
    self = [super init];
    if (self) {
        [self initialize];
        
    }
    return self;
}

- (void) drawRect:(CGRect)rect {
    [self captureRun];
    
//    [self performSelectorInBackground:@selector(setNeedsDisplay) withObject:self];
}

//UIView *snap;
- (void)captureRun
{
    BCHDataManager *dataManager = [BCHDataManager sharedInstance];
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_LOW, 0), ^{
        CGSize imageSize = CGSizeMake(self.bounds.size.width, self.bounds.size.height);
        UIGraphicsBeginImageContextWithOptions(imageSize, YES, 1);
//        CGContextRef context = UIGraphicsGetCurrentContext();
//        [self drawViewHierarchyInRect:self.bounds afterScreenUpdates:NO];
//        UIView *snap = [self snapshotViewAfterScreenUpdates:NO];
//        if (!snap) {
//            snap = [self snapshotViewAfterScreenUpdates:NO];
//        }
//        else {
//            snap = [snap snapshotViewAfterScreenUpdates:NO];
//        }
//        snap.layer.drawsAsynchronously = YES;
//        [snap.layer renderInContext:context];
        
        UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
        UIGraphicsEndImageContext();
        
        NSData *data = UIImageJPEGRepresentation(image, 0.0);
        [dataManager postScreencastImageData:data];
        dispatch_async(dispatch_get_main_queue(),^{
            [self setNeedsDisplay];
        });
    });
}

- (void) cleanupWriter {
    if (bitmapData != NULL) {
        free(bitmapData);
        bitmapData = NULL;
    }
}

- (void)dealloc {
    [self cleanupWriter];
}

- (NSURL*) tempFileURL {
    NSString* outputPath = [[NSString alloc] initWithFormat:@"%@/%@", [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) objectAtIndex:0], @"output.mp4"];
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

-(BOOL) setUpWriter {
    NSError* error = nil;
    videoWriter = [[AVAssetWriter alloc] initWithURL:[self tempFileURL] fileType:AVFileTypeQuickTimeMovie error:&error];
    NSParameterAssert(videoWriter);
    
    //Configure video
    NSDictionary* videoCompressionProps = [NSDictionary dictionaryWithObjectsAndKeys:
                                           [NSNumber numberWithDouble:1024.0*1024.0], AVVideoAverageBitRateKey,
                                           nil ];
    
    NSDictionary* videoSettings = [NSDictionary dictionaryWithObjectsAndKeys:
                                   AVVideoCodecH264, AVVideoCodecKey,
                                   [NSNumber numberWithInt:self.frame.size.width], AVVideoWidthKey,
                                   [NSNumber numberWithInt:self.frame.size.height], AVVideoHeightKey,
                                   videoCompressionProps, AVVideoCompressionPropertiesKey,
                                   nil];
    
    videoWriterInput = [AVAssetWriterInput assetWriterInputWithMediaType:AVMediaTypeVideo outputSettings:videoSettings];
    
    NSParameterAssert(videoWriterInput);
    videoWriterInput.expectsMediaDataInRealTime = YES;
    NSDictionary* bufferAttributes = [NSDictionary dictionaryWithObjectsAndKeys:
                                      [NSNumber numberWithInt:kCVPixelFormatType_32ARGB], kCVPixelBufferPixelFormatTypeKey, nil];
    
    avAdaptor = [AVAssetWriterInputPixelBufferAdaptor assetWriterInputPixelBufferAdaptorWithAssetWriterInput:videoWriterInput sourcePixelBufferAttributes:bufferAttributes];
    
//    //add input
//    [videoWriter addInput:videoWriterInput];
//    [videoWriter startWriting];
//    [videoWriter startSessionAtSourceTime:CMTimeMake(0, 1000)];
    
    return YES;
}

- (void) completeRecordingSession {
    @autoreleasepool {
        [videoWriterInput markAsFinished];
        
        // Wait for the video
        int status = videoWriter.status;
        while (status == AVAssetWriterStatusUnknown) {
            NSLog(@"Waiting...");
            [NSThread sleepForTimeInterval:0.5f];
            status = videoWriter.status;
        }

        [videoWriter finishWritingWithCompletionHandler:^{
            if (videoWriter.status != AVAssetWriterStatusCompleted) {
                NSLog(@"finishWriting returned NO");
            }
            else {
                [self cleanupWriter];
                
                id delegateObj = self.delegate;
                NSString *outputPath = [[NSString alloc] initWithFormat:@"%@/%@", [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) objectAtIndex:0], @"output.mp4"];
                NSURL *outputURL = [[NSURL alloc] initFileURLWithPath:outputPath];
                
                NSLog(@"Completed recording, file is stored at:  %@", outputURL);
                if ([delegateObj respondsToSelector:@selector(recordingFinished:)]) {
                    [delegateObj performSelectorOnMainThread:@selector(recordingFinished:) withObject:outputURL waitUntilDone:YES];
                }
            }
        }];
    }
}

- (bool) startRecording {
    bool result = NO;
    @synchronized(self) {
        if (! _recording) {
            result = [self setUpWriter];
            startedAt = [NSDate date];
            _recording = true;
        }
    }
    
    return result;
}

- (void) stopRecording {
    @synchronized(self) {
        if (_recording) {
            _recording = false;
            [self completeRecordingSession];
        }
    }
}



@end