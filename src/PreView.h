#import <Cocoa/Cocoa.h>
#import <AVFoundation/AVFoundation.h>

@interface PreView : NSView {
  AVCaptureSession           *captureSession;
  CALayer                    *savedLayer;
  NSString                   *target;
}

@property (nonatomic, retain) NSString *target;

-(void)start;
-(void)stop;
-(BOOL)running;

@end
