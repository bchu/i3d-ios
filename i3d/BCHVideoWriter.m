//
//  BCHVideoWriter.m
//  i3d
//
//  Created by Brian Chu on 8/9/14.
//  Copyright (c) 2014 Brian. All rights reserved.
//

#import "BCHVideoWriter.h"
#import "BCHDataManager.h"
@import AVFoundation;

NSString *BCHWritingDocumentsFileNames = @"BCHWritingDocumentsFileNames";

@interface BCHVideoWriter ()
@property (nonatomic) void* bitmapData;

@property (strong, nonatomic) NSURL *fileURL;

@property (strong, nonatomic) AVAssetWriter *videoWriter;
@property (strong, nonatomic) AVAssetWriterInput *videoWriterInput;
@property (strong, nonatomic) AVAssetWriterInputPixelBufferAdaptor *avAdaptor;
@end

@implementation BCHVideoWriter

- (instancetype) init
{
    self = [super init];
    if (self) {
        self.bitmapData = NULL;
    }
    return self;
}

- (BOOL)setUpWriterWithSize:(CGSize)size url:(NSURL *)fileURL
{
    self.fileURL = fileURL;
    NSError* error;
    self.videoWriter = [[AVAssetWriter alloc] initWithURL:fileURL fileType:AVFileTypeQuickTimeMovie error:&error];
    
    //Configure video
    // 500 kilobits:
    NSDictionary* videoCompressionProps = [NSDictionary dictionaryWithObjectsAndKeys:
                                           @(500000), AVVideoAverageBitRateKey,
                                           nil ];

    NSDictionary* videoSettings = [NSDictionary dictionaryWithObjectsAndKeys:
                                   AVVideoCodecH264, AVVideoCodecKey,
                                   [NSNumber numberWithInt:size.width], AVVideoWidthKey,
                                   [NSNumber numberWithInt:size.height], AVVideoHeightKey,
                                   videoCompressionProps, AVVideoCompressionPropertiesKey,
                                   nil];
    // can't re-use this because it you cannot reset it after `markAsFinished`
    self.videoWriterInput = [AVAssetWriterInput assetWriterInputWithMediaType:AVMediaTypeVideo outputSettings:videoSettings];
    self.videoWriterInput.expectsMediaDataInRealTime = YES;

    // BRIAN NOTE: kCVPixelFormatType_32ARGB is used if createBitmapContextOfSize is used. Otherwise (UIGraphicsGetImageFromCurrentImageContext) use BGRA
    NSDictionary* bufferAttributes = [NSDictionary dictionaryWithObjectsAndKeys:
                                      [NSNumber numberWithInt:kCVPixelFormatType_32BGRA], kCVPixelBufferPixelFormatTypeKey,
                                      [NSNumber numberWithBool:NO], kCVPixelBufferCGImageCompatibilityKey,
                                      [NSNumber numberWithBool:NO], kCVPixelBufferCGBitmapContextCompatibilityKey,
                                      nil];

    self.avAdaptor = [AVAssetWriterInputPixelBufferAdaptor assetWriterInputPixelBufferAdaptorWithAssetWriterInput:self.videoWriterInput sourcePixelBufferAttributes:bufferAttributes];

    // add input
    [self.videoWriter addInput:self.videoWriterInput];
    return YES;
}

#pragma mark - Recording

- (void)startRecording
{
    self.startedAt = [NSDate date];
    self.recording = YES;
    [self.videoWriter startWriting]; // this creates an empty file
    NSArray *filenames = [[NSUserDefaults standardUserDefaults] objectForKey:BCHWritingDocumentsFileNames];
    filenames = [filenames arrayByAddingObject:self.fileURL.path.lastPathComponent];
    [[NSUserDefaults standardUserDefaults] setObject:filenames forKey:BCHWritingDocumentsFileNames];
    [[NSUserDefaults standardUserDefaults] synchronize];
    [self.videoWriter startSessionAtSourceTime:CMTimeMake(0, 1000)];
}

- (void)writeVideoFrameAtTime:(CMTime)time image:(UIImage *)image
{
    if (![self.videoWriterInput isReadyForMoreMediaData]) {
        NSLog(@"Not ready for video data");
    }
    else {
//        @synchronized (self) {
            CVPixelBufferRef pixelBuffer = NULL;
            CGImageRef cgImage = CGImageCreateCopy(image.CGImage);
            CFDataRef image = CGDataProviderCopyData(CGImageGetDataProvider(cgImage));

            // ideally re-use pixel buffer here:
            int status = CVPixelBufferPoolCreatePixelBuffer(kCFAllocatorDefault, self.avAdaptor.pixelBufferPool, &pixelBuffer);
            if(status != 0){
                //could not get a buffer from the pool
                NSLog(@"Error creating pixel buffer:  status=%d", status);
            }
            // set image data into pixel buffer
            CVPixelBufferLockBaseAddress( pixelBuffer, 0 );
            uint8_t* destPixels = CVPixelBufferGetBaseAddress(pixelBuffer);
            CFDataGetBytes(image, CFRangeMake(0, CFDataGetLength(image)), destPixels);  //XXX:  will work if the pixel buffer is contiguous and has the same bytesPerRow as the input data

            // BRIAN NOTE: alternate (broken) method:
            //            pixelBuffer = [self pixelBufferFromCGImage:newFrame.CGImage];
            //            int status = 1;
            
            // BRIAN NOTE: no idea what this does
            //            int w = CVPixelBufferGetWidth(pixelBuffer);
            //            int h = CVPixelBufferGetHeight(pixelBuffer);
            //            int r = CVPixelBufferGetBytesPerRow(pixelBuffer);
            //            int bytesPerPixel = r/w;
            //
            //            unsigned char *buffer = CVPixelBufferGetBaseAddress(pixelBuffer);
            
            
            
            if(status == 0){
                BOOL success = [self.avAdaptor appendPixelBuffer:pixelBuffer withPresentationTime:time];
                if (!success) { NSLog(@"Warning:  Unable to write buffer to video"); }
            }
            
            //clean up
            CVPixelBufferUnlockBaseAddress( pixelBuffer, 0 );
            CVPixelBufferRelease( pixelBuffer );
            CFRelease(image);
            CGImageRelease(cgImage);
//        }

    }
    
}

- (void)stopRecording
{
    [self stopRecordingThenUploadWithManager:nil];
}

- (void)stopRecordingThenUploadWithManager:(BCHDataManager *)dataManager;
{
    if (!self.recording) {
        return;
    }
    self.recording = false;

    @autoreleasepool {
        [self.videoWriterInput markAsFinished];
        
        // Wait for the video
        int status = self.videoWriter.status;
        while (status == AVAssetWriterStatusUnknown) {
            NSLog(@"ERROR Waiting...");
            [NSThread sleepForTimeInterval:0.5f];
            status = self.videoWriter.status;
        }

        // this actually writes data to file; before this is called, the file is empty
        [self.videoWriter finishWritingWithCompletionHandler:^{
            if (self.videoWriter.status != AVAssetWriterStatusCompleted) {
                NSLog(@"finishWriting returned NO");
            }
            else {
                [self cleanupWriter];

                id delegateObj = self.delegate;
                NSLog(@"Completed recording, file is stored at:  %@", self.fileURL);
                if ([delegateObj respondsToSelector:@selector(recordingFinished:)]) {
                    [delegateObj performSelectorOnMainThread:@selector(recordingFinished:) withObject:self.fileURL waitUntilDone:YES];
                }
                if (!dataManager) { return; }
                [self sendDataToManager:dataManager];
            }
        }];
    }
}

#pragma mark - Upload and Cleanup

- (void)sendDataToManager:(BCHDataManager *)dataManager
{
    NSError *error;
    NSData *data = [NSData dataWithContentsOfURL:self.fileURL options:NSDataReadingUncached error:&error];
    if (error) {
        NSLog(@"Upload data reading error: %@", error);
    }
    [dataManager postScreencastVideoData:data];

    // delete old file:
    NSFileManager* fileManager = [NSFileManager defaultManager];
    if ([fileManager fileExistsAtPath:self.fileURL.path]) {
        NSError* error;
        if ([fileManager removeItemAtURL:self.fileURL error:&error] == NO) {
            NSLog(@"Could not delete old recording file at path: %@, with error: %@", self.fileURL.path, error);
        }
        else {
            NSMutableArray *filenames = [[[NSUserDefaults standardUserDefaults] objectForKey:BCHWritingDocumentsFileNames] mutableCopy];
            [filenames removeObject:self.fileURL.path.lastPathComponent];
            [[NSUserDefaults standardUserDefaults] setObject:filenames forKey:BCHWritingDocumentsFileNames];
            [[NSUserDefaults standardUserDefaults] synchronize];
        }
    }
}

- (void) cleanupWriter
{
    if (self.bitmapData != NULL) {
        free(self.bitmapData);
        self.bitmapData = NULL;
    }
}

- (void)dealloc
{
    [self cleanupWriter];
}

@end
