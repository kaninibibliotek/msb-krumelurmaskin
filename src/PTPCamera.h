#ifndef PTPCamera_H_
#define PTPCamera_H_

#import <Cocoa/Cocoa.h>
#import <ImageCaptureCore/ImageCaptureCore.h>

@protocol PTPCameraDelegate <NSObject>
-(void)ptpCameraFound:(BOOL)found;
-(void)ptpCameraReady;
@end

@interface PTPCamera : NSObject<ICDeviceBrowserDelegate, ICCameraDeviceDelegate> {
  NSString               *target;
  ICDeviceBrowser        *deviceBrowser;
  id <PTPCameraDelegate> delegate;
  ICCameraDevice         *device;
}

@property (nonatomic, retain) NSString              *target;
@property (nonatomic, retain) id<PTPCameraDelegate> delegate;
@property (nonatomic, readonly) ICCameraDevice      *device;

-(void)connect;
-(void)capture;
-(void)shutdown;

@end

#endif
