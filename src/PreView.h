#import <Cocoa/Cocoa.h>
#import <AVFoundation/AVFoundation.h>

@protocol PreViewDelegate <NSObject>
-(void)usbDeviceFound:(BOOL)found;
@end

@interface PreView : NSView<AVCaptureVideoDataOutputSampleBufferDelegate> {
  AVCaptureSession           *captureSession;
  AVCaptureDevice            *device;
  CIFilter                   *filter;
  NSImageView                *imageView;
  NSString                   *target;
  id<PreViewDelegate>        delegate;
}

@property (nonatomic, retain) NSString            *target;
@property (nonatomic, readonly) AVCaptureDevice   *device; 
@property (nonatomic, retain) id<PreViewDelegate> delegate;

-(void)connect;
-(void)shutdown;
-(void)start;
-(void)stop;
-(BOOL)running;

@end
