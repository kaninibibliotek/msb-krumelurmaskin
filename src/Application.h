#import <Cocoa/Cocoa.h>
#import <WebKit/WebKit.h>
#import <Quartz/Quartz.h>
#import <WebKit/WebKit.h>

#import "VideoView.h"
#import "PreView.h"
#import "PTPCamera.h"


#define app_ ((Application*)[NSApplication sharedApplication].delegate)

@interface Application : NSObject <NSApplicationDelegate, NSWindowDelegate, PreViewDelegate, PTPCameraDelegate> {
  NSWindow     *window;
  WebView      *main;
  PreView      *preview;
  PTPCamera    *camera;
  QCView       *intro;
  NSView       *view;
  NSTimer      *timer;
}

@property (nonatomic, retain) NSWindow  *window;
@property (nonatomic, retain) WebView   *main;
@property (nonatomic, retain) PreView   *preview;
@property (nonatomic, retain) PTPCamera *camera;
@end
