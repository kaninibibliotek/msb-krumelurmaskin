#import <Cocoa/Cocoa.h>
#import <WebKit/WebKit.h>
#import "VideoView.h"
#import "PreView.h"
#import "PTPCamera.h"

#define app_ ((Application*)[NSApplication sharedApplication].delegate)

@interface Application : NSObject <NSApplicationDelegate, NSWindowDelegate, PreViewDelegate, PTPCameraDelegate> {
  NSWindow  *window;
  VideoView *videoView;
  PreView   *preview;
  PTPCamera *camera;
}

@property (nonatomic, retain) NSWindow  *window;
@property (nonatomic, retain) VideoView *videoView;
@property (nonatomic, retain) PreView   *preview;
@property (nonatomic, retain) PTPCamera *camera;
@end
