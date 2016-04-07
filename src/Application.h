#import <Cocoa/Cocoa.h>
#import <WebKit/WebKit.h>
#import "VideoView.h"

#define app_ ((Application*)[NSApplication sharedApplication].delegate)

@interface Application : NSObject <NSApplicationDelegate, NSWindowDelegate> {
  NSWindow  *window;
  VideoView *videoView;
}

@property (nonatomic, retain) NSWindow *window;
@property (nonatomic, retain) VideoView *videoView;

@end
