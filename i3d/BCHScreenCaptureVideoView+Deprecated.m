//
//  BCHScreenCaptureVideoView+Deprecated.m
//  i3d
//
//  Created by Brian Chu on 8/10/14.
//  Copyright (c) 2014 Brian. All rights reserved.
//

#import "BCHScreenCaptureVideoView+Deprecated.h"

@implementation BCHScreenCaptureVideoView (Deprecated)

- (CGContextRef) createBitmapContextOfSize:(CGSize) size {
//    CGContextRef    context = NULL;
//    CGColorSpaceRef colorSpace;
//    int             bitmapByteCount;
//    int             bitmapBytesPerRow;
//    
//    bitmapBytesPerRow   = (size.width * 4);
//    bitmapByteCount     = (bitmapBytesPerRow * size.height);
//    colorSpace = CGColorSpaceCreateDeviceRGB();
//    if (self.bitmapData != NULL) {
//        free(self.bitmapData);
//    }
//    self.bitmapData = malloc( bitmapByteCount );
//    if (self.bitmapData == NULL) {
//        fprintf (stderr, "Memory not allocated!");
//        return NULL;
//    }
//    
//    context = CGBitmapContextCreate (self.bitmapData,
//                                     size.width,
//                                     size.height,
//                                     8,      // bits per component
//                                     bitmapBytesPerRow,
//                                     colorSpace,
//                                     kCGImageAlphaNoneSkipFirst);
//    
//    CGContextSetAllowsAntialiasing(context,NO);
//    if (context== NULL) {
//        free (self.bitmapData);
//        fprintf (stderr, "Context not created!");
//        return NULL;
//    }
//    CGColorSpaceRelease( colorSpace );
//    
//    return context;
    return NULL;
}

- (CVPixelBufferRef) pixelBufferFromCGImage: (CGImageRef) image
{
    
    CGSize frameSize = CGSizeMake(CGImageGetWidth(image), CGImageGetHeight(image));
    NSDictionary *options = [NSDictionary dictionaryWithObjectsAndKeys:
                             [NSNumber numberWithBool:NO], kCVPixelBufferCGImageCompatibilityKey,
                             [NSNumber numberWithBool:NO], kCVPixelBufferCGBitmapContextCompatibilityKey,
                             nil];
    CVPixelBufferRef pxbuffer = NULL;
    CVReturn status = CVPixelBufferCreate(kCFAllocatorDefault, frameSize.width,
                                          frameSize.height,  kCVPixelFormatType_32ARGB, (__bridge CFDictionaryRef) options,
                                          &pxbuffer);
    NSParameterAssert(status == kCVReturnSuccess && pxbuffer != NULL);
    
    CVPixelBufferLockBaseAddress(pxbuffer, 0);
    void *pxdata = CVPixelBufferGetBaseAddress(pxbuffer);
    
    
    CGColorSpaceRef rgbColorSpace = CGColorSpaceCreateDeviceRGB();
    CGContextRef context = CGBitmapContextCreate(pxdata, frameSize.width,
                                                 frameSize.height, 8, 4*frameSize.width, rgbColorSpace,
                                                 kCGImageAlphaPremultipliedFirst);
    // suggestions from stackoverflow
    //                                                 kCGImageAlphaNoneSkipLast);
    
    CGContextDrawImage(context, CGRectMake(0, 0, CGImageGetWidth(image),
                                           CGImageGetHeight(image)), image);
    CGColorSpaceRelease(rgbColorSpace);
    CGContextRelease(context);
    
    CVPixelBufferUnlockBaseAddress(pxbuffer, 0);
    
    return pxbuffer;
}

@end
