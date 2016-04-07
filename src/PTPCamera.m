#import "PTPCamera.h"

@interface PTPCamera ()
-(void)detach;
@end

@implementation PTPCamera
@synthesize target, delegate, device;
-(id)init {
  if (self = [super init]) {
    target = nil;
    deviceBrowser = nil;
    delegate = nil;
    device = nil;
  }
  return self;
}

-(void)connect {
  if (deviceBrowser) {
    NSLog(@"PTPCamera is searching for devices right now\n");
    return ;
  }
  deviceBrowser = [[ICDeviceBrowser alloc] init];
  deviceBrowser.delegate = self;
  deviceBrowser.browsedDeviceTypeMask=ICDeviceLocationTypeMaskLocal|ICDeviceTypeMaskCamera;
  [deviceBrowser start];
  NSLog(@"PTPCamera scanning for devices..\n");
}

-(void)capture {
  if (!device) {
    NSLog(@"No camera attached or not ready\n");
    return ;
  }
  NSLog(@"Started capture...\n");
  [device requestOpenSession];
}

-(void)detach {
  NSLog(@"Detaching from device %@\n", target);
  if (device) {
    device.delegate = nil;
    [device release];
  }
  device = nil;
}

-(void)shutdown {
  [self detach];
  NSLog(@"Stopping ICDeviceBrowser\n");
  if (deviceBrowser) {
    [deviceBrowser stop];
    [deviceBrowser release];
  }
  deviceBrowser=nil;
}

//------------------------------------------------------------------------------------------------------------
#pragma mark - ICDeviceBrowser
//------------------------------------------------------------------------------------------------------------

- (void)deviceBrowser:(ICDeviceBrowser*)browser
         didAddDevice:(ICDevice*)addedDevice
           moreComing:(BOOL)moreComing {

  ICCameraDevice *found=nil;
  
  if (!device && [addedDevice.name isEqualToString:target]) {
    NSLog(@"Found %@\n", target);
    found = (ICCameraDevice*)addedDevice;
    if ([found.capabilities containsObject:ICCameraDeviceCanTakePicture]) {
      device = [found retain];
      device.delegate = self;
    } else {
      NSLog(@"Device %@ does not support capture\n", found.name);
    }

  }

  if (!moreComing) {
    if (delegate)
      [delegate ptpCameraFound:(device) ? YES : NO];
  }

}

- (void)deviceBrowser:(ICDeviceBrowser*)browser
      didRemoveDevice:(ICDevice*)removedDevice
            moreGoing:(BOOL)moreGoing {
  if (device && removedDevice == device) {
    NSLog(@"Device was unplugged (ICDeviceBrowser)\n");
    [self detach];
  }
}

//------------------------------------------------------------------------------------------------------------
#pragma mark - ICDevice
//------------------------------------------------------------------------------------------------------------

- (void)didRemoveDevice:(ICDevice*)removedDevice {
  if (device && removedDevice == device) {
    NSLog(@"Device was unplugged (ICDevice)\n");
    [self detach];
  }
}

- (void)         device:(ICDevice*)inDevice
didOpenSessionWithError:(NSError*)error {
  if (error) {
    return ;
  }
  NSLog(@"Enabling tethering\n");
  [device requestEnableTethering];
}

- (void)deviceDidBecomeReady:(ICDevice*)inDevice {
  NSLog(@"Capturing image\n");
  [device requestTakePicture];
}

- (void)          device:(ICDevice*)inDevice
didCloseSessionWithError:(NSError*)error {
  NSLog(@"Capture was completed..\n");
}

- (void)   device:(ICDevice*)inDevice
didEncounterError:(NSError*)error {
    NSLog( @"device: \n%@\ndidEncounterError: \n%@\n", device, error );
}

//------------------------------------------------------------------------------------------------------------
#pragma mark - ICCameraDevice
//------------------------------------------------------------------------------------------------------------

- (void)cameraDevice:(ICCameraDevice*)camera
          didAddItem:(ICCameraItem*)item {
  NSLog(@"New item available: %@\n", item.name);

}
@end
