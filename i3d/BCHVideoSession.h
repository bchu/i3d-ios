//
//  BCHVideoSession.h
//  i3d
//
//  Created by Brian Chu on 9/1/14.
//  Copyright (c) 2014 Brian. All rights reserved.
//

#import "VCSimpleSession.h"
#import <Foundation/Foundation.h>
#import <CoreGraphics/CoreGraphics.h>
#import <UIKit/UIKit.h>

@interface BCHVideoSession : NSObject

@property (nonatomic, readonly) VCSessionState rtmpSessionState;
@property (nonatomic, strong, readonly) UIView* previewView;

/*! Setters / Getters for session properties */
@property (nonatomic, assign) CGSize            videoSize;      // Change will not take place until the next RTMP Session
@property (nonatomic, assign) int               bitrate;        // Change will not take place until the next RTMP Session
@property (nonatomic, assign) int               fps;            // Change will not take place until the next RTMP Session
@property (nonatomic, assign) float         videoZoomFactor;
@property (nonatomic, assign) int           audioChannelCount;
@property (nonatomic, assign) float         audioSampleRate;
@property (nonatomic, assign) float         micGain;        // [0..1]
@property (nonatomic, assign) BOOL          useAdaptiveBitrate;     /* Default is off */

@property (nonatomic, assign) id<VCSessionDelegate> delegate;

- (instancetype) initWithVideoSize:(CGSize)videoSize
                         frameRate:(int)fps
                           bitrate:(int)bps;
- (void) startRtmpSessionWithURL:(NSString*) rtmpUrl
                    andStreamKey:(NSString*) streamKey;

- (void) endRtmpSession;
- (void)bufferCaptured:(CVPixelBufferRef) pixelBufferRef;

@end