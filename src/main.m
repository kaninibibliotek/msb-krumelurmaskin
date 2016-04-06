#import <Cocoa/Cocoa.h>
#import "Application.h"

int main(int argc, const char * argv[]) {
  NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
  NSApplication *app = [NSApplication sharedApplication];
  Application *delegate = [[[Application alloc] init] autorelease];

  app.delegate = delegate;

  [app run];

  [pool drain];

  return 0;
}
