#import <Cocoa/Cocoa.h>
#import <WebKit/WebKit.h>
#import <Quartz/Quartz.h>
#import <WebKit/WebKit.h>

#import "VideoView.h"
#import "PreView.h"
#import "PTPCamera.h"
#import "Controls.h"

#define app_ ((Application*)[NSApplication sharedApplication].delegate)

@interface Application : NSObject <NSApplicationDelegate, NSWindowDelegate, PreViewDelegate, PTPCameraDelegate, ControlDelegate> {
  NSWindow     *window;
  WebView      *main;
  PreView      *preview;
  PTPCamera    *camera;
  QCView       *intro;
  NSView       *view;
  NSTimer      *timer;
  NSImageView  *imageview;
  Controls     *controls;
}

@property (nonatomic, retain) NSWindow    *window;
@property (nonatomic, retain) WebView     *main;
@property (nonatomic, retain) PreView     *preview;
@property (nonatomic, retain) PTPCamera   *camera;
@property (nonatomic, retain) NSImageView *imageview;
@property (nonatomic, retain) Controls    *controls;

@end
