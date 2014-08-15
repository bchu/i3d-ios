//
//  BCHScreenCaptureVideoView+Deprecated.h
//  i3d
//
//  Created by Brian Chu on 8/10/14.
//  Copyright (c) 2014 Brian. All rights reserved.
//

#import "BCHScreenCaptureVideoView.h"

@interface BCHScreenCaptureVideoView (Deprecated)
- (CGContextRef) createBitmapContextOfSize:(CGSize) size;
- (CVPixelBufferRef) pixelBufferFromCGImage: (CGImageRef) image;
@end
