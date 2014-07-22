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
    self.currentScreen = nil;
    self.frameRate = 10.0f;     //10 frames per seconds
    _recording = false;
    videoWriter = nil;
    videoWriterInput = nil;
    avAdaptor = nil;
    startedAt = nil;
    bitmapData = NULL;
    
    //        // make input device
    //        NSError *deviceError;
    //        AVCaptureDevice *cameraDevice = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeVideo];
    //        AVCaptureDeviceInput *inputDevice = [AVCaptureDeviceInput deviceInputWithDevice:cameraDevice error:&deviceError];
    //
    //        // make output device
    //        AVCaptureVideoDataOutput *outputDevice = [[AVCaptureVideoDataOutput alloc] init];
    //        [outputDevice setSampleBufferDelegate:self queue:dispatch_get_main_queue()];
    //
    //        // initialize capture session
    //        AVCaptureSession *captureSession = [[AVCaptureSession alloc] init];
    //        [captureSession addInput:inputDevice];
    //        [captureSession addOutput:outputDevice];
    //
    //        // make preview layer and add so that camera's view is displayed on screen
    //        AVCaptureVideoPreviewLayer *previewLayer = [AVCaptureVideoPreviewLayer layerWithSession:captureSession];
    //        previewLayer.frame = self.bounds;
    //        [self.layer addSublayer:previewLayer];
    //
    //        // go!
    //        [captureSession startRunning];
//    [self startRecording];
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

    [self performSelectorInBackground:@selector(setNeedsDisplay) withObject:nil];
}


- (void)captureRun
{
    CGSize imageSize = CGSizeMake(self.bounds.size.width, self.bounds.size.height);
    UIGraphicsBeginImageContextWithOptions(imageSize, YES, 1);
    [self drawViewHierarchyInRect:self.bounds afterScreenUpdates:YES];
    
    UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    
    NSData *data = UIImageJPEGRepresentation(image, 0.0);
    BCHDataManager *dataManager = [BCHDataManager sharedInstance];
    [dataManager postScreencastImageData:data];
}

- (void) cleanupWriter {
    avAdaptor = nil;
    videoWriterInput = nil;
    videoWriter = nil;
    startedAt = nil;
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

-(void) writeVideoFrameAtTime:(CMTime)time {
    if (![videoWriterInput isReadyForMoreMediaData]) {
        NSLog(@"Not ready for video data");
    }
    else {
        @synchronized (self) {
            UIImage* newFrame = self.currentScreen;
            CVPixelBufferRef pixelBuffer = NULL;
            CGImageRef cgImage = CGImageCreateCopy([newFrame CGImage]);
            CFDataRef image = CGDataProviderCopyData(CGImageGetDataProvider(cgImage));

            int status = CVPixelBufferPoolCreatePixelBuffer(kCFAllocatorDefault, avAdaptor.pixelBufferPool, &pixelBuffer);
            if(status != 0){
                //could not get a buffer from the pool
                NSLog(@"Error creating pixel buffer:  status=%d", status);
            }
            // set image data into pixel buffer
            CVPixelBufferLockBaseAddress( pixelBuffer, 0 );
            uint8_t* destPixels = CVPixelBufferGetBaseAddress(pixelBuffer);
            CFDataGetBytes(image, CFRangeMake(0, CFDataGetLength(image)), destPixels);  //XXX:  will work if the pixel buffer is contiguous and has the same bytesPerRow as the input data


            
//            if(status == 0){
//                BOOL success = [avAdaptor appendPixelBuffer:pixelBuffer withPresentationTime:time];
//                if (!success)
//                    NSLog(@"Warning:  Unable to write buffer to video");
//            }
            
            //clean up
            
            CVPixelBufferUnlockBaseAddress( pixelBuffer, 0 );
            CVPixelBufferRelease( pixelBuffer );
            CFRelease(image);
            CGImageRelease(cgImage);
        }
        
    }
    
}



@end