/********************************************************************************************/
/*                                        krumelur                                          */
/*                                 by Unsworn Industries AB                                 */
/*                            Copyright (c) 2016, Nicklas Marelius                          */
/*                                   All rights reserved.                                   */
/*                                                                                          */
/*      Permission is hereby granted, free of charge, to any person obtaining a copy        */
/*      of this software and associated documentation files (the "Software"), to deal       */
/*      in the Software without restriction, including without limitation the rights        */
/*      to use, copy, modify, merge, publish, distribute, sublicense, and/or sell           */
/*      copies of the Software, and to permit persons to whom the Software is               */
/*      furnished to do so, subject to the following conditions:                            */
/*                                                                                          */
/*      The above copyright notice and this permission notice shall be included in all      */
/*      copies or substantial portions of the Software.                                     */
/*                                                                                          */
/*      THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR          */
/*      IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,            */
/*      FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE         */
/*      AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER              */
/*      LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,       */
/*      OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE       */
/*      SOFTWARE.                                                                           */
/*                                                                                          */
/********************************************************************************************/

#import <QuartzCore/QuartzCore.h>
#import "YVSChromaKeyFilter.h"
#import "Application.h"
#import "PreView.h"

#define SENC_LIMIT 50

@implementation PreView
@synthesize target, device, delegate, mode;
-(id)initWithFrame:(NSRect)frame {
  if (self = [super initWithFrame:frame]) {
    captureSession = nil;
    device =nil;
    delegate=nil;
    imgprc=nil;
    imageView=nil;
    target = nil;
    mode = kModePreview;
    senc = 0;
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
#if FAKE_EVENTS
  if (delegate) [delegate usbDeviceFound:YES];
  return ;
#endif
  for (AVCaptureDevice* cam in AVCaptureDevice.devices) {
    NSLog(@"Found capture device:%@\n", cam.localizedName);
    if ([cam.localizedName hasPrefix:target] && [cam hasMediaType:AVMediaTypeVideo]) {
      device = [cam retain];
      break ;
    }
  }
  if (!device)
    NSLog(@"Target device not found or does not support video\n");
  else
    NSLog(@"Video input: %@\n", device.localizedName);
  
  if (delegate) [delegate usbDeviceFound:(device) ? YES : NO];
}

-(void)start:(PreviewMode)preview_mode {
  NSError *err=nil;
  AVCaptureDeviceInput *input;
  AVCaptureSession *session;
  AVCaptureVideoDataOutput *output;
  NSRect bounds;
  NSDictionary *settings = [[NSBundle mainBundle].infoDictionary objectForKey:@"Calibration"];
  
  NSArray *presetPriority;

  mode = preview_mode;
  senc = 0;

#if FAKE_EVENTS
  if (mode == kModePreview) {
    NSString* fakeImagePath = [NSString stringWithFormat:@"%s/images/FAKE_%d.JPG", getwd(0), FAKE_EVENTS];
    NSLog(@"Loading fake preview: %@", fakeImagePath);
    NSImage *image = [[NSImage alloc] initWithContentsOfFile:fakeImagePath];
    imageView.image = [image autorelease];
    [self addSubview:imageView];
  }
  return;
#endif
  
  if (mode == kModePreview) {
    presetPriority = @[
      AVCaptureSessionPreset1280x720,
      AVCaptureSessionPresetHigh
    ];
  } else {
    presetPriority = @[
      AVCaptureSessionPreset352x288,
     AVCaptureSessionPresetLow
    ];
  }
  
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

  bounds = (mode == kModePreview) ? self.bounds : NSMakeRect(0, 0, 320, 240);
  
  output = [[AVCaptureVideoDataOutput alloc] init];

  output.videoSettings = @{
    (id)kCVPixelBufferWidthKey:           [NSNumber numberWithDouble:bounds.size.width/2],
    (id)kCVPixelBufferHeightKey:          [NSNumber numberWithDouble:bounds.size.height/2],
    (id)kCVPixelBufferPixelFormatTypeKey: [NSNumber numberWithUnsignedInt:kCVPixelFormatType_32BGRA]
  };

  [output setSampleBufferDelegate:self queue:dispatch_queue_create("sample buffer delegate", DISPATCH_QUEUE_SERIAL)];

  [session addOutput:output];

  if (mode == kModePreview)
    [self addSubview:imageView];

  imgprc = [[ImageProcessor alloc] init];
  
  imgprc.settings = [settings objectForKey:@"Preview"];

  captureSession = session;

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

-(void)switchMode:(PreviewMode)preview_mode {

  if ([self running] && mode == preview_mode)
    return;
  NSLog(@"Switching modes %d => %d\n", mode, preview_mode);
  [self stop];
  [self start:preview_mode];
  
}

-(BOOL)attached {
#if FAKE_EVENTS
  return YES;
#endif
  return self.device != nil;
}

- (void)captureOutput:(AVCaptureOutput *)captureOutput
didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer
       fromConnection:(AVCaptureConnection *)connection {

  CVImageBufferRef pixbuf = CMSampleBufferGetImageBuffer(sampleBuffer);
  CIImage *imagebuf = [CIImage imageWithCVImageBuffer:pixbuf];
  
  if (mode == kModePreview) {
    CIImage *output = [[imgprc filteredImage:imagebuf] retain];
    dispatch_async(dispatch_get_main_queue(), ^(void) {
        self->imageView.image = [NSImage imageWithCIImage:output];
        [output release];
      });
    return ;
  }
    
  // sentinel..

  if (senc++ < SENC_LIMIT) // wait for image to stabilize
    return ;
  
  if ([imgprc compareDetect:imagebuf] && delegate) {
    dispatch_async(dispatch_get_main_queue(), ^(void) {
        [delegate motionDetected];
    });
  }
  
}

@end
