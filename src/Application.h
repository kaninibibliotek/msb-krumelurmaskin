#import <Cocoa/Cocoa.h>
#import <WebKit/WebKit.h>

#define app_ ((Application*)[NSApplication sharedApplication].delegate)

@interface Application : NSObject <NSApplicationDelegate, NSWindowDelegate> {
  NSWindow  *window;
}

@property (nonatomic, retain) NSWindow *window;

@end