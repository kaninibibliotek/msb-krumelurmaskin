#import "PreView.h"

@implementation PreView
@synthesize target;
-(id)initWithFrame:(NSRect)frame {
  if (self = [super initWithFrame:frame]) {
    captureSession = nil;
    savedLayer = nil;
    target = nil;
    self.wantsLayer = YES;
  }
  return self;
}

-(void)start {
  NSError *err=nil;
  AVCaptureDevice *device;
  AVCaptureDeviceInput *input;
  AVCaptureSession *s;
  AVCaptureVideoPreviewLayer* layer;
  NSRect bounds;

  NSArray *presetPriority = @[
    AVCaptureSessionPreset352x288,
    AVCaptureSessionPresetLow,    
    AVCaptureSessionPreset640x480,
    AVCaptureSessionPresetMedium,                                                       
    AVCaptureSessionPreset1280x720,
    AVCaptureSessionPresetHigh,
  ];
  
  if (captureSession) [self stop];
  for (AVCaptureDevice* cam in AVCaptureDevice.devices) {
    if ([target isEqualToString:cam.localizedName] && [cam hasMediaType:AVMediaTypeVideo]) {
      device = [cam retain];
      break ;
    }
  }
  if (!device) {
    NSLog(@"Target device not found or does not support video\n");
    return ;
  }
  s = [[AVCaptureSession alloc] init];
  input = [AVCaptureDeviceInput deviceInputWithDevice:device error:&err];
  if (err) {
    NSLog(@"Could not create input for device\n");
    [s release];
    return ;
  }
  [s addInput:input];

  for (NSString *preset in presetPriority) {
    NSLog(@"Trying %@\n", preset);
    if ([s canSetSessionPreset:preset]) {
      NSLog(@"Selecting: %@\n", preset);
      s.sessionPreset = preset;
      break ;
    }
  }
  
  layer = [[AVCaptureVideoPreviewLayer alloc] initWithSession:s];

  bounds = self.bounds;
  
  layer.videoGravity = AVLayerVideoGravityResizeAspectFill;
  layer.position=CGPointMake(CGRectGetMidX(bounds), CGRectGetMidY(bounds));
  layer.bounds = bounds;
  layer.backgroundColor = [[NSColor greenColor] CGColor];

  captureSession = s;
  savedLayer = [self.layer retain];
  self.layer = layer;
  [captureSession startRunning];
  NSLog(@"Preview started for device:%@\n", device.localizedName);
}

#if 0
-(void)drawRect:(NSRect)rect {
  [[NSColor redColor] setFill];
  NSRectFill(rect);
  [super drawRect:rect];
}
#endif

-(void)stop {
  CALayer *t;
  if (savedLayer) {
    t = self.layer;
    self.layer = savedLayer;
    [savedLayer release];
    if (t) [t release];
  }
  savedLayer = nil;
  if (captureSession) {
    if (captureSession.running)
      [captureSession stopRunning];
    [captureSession release];
    captureSession=nil;
  }
}

-(BOOL)running {
  return (captureSession && captureSession.running);
}

@end
