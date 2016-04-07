#import <Cocoa/Cocoa.h>
#import <WebKit/WebKit.h>
#import "VideoView.h"
#import "PreView.h"

#define app_ ((Application*)[NSApplication sharedApplication].delegate)

@interface Application : NSObject <NSApplicationDelegate, NSWindowDelegate> {
  NSWindow  *window;
  VideoView *videoView;
  PreView   *preview;
}

@property (nonatomic, retain) NSWindow *window;
@property (nonatomic, retain) VideoView *videoView;
@property (nonatomic, retain) PreView *preview;
@end
