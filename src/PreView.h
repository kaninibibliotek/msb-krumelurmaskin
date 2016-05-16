#import <Cocoa/Cocoa.h>
#import <AVFoundation/AVFoundation.h>
#import "ImageProcessor.h"

typedef enum {
  kModePreview,
  kModeSentinel
} PreviewMode;

@protocol PreViewDelegate <NSObject>
-(void)usbDeviceFound:(BOOL)found;
-(void)motionDetected;
@end

@interface PreView : NSView<AVCaptureVideoDataOutputSampleBufferDelegate> {
  AVCaptureSession           *captureSession;
  AVCaptureDevice            *device;
  ImageProcessor             *imgprc;
  NSImageView                *imageView;
  NSString                   *target;
  id<PreViewDelegate>        delegate;
  PreviewMode                mode;
  int                        senc;
}

@property (nonatomic, retain) NSString            *target;
@property (nonatomic, readonly) AVCaptureDevice   *device;
@property (nonatomic, retain) id<PreViewDelegate> delegate;
@property (nonatomic, readonly) PreviewMode       mode;

-(void)connect;
-(void)shutdown;
-(void)start:(PreviewMode)mode;
-(void)stop;
-(BOOL)running;
-(void)switchMode:(PreviewMode)mode;

@end
