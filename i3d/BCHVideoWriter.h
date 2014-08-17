//
//  BCHVideoWriter.h
//  i3d
//
//  Created by Brian Chu on 8/9/14.
//  Copyright (c) 2014 Brian. All rights reserved.
//

@import UIKit;
@import CoreMedia;
@class SRWebSocket;

/**
 * Delegate protocol.  Implement this if you want to receive a notification when the
 * view completes a recording.
 *
 * When a recording is completed, the BCHVideoWriterDelegate will notify the delegate, passing
 * it the path to the created recording file if the recording was successful, or a value
 * of nil if the recording failed/could not be saved.
 */
@protocol BCHVideoWriterDelegate <NSObject>
- (void) recordingFinished:(NSString*)outputPathOrNil;
@end

@interface BCHVideoWriter : NSObject
@property (nonatomic) BOOL recording;
@property (strong, nonatomic) NSDate* startedAt;
@property (weak, nonatomic) id<BCHVideoWriterDelegate> delegate;


- (BOOL)setUpWriterWithSize:(CGSize)size url:(NSURL *)fileURL;
- (void)startRecording;
- (void)stopRecording;
- (void)stopRecordingThenUploadWithSocket:(SRWebSocket *)socket;
- (void)writeVideoFrameAtTime:(CMTime)time image:(UIImage *)image;
- (void)uploadWithSocket:(SRWebSocket *)socket;
@end
