#import <WebKit/WebKit.h>
#import "Application.h"
#import "Runtime.h"

@interface Application ()
  
@end

@implementation Application
@synthesize window, videoView, preview, camera;

- (id) init {
  if (self = [super init]) {
    window = nil;
    videoView = nil;
    preview = nil;
    camera = nil;
  }
  return self;
}

#pragma mark - Menu actions..

-(void)togglePreview:(id)sender {
  if ([preview running]) [preview stop];
  else [preview start];
}

-(void)captureImage:(id)sender {
  
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
  id val, info;
  
  [defaults synchronize];

  window = [[NSWindow alloc] initWithContentRect:frame
            styleMask: NSTitledWindowMask|NSClosableWindowMask|NSMiniaturizableWindowMask|NSResizableWindowMask
            backing: NSBackingStoreBuffered
            defer:NO];

  info = bundle.infoDictionary;
  
  window.title = @"Krumeluren";
  if ((val = [info objectForKey:@"WindowTitle"]))
    window.title = val;
  window.delegate = self;

  camera = [[PTPCamera alloc] init];
  camera.target = @"None";
  if ((val = [info objectForKey:@"PTPCameraDeviceName"]))
    camera.target = val;
  camera.delegate = self;

  preview = [[PreView alloc] initWithFrame:frame];
  preview.target = @"None";
  if ((val = [info objectForKey:@"USBCameraDeviceName"]))
    preview.target = val;
  preview.delegate = self;

  view = [[[NSView alloc] initWithFrame:frame] autorelease];
    
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
  [ms addItemWithTitle:@"Preview" action:@selector(togglePreview:) keyEquivalent:@"p"];
  [ms addItemWithTitle:@"Capture" action:@selector(captureImage:) keyEquivalent:@"c"];
  [mb setSubmenu:ms forItem:mi];
  
  mi = [mb addItemWithTitle:@"Help" action:nil keyEquivalent:@""];
  ms = [[[NSMenu alloc] initWithTitle:mi.title] autorelease];
  [mb setSubmenu:ms forItem:mi];

  [app setMainMenu:mb];
    
  window.contentView = view;

  [window makeKeyAndOrderFront:nil];

  [window center];

  intro = [[QCView alloc] initWithFrame:frame];
  intro.autoresizesSubviews = YES;
  intro.autoresizingMask = NSViewHeightSizable|NSViewWidthSizable;

  [intro loadCompositionFromFile:[bundle pathForResource:@"intro" ofType:@"qtz"]];
  intro.eraseColor = [NSColor whiteColor];
  [view addSubview:intro];

}

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification {
  NSApplication *app = [NSApplication sharedApplication];
  NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
  NSBundle *bundle = [NSBundle mainBundle];
  [intro startRendering];

  [defaults synchronize];
  [[Runtime sharedRuntime] run:@"main"];
  [preview connect];
  [camera connect];
}

- (void)applicationWillTerminate:(NSNotification *)aNotification {
  if (intro) {
    [intro unloadComposition];
    [intro removeFromSuperview];
    [intro release];
  }
  intro = nil;
  if ([preview running])
    [preview stop];
  [preview shutdown];
  [camera shutdown];
  self.preview = nil;
  self.camera = nil;
  [[Runtime sharedRuntime] shutdown];
  [window release];
}

- (BOOL)applicationShouldTerminateAfterLastWindowClosed:(NSApplication *)sender {
  return YES;
}

-(void)usbDeviceFound:(BOOL)found {
  NSLog(@"USB Video camera found: %d\n", found);
}

-(void)ptpCameraFound:(BOOL)found {
  NSLog(@"SLR usb camera found: %d\n", found);
}

-(void)ptpCameraReady {
  NSLog(@"SLR camera ready\n");
}

@end
