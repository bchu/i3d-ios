//
//ScreenCaptureView.m
//
#import "BCHScreenCaptureView.h"
@import QuartzCore;
#import <MobileCoreServices/UTCoreTypes.h>
#import <AssetsLibrary/AssetsLibrary.h>
#import <AFNetworking/AFNetworking.h>
#import "BCHMotionManager.h"

static NSString *const BCH_API_IMAGE = @"http://df49858.ngrok.com/screencast";
static NSString *const BCH_API_IMAGE_SECONDARY = @"http://d2e05a5.ngrok.com/screencast";

@interface BCHScreenCaptureView() <AVCaptureVideoDataOutputSampleBufferDelegate>
- (void) writeVideoFrameAtTime:(CMTime)time;
@end

@implementation BCHScreenCaptureView

@synthesize currentScreen, frameRate, delegate;

- (void)initialize
{
    // Initialization code
    self.clearsContextBeforeDrawing = YES;
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
    [self startRecording];
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

//-(void) captureOutput:(AVCaptureOutput*)captureOutput didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer fromConnection:(AVCaptureConnection*)connection
//{
//    CVImageBufferRef imageBuffer = CMSampleBufferGetImageBuffer( sampleBuffer );
//    CGSize imageSize = CVImageBufferGetEncodedSize( imageBuffer );
//    // also in the 'mediaSpecific' dict of the sampleBuffer
//    
//    NSLog( @"frame captured at %.fx%.f", imageSize.width, imageSize.height );
//}

- (CGContextRef) createBitmapContextOfSize:(CGSize) size {
    CGContextRef    context = NULL;
    CGColorSpaceRef colorSpace;
    int             bitmapByteCount;
    int             bitmapBytesPerRow;
    
    bitmapBytesPerRow   = (size.width * 4);
    bitmapByteCount     = (bitmapBytesPerRow * size.height);
    colorSpace = CGColorSpaceCreateDeviceRGB();
    if (bitmapData != NULL) {
        free(bitmapData);
    }
    bitmapData = malloc( bitmapByteCount );
    if (bitmapData == NULL) {
        fprintf (stderr, "Memory not allocated!");
        return NULL;
    }
    
    context = CGBitmapContextCreate (bitmapData,
                                     size.width,
                                     size.height,
                                     8,      // bits per component
                                     bitmapBytesPerRow,
                                     colorSpace,
                                     kCGImageAlphaNoneSkipFirst);
    
    CGContextSetAllowsAntialiasing(context,NO);
    if (context== NULL) {
        free (bitmapData);
        fprintf (stderr, "Context not created!");
        return NULL;
    }
    CGColorSpaceRelease( colorSpace );
    
    return context;
}

//static int frameCount = 0;            //debugging
- (void) drawRect:(CGRect)rect {
    NSDate* start = [NSDate date];
    CGContextRef context = [self createBitmapContextOfSize:self.frame.size];
    
    //not sure why this is necessary...image renders upside-down and mirrored
    CGAffineTransform flipVertical = CGAffineTransformMake(1, 0, 0, -1, 0, self.frame.size.height);
    CGContextConcatCTM(context, flipVertical);
    
    [self.layer renderInContext:context];
    
    CGImageRef cgImage = CGBitmapContextCreateImage(context);
    UIImage* background = [UIImage imageWithCGImage: cgImage];
    CGImageRelease(cgImage);
    
    self.currentScreen = background;
    
    //debugging
    //if (frameCount < 40) {
    //      NSString* filename = [NSString stringWithFormat:@"Documents/frame_%d.png", frameCount];
    //      NSString* pngPath = [NSHomeDirectory() stringByAppendingPathComponent:filename];
    //      [UIImagePNGRepresentation(self.currentScreen) writeToFile: pngPath atomically: YES];
    //      frameCount++;
    //}
    
    //NOTE:  to record a scrollview while it is scrolling you need to implement your UIScrollViewDelegate such that it calls
    //       'setNeedsDisplay' on the ScreenCaptureView.
    if (_recording) {
        float millisElapsed = [[NSDate date] timeIntervalSinceDate:startedAt] * 1000.0;
        [self writeVideoFrameAtTime:CMTimeMake((int)millisElapsed, 1000)];
    }
    
    float processingSeconds = [[NSDate date] timeIntervalSinceDate:start];
    float delayRemaining = (1.0 / self.frameRate) - processingSeconds;
    
    CGContextRelease(context);
    
    //redraw at the specified framerate
    [self performSelector:@selector(setNeedsDisplay) withObject:nil afterDelay:delayRemaining > 0.0 ? delayRemaining : 0.01];
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
    
    //add input
    [videoWriter addInput:videoWriterInput];
    [videoWriter startWriting];
    [videoWriter startSessionAtSourceTime:CMTimeMake(0, 1000)];
    
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
            
            
            
            
            
            int w = CVPixelBufferGetWidth(pixelBuffer);
            int h = CVPixelBufferGetHeight(pixelBuffer);
            int r = CVPixelBufferGetBytesPerRow(pixelBuffer);
            int bytesPerPixel = r/w;
            
            unsigned char *buffer = CVPixelBufferGetBaseAddress(pixelBuffer);
            
            UIGraphicsBeginImageContext(CGSizeMake(w, h));
            
            CGContextRef c = UIGraphicsGetCurrentContext();
            
            unsigned char* data = CGBitmapContextGetData(c);
            if (data != NULL) {
                int maxY = h;
                for(int y = 0; y<maxY; y++) {
                    for(int x = 0; x<w; x++) {
                        int offset = bytesPerPixel*((w*y)+x);
                        data[offset] = buffer[offset];     // R
                        data[offset+1] = buffer[offset+1]; // G
                        data[offset+2] = buffer[offset+2]; // B
                        data[offset+3] = buffer[offset+3]; // A
                    }
                }
            } 
            UIImage *img = UIGraphicsGetImageFromCurrentImageContext();
            
            UIGraphicsEndImageContext();
            
            
            // Form the URL request
            NSMutableURLRequest *request = [[AFHTTPRequestSerializer serializer] multipartFormRequestWithMethod:@"POST" URLString:BCH_API_IMAGE parameters:nil constructingBodyWithBlock:^(id<AFMultipartFormData> formData) {
                [formData appendPartWithFileData:UIImageJPEGRepresentation(img, 1.0) name:@"image" fileName:@"original.jpg" mimeType:@"image/jpeg"];
            } error:nil];
            
            // Add the operations
            AFHTTPRequestOperation *operation = [[AFHTTPRequestOperation alloc] initWithRequest:request];
            [[BCHMotionManager sharedInstance].httpManager.operationQueue addOperation:operation];
            
            NSLog(@"Uploading");
            
            
//            NSMutableURLRequest *request = [[AFHTTPRequestSerializer serializer] multipartFormRequestWithMethod:@"POST" URLString:@"http://example.com/upload" parameters:nil constructingBodyWithBlock:^(id<AFMultipartFormData> formData) {
//                [formData appendPartWithFileURL:[NSURL fileURLWithPath:@"file://path/to/image.jpg"] name:@"file" fileName:@"filename.jpg" mimeType:@"image/jpeg" error:nil];
//            } error:nil];
//            
//            AFURLSessionManager *manager = [[AFURLSessionManager alloc] initWithSessionConfiguration:[NSURLSessionConfiguration defaultSessionConfiguration]];
//            NSProgress *progress = nil;
//            
//            NSURLSessionUploadTask *uploadTask = [manager uploadTaskWithStreamedRequest:request progress:&progress completionHandler:^(NSURLResponse *response, id responseObject, NSError *error) {
//                if (error) {
//                    NSLog(@"Error: %@", error);
//                } else {
//                    NSLog(@"%@ %@", response, responseObject);
//                }
//            }];
//            
//            [uploadTask resume];
            
            
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