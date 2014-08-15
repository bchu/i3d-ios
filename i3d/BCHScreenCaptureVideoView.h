
/**
 * ScreenCaptureView, a UIView subclass that periodically samples its current display
 * and stores it as a UIImage available through the 'currentScreen' property.  The
 * sample/update rate can be configured (within reason) by setting the 'frameRate'
 * property.
 *
 * This class can also be used to record real-time video of its subviews, using the
 * 'startRecording' and 'stopRecording' methods.  A new recording will overwrite any
 * previously made recording file, so if you want to create multiple recordings per
 * session (or across multiple sessions) then it is your responsibility to copy/back-up
 * the recording output file after each session.
 *
 * To use this class, you must link against the following frameworks:
 *
 *  - AssetsLibrary
 *  - AVFoundation
 *  - CoreGraphics
 *  - CoreMedia
 *  - CoreVideo
 *  - QuartzCore
 *
 
 Credit to:
 recording code: http://codethink.no-ip.org/wordpress/archives/673
 streaming ideas: http://stackoverflow.com/questions/1960782/upload-live-streaming-video-from-iphone-like-ustream-or-qik
 
 */

@import UIKit;
@import QuartzCore;
@import CoreVideo;
@import CoreMedia;
@import CoreGraphics;
@import AVFoundation;
@import AssetsLibrary;

@interface BCHScreenCaptureVideoView : UIWindow
//for accessing the current screen and adjusting the capture rate, etc.
@property(assign) float frameRate;
@property (readonly, getter = isStarted, nonatomic) BOOL started;
@property (strong, nonatomic) NSString *url;
- (void)start;
- (void)stop;
@end