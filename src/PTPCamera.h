#ifndef PTPCamera_H_
#define PTPCamera_H_

#import <Cocoa/Cocoa.h>
#import <ImageCaptureCore/ImageCaptureCore.h>

@protocol PTPCameraDelegate <NSObject>
-(void)ptpCameraFound:(BOOL)found;
-(void)ptpCaptureCompleted:(NSImage*)image withError:(NSError*)err;
@end

@interface PTPCamera : NSObject<ICDeviceBrowserDelegate, ICCameraDeviceDelegate, ICCameraDeviceDownloadDelegate> {
  NSString               *target;
  ICDeviceBrowser        *deviceBrowser;
  id <PTPCameraDelegate> delegate;
  ICCameraDevice         *device;
  NSTimer                *timer;
  unsigned int           status;
  ICCameraItem           *curitem;
}

@property (nonatomic, retain)   NSString              *target;
@property (nonatomic, retain)   id<PTPCameraDelegate> delegate;
@property (nonatomic, readonly) ICCameraDevice        *device;
@property (nonatomic, readonly) unsigned int          status;

-(void)connect;
-(void)capture;
-(void)shutdown;

@end

#endif
