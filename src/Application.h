#import <Cocoa/Cocoa.h>
#import <WebKit/WebKit.h>
#import "Runtime.h"

#define app_ ((Application*)[NSApplication sharedApplication].delegate)

@interface Application : NSObject <NSApplicationDelegate, NSWindowDelegate> {
  NSWindow  *window;
  Runtime   *runtime;
}

@property (nonatomic, retain) NSWindow *window;

@end
