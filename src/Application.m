#import <WebKit/WebKit.h>
#import "Application.h"
#import "Runtime.h"

@interface Application ()
  
@end

@implementation Application
@synthesize window, videoView, preview;

- (id) init {
  if (self = [super init]) {
    window = nil;
    videoView = nil;
    preview = nil;
  }
  return self;
}

#pragma mark - Menu actions..

-(void)togglePreview:(id)sender {
  if ([preview running]) [preview stop];
  else [preview start];
}

-(BOOL)validateMenuItem:(NSMenuItem*)item {
  return YES;
}

#pragma mark - Application Delegate

- (void)applicationWillFinishLaunching:(NSNotification *)aNotification {

  CGRect frame = CGRectMake(0, 0, 1024, 768);
  NSBundle *bundle = [NSBundle mainBundle];
  NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
  NSApplication *app = [NSApplication sharedApplication];

  [defaults synchronize];

  window = [[NSWindow alloc] initWithContentRect:frame
            styleMask: NSTitledWindowMask|NSClosableWindowMask|NSMiniaturizableWindowMask|NSResizableWindowMask
            backing: NSBackingStoreBuffered
            defer:NO];

  window.title = @"Krumeluren";
  window.delegate = self;

  NSMenuItem *mi;
  NSMenu *ms=nil, *mb = [[[NSMenu alloc] init] autorelease];

  mb.autoenablesItems = YES;  

  mi = [mb addItemWithTitle:@"Krumeluren" action:nil keyEquivalent:@""];
  ms = [[[NSMenu alloc] initWithTitle:@"Krumeluren"] autorelease];

  [ms addItemWithTitle:@"About Krumeluren" action:@selector(aboutAction:) keyEquivalent:@""];
  [ms addItem:[NSMenuItem separatorItem]];
  [ms addItemWithTitle:@"Preferences" action:@selector(preferencesAction:) keyEquivalent:@""];
  [ms addItem:[NSMenuItem separatorItem]];
  [ms addItemWithTitle:@"Services" action:nil keyEquivalent:@""];
  [ms addItem:[NSMenuItem separatorItem]];
  [ms addItemWithTitle:@"Hide Krumeluren" action:@selector(hide:) keyEquivalent:@"h"];
  [ms addItemWithTitle:@"Hide Others" action:@selector(hideOtherApplications:) keyEquivalent:@""];
  [ms addItem:[NSMenuItem separatorItem]];
  [ms addItemWithTitle:@"Quit Krumeluren" action:@selector(terminate:) keyEquivalent:@"q"];
  [mb setSubmenu:ms forItem:mi];

  mi = [mb addItemWithTitle:@"File" action:nil keyEquivalent:@""];
  ms = [[[NSMenu alloc] initWithTitle:mi.title] autorelease];
  [ms addItemWithTitle:@"Preview" action:@selector(togglePreview:) keyEquivalent:@"P"];
  [mb setSubmenu:ms forItem:mi];
  
  mi = [mb addItemWithTitle:@"Help" action:nil keyEquivalent:@""];
  ms = [[[NSMenu alloc] initWithTitle:mi.title] autorelease];
  [mb setSubmenu:ms forItem:mi];

  [app setMainMenu:mb];

  preview = [[[PreView alloc] initWithFrame:frame] autorelease];

  preview.target = @"Trust Webcam";
    
  window.contentView = preview;

  [window makeKeyAndOrderFront:nil];

  [window center];
}

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification {
  NSApplication *app = [NSApplication sharedApplication];
  NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
  [defaults synchronize];
  [[Runtime sharedRuntime] run:@"main"];
}

- (void)applicationWillTerminate:(NSNotification *)aNotification {
  [[Runtime sharedRuntime] shutdown];
}

- (BOOL)applicationShouldTerminateAfterLastWindowClosed:(NSApplication *)sender {
  return YES;
}


@end
