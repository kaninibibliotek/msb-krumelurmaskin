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

#import "PTPCamera.h"

enum {
  kStatusIdle,
  kStatusFindCamera,
  kStatusConnect,
  kStatusCapture,
  kStatusRecieve,
  kStatusCleanup,
  kStatusCompleted,
  kStatusError
};

#define TASK_TIMEOUT 10.0

#define ERROR_DOMAIN @"PTPCameraErrorDomain"
#define ERROR(a,b) [NSError errorWithDomain:ERROR_DOMAIN code:a userInfo:@{NSLocalizedDescriptionKey: @b}]

//------------------------------------------------------------------------------------------------------------
#pragma mark - private PTPCamera
//------------------------------------------------------------------------------------------------------------

@interface PTPCamera ()
-(void)detach;
-(void)captureTimeout:(NSTimer*)timer;
-(void)captureBegin;
-(void)captureCompletedWithError:(NSError*)error;
@end

//------------------------------------------------------------------------------------------------------------
#pragma mark - PTPCamera
//------------------------------------------------------------------------------------------------------------

@implementation PTPCamera
@synthesize target, delegate, device, status;
-(id)init {
  if (self = [super init]) {
    target = nil;
    deviceBrowser = nil;
    delegate = nil;
    device = nil;
    status = kStatusIdle;
    curitem = nil;
  }
  return self;
}

-(void)connect {
  if (deviceBrowser) {
    NSLog(@"PTPCamera is searching for devices right now\n");
    return ;
  }
  status = kStatusFindCamera;
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
  [self captureBegin];
}

-(void)detach {
  if (device) {
    device.delegate = nil;
    [device release];
  }
  device = nil;
}

-(void)shutdown {
  if (status != kStatusIdle)
    [self captureCompletedWithError: ERROR(-2, "Service was shutdown")];
  [self detach];
  if (deviceBrowser) {
    [deviceBrowser stop];
    [deviceBrowser release];
  }
  deviceBrowser=nil;
}

-(void)captureTimeout:(NSTimer*)tmr {
  timer=nil;
  [self captureCompletedWithError:ERROR(status, "Task has timed out")];
}

-(void)captureBegin {
  NSError  *err;
  if (!device) {
    NSLog(@"No Device. Can not begin task\n");
    return ;
  }
  if (self.status != kStatusIdle) {
    err = ERROR(-1, "Another task already in progress\n");
    return ;
  }
  timer = [NSTimer timerWithTimeInterval: TASK_TIMEOUT
                                  target:self
                                selector:@selector(captureTimeout:)
                                userInfo:nil
                                 repeats:NO];
  [[NSRunLoop currentRunLoop] addTimer:timer forMode:NSDefaultRunLoopMode];
  status = kStatusConnect;
  NSLog(@"Starting capture\n");
  [device requestOpenSession];
}

-(void)captureCompletedWithError:(NSError*)error {

  NSString *path;
  NSFileManager *fm = [NSFileManager defaultManager];
  NSError *err;
  unsigned int status_ = status;
  
  if (timer) [timer invalidate];
  timer = nil;

  status = kStatusIdle;
  
  if (status_ == kStatusIdle)
    return ;

  if (curitem) {
    path = [@"/tmp" stringByAppendingPathComponent:curitem.name];
    if (![fm fileExistsAtPath:path])
      path = nil;
    [curitem release];
  }
  curitem = nil;

  do {
    
    if (!device)
      break ;

    switch(status_) {
     case kStatusRecieve:
       [device cancelDownload];
       break ;
     case kStatusCleanup:
       [device cancelDelete];
       break ;
    }

    [device requestDisableTethering];
    [device requestCloseSession];
    
  } while(NO) ;
  
  if (delegate)
    [delegate ptpCaptureCompleted:path withError:error];

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
    status = kStatusIdle;
    if (delegate)
      [delegate ptpCameraFound:(device) ? YES : NO];
  }
}

- (void)deviceBrowser:(ICDeviceBrowser*)browser
      didRemoveDevice:(ICDevice*)removedDevice
            moreGoing:(BOOL)moreGoing {
}

//------------------------------------------------------------------------------------------------------------
#pragma mark - ICDevice
//------------------------------------------------------------------------------------------------------------

- (void)didRemoveDevice:(ICDevice*)removedDevice {
  if (device && removedDevice == device) {
    if (status != kStatusIdle)
      [self captureCompletedWithError:ERROR(-3, "Device disconnected")];
    [self detach];
  }
}

- (void)         device:(ICDevice*)inDevice
didOpenSessionWithError:(NSError*)error {
  if (error && status != kStatusIdle) {
    [self captureCompletedWithError:error];
    return ;
  }
  [device requestEnableTethering];
}

- (void)deviceDidBecomeReady:(ICDevice*)inDevice {

}

- (void)          device:(ICDevice*)inDevice
didCloseSessionWithError:(NSError*)error {
}

- (void)   device:(ICDevice*)inDevice
didEncounterError:(NSError*)error {
  if (status != kStatusIdle)
    [self captureCompletedWithError:error];
}

//------------------------------------------------------------------------------------------------------------
#pragma mark - ICCameraDevice
//------------------------------------------------------------------------------------------------------------

- (void)deviceDidBecomeReadyWithCompleteContentCatalog:(ICDevice*)camera {
  if (status != kStatusConnect)
    return ;
  status = kStatusCapture;
  [device requestTakePicture];
}

- (void)cameraDevice:(ICCameraDevice*)camera
          didAddItem:(ICCameraItem*)item {

  if (status != kStatusCapture)
    return ;
  if ([item isKindOfClass:[ICCameraFolder class]])
    return ;
  status = kStatusRecieve;

  NSDictionary* options = @{
    ICDownloadsDirectoryURL: [NSURL fileURLWithPath:@"/tmp"]
  };
  if (curitem) [curitem release];
  curitem = [item retain];
  [device requestDownloadFile:(ICCameraFile*)item
                      options:options
             downloadDelegate:self
          didDownloadSelector:@selector(didDownloadFile:error:options:contextInfo:)
                  contextInfo:nil];
  NSLog(@"Download started for %@\n", item.name);
}

- (void)cameraDevice:(ICCameraDevice*)camera didCompleteDeleteFilesWithError:(NSError*)error {
  if (error) NSLog(@"%@\n", [error localizedDescription]);
  status = kStatusCompleted;
  [self captureCompletedWithError:nil];
}

//------------------------------------------------------------------------------------------------------------
#pragma mark - ICCameraDeviceDownloadDelegate
//------------------------------------------------------------------------------------------------------------


- (void)didDownloadFile:(ICCameraFile*)file
                  error:(NSError*)error 
                options:(NSDictionary*)options
            contextInfo:(void*)contextInfo {
  if (error)
    [self captureCompletedWithError:error];
  status = kStatusCleanup;
  [device requestDeleteFiles:@[ file ]];
}

- (void)didReceiveDownloadProgressForFile:(ICCameraFile*)file 
                          downloadedBytes:(off_t)downloadedBytes
                                 maxBytes:(off_t)maxBytes {
}


@end

//------------------------------------------------------------------------------------------------------------
#pragma mark - Test
//------------------------------------------------------------------------------------------------------------

#if _STANDALONE_TEST_
#include <sys/signal.h>
void abort_test(int s) {
  NSLog(@"Aborting\n");
  [[NSApplication sharedApplication] terminate:nil];
}
@interface PTPDelegate : NSObject<NSApplicationDelegate, PTPCameraDelegate> {
  PTPCamera *ptp;
  int loops;
}
@property (nonatomic, retain) PTPCamera *ptp;
@end

@implementation PTPDelegate
@synthesize ptp;
- (void)applicationDidFinishLaunching:(NSNotification *)aNotification {
  [ptp connect];
}
- (void)applicationWillTerminate:(NSNotification *)aNotification {
  [ptp shutdown];
}
-(void)ptpCameraFound:(BOOL)found {
  if (!found) {
    NSLog(@"No camera, no fun\n");
    [[NSApplication sharedApplication] terminate:nil];
    return ;
  }
  loops = 10;
  [ptp capture];
}
-(void)ptpCaptureCompleted:(NSString*)imagePath withError:(NSError*)error {
  NSLog(@"We captured an image: %@\n", (error) ? [error localizedDescription] : @"Success!");
  NSLog(@"Camera status: %d\n", ptp.status);

  if (imagePath)
    [[NSFileManager defaultManager] removeItemAtPath:imagePath error:nil];
  
  if (--loops > 0) {
    [ptp capture];
    return ;
  }
  [[NSApplication sharedApplication] terminate:nil];
}
@end

int main(int argc, char **argv) {

  signal(SIGINT, abort_test);
  @autoreleasepool {
    NSApplication *app = [NSApplication sharedApplication];
    PTPDelegate   *me = [[[PTPDelegate alloc] init] autorelease];
    me.ptp = [[[PTPCamera alloc] init] autorelease];
    app.delegate = me;
    me.ptp.target = @"D3200";
    me.ptp.delegate = me;

    [app run];
  }
  return 0;
}
#endif
