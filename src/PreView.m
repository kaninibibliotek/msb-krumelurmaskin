#import <QuartzCore/QuartzCore.h>
#import "YVSChromaKeyFilter.h"

#import "PreView.h"

@implementation PreView
@synthesize target, device, delegate;
-(id)initWithFrame:(NSRect)frame {
  if (self = [super initWithFrame:frame]) {
    captureSession = nil;
    device =nil;
    delegate=nil;
    imgprc=nil;
    imageView=nil;
    target = nil;
    self.wantsLayer = YES;
    self.autoresizingMask = NSViewHeightSizable|NSViewWidthSizable;
    imageView = [[NSImageView alloc] initWithFrame:frame];
    imageView.autoresizingMask = NSViewHeightSizable|NSViewWidthSizable;
    imageView.imageScaling = /*NSImageScaleAxesIndependently;*/ NSImageScaleProportionallyUpOrDown;
  }
  return self;
}

-(void)dealloc {
  [imageView release];
  imageView =nil;
  [super dealloc];
}

-(void)shutdown {
  NSLog(@"Detaching %@\n", target);
  if (device)
    [device release];
  device = nil;
}

-(void)connect {
  if (device) {
    [self stop];
  }
  device = nil;
  for (AVCaptureDevice* cam in AVCaptureDevice.devices) {
    if ([target isEqualToString:cam.localizedName] && [cam hasMediaType:AVMediaTypeVideo]) {
      device = [cam retain];
      break ;
    }
  }
  if (!device)
    NSLog(@"Target device not found or does not support video\n");
  if (delegate) [delegate usbDeviceFound:(device) ? YES : NO];
}

-(void)start {
  NSError *err=nil;
  AVCaptureDeviceInput *input;
  AVCaptureSession *session;
  AVCaptureVideoDataOutput *output;
  NSRect bounds;
  NSDictionary *info = [[NSBundle mainBundle] infoDictionary];
  
  NSArray *presetPriority = @[
    /*
    AVCaptureSessionPreset352x288,
    AVCaptureSessionPresetLow,    
    AVCaptureSessionPreset640x480,
    AVCaptureSessionPresetMedium,
    */
    AVCaptureSessionPreset1280x720,
    AVCaptureSessionPresetHigh,
  ];
  
  if (captureSession) [self stop];

  if (!device) {
    NSLog(@"Unable to start, no device connected\n");
    return ;
  }

  session = [[AVCaptureSession alloc] init];
  input = [AVCaptureDeviceInput deviceInputWithDevice:device error:&err];
  if (err) {
    NSLog(@"Could not create input for device\n");
    [session release];
    return ;
  }
  [session addInput:input];

  for (NSString *preset in presetPriority) {
    NSLog(@"Trying %@\n", preset);
    if ([session canSetSessionPreset:preset]) {
      NSLog(@"Selecting: %@\n", preset);
      session.sessionPreset = preset;
      break ;
    }
  }
  
  bounds = self.bounds;
  
  output = [[AVCaptureVideoDataOutput alloc] init];

  output.videoSettings = @{
    (id)kCVPixelBufferWidthKey:           [NSNumber numberWithDouble:bounds.size.width/2],
    (id)kCVPixelBufferHeightKey:          [NSNumber numberWithDouble:bounds.size.height/2],
    (id)kCVPixelBufferPixelFormatTypeKey: [NSNumber numberWithUnsignedInt:kCVPixelFormatType_32BGRA]
  };

  [output setSampleBufferDelegate:self queue:dispatch_queue_create("sample buffer delegate", DISPATCH_QUEUE_SERIAL)];

  [session addOutput:output];

  
  imgprc = [[ImageProcessor alloc] init];
  
  imgprc.settings = [info objectForKey:@"Calibration"];

  captureSession = session;

  [self addSubview:imageView];
  
  [captureSession startRunning];
  
  NSLog(@"Preview started for device:%@\n", device.localizedName);
}

-(void)stop {

  imageView.image = nil;
  
  [imageView removeFromSuperview];

  if (captureSession) {
    if (captureSession.running)
      [captureSession stopRunning];
    [captureSession release];
    captureSession=nil;
  }
  [imgprc release];
  imgprc = nil;
  
}

-(BOOL)running {
  return (captureSession && captureSession.running);
}

- (void)captureOutput:(AVCaptureOutput *)captureOutput
didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer
       fromConnection:(AVCaptureConnection *)connection {

  CVImageBufferRef pixbuf = CMSampleBufferGetImageBuffer(sampleBuffer);
  CIImage *imagebuf = [CIImage imageWithCVImageBuffer:pixbuf];
  CIImage *output = [[imgprc filteredImage:imagebuf] retain];
  dispatch_async(dispatch_get_main_queue(), ^(void) {
      self->imageView.image = [NSImage imageWithCIImage:output];
      [output release];
  });
  
  
}
@end
