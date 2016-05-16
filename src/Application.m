#import <WebKit/WebKit.h>
#import "Application.h"
#import "Runtime.h"

#define TIMER_INTERVAL 0.5
#define ERROR_DOMAIN @"ApplicationDomain"
#define ERROR(a,b) [NSError errorWithDomain:ERROR_DOMAIN code:a userInfo:@{NSLocalizedDescriptionKey: @b}]

//------------------------------------------------------------------------------------------------------------

enum {
  kStatusIntro,  
  kStatusIdle,
  kStatusPreview,
  kStatusCapture,
  kStatusProcess,
  kStatusPublish
};

//------------------------------------------------------------------------------------------------------------

typedef struct {
  const char   *name;
  unsigned int next;
  unsigned int timeout;
  BOOL         init;
  double       limit;
} ssm_t;

//------------------------------------------------------------------------------------------------------------

static ssm_t sm[] = {
  {"intro",   kStatusIdle,    kStatusIdle, YES, 5.0},
  {"idle" ,   kStatusPreview, kStatusIdle, YES, 0.0},
  {"preview", kStatusCapture, kStatusIdle, YES, 30.0},
  {"capture", kStatusProcess, kStatusIdle, YES, 10.0},
  {"process", kStatusPublish, kStatusIdle, YES, 5.0},
  {"publish", kStatusIdle,    kStatusIdle, YES, 5.0}
};

//------------------------------------------------------------------------------------------------------------

@interface Application ()
-(void)nextState;
-(void)gotoState:(unsigned int)state;
-(void)handleTimer:(NSTimer*)timer;
-(void)initState:(unsigned int)state error:(NSError**)err;
-(void)updateState;
-(void)exitState:(unsigned int)current;
-(void)enterState:(unsigned int)next error:(NSError**)err;

@end

//------------------------------------------------------------------------------------------------------------

@implementation Application
@synthesize window, main, preview, camera, imageview, controls;

- (id) init {
  if (self = [super init]) {
    window = nil;
    main = nil;
    preview = nil;
    camera = nil;
    timer = nil;
    imageview = nil;
    controls = nil;
    status = kStatusIntro;
    stime  = 0;
  }
  return self;
}

//------------------------------------------------------------------------------------------------------------
#pragma mark - Menu actions..
//------------------------------------------------------------------------------------------------------------

-(void)togglePreview:(id)sender {
  [self gotoState:kStatusPreview];
}

-(void)captureImage:(id)sender {
  [self gotoState:kStatusCapture];
}

-(BOOL)validateMenuItem:(NSMenuItem*)item {
  return YES;
}

//------------------------------------------------------------------------------------------------------------
#pragma mark - Application Delegate
//------------------------------------------------------------------------------------------------------------

- (void)applicationWillFinishLaunching:(NSNotification *)aNotification {

  CGRect frame = CGRectMake(0, 0, 1024, 768);
  NSBundle *bundle = [NSBundle mainBundle];
  NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
  NSApplication *app = [NSApplication sharedApplication];
  NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
  WebPreferences *prefs = [[WebPreferences alloc] init];
  
  id val, info;
  
  [defaults synchronize];

  info = bundle.infoDictionary;

  if ((val = [info objectForKey:@"InitialWidth"]))
    frame.size.width = atol([val UTF8String]);
  if ((val = [info objectForKey:@"InitialHeight"]))
    frame.size.height = atol([val UTF8String]);

  window = [[NSWindow alloc] initWithContentRect:frame
            styleMask: NSTitledWindowMask|NSClosableWindowMask|NSMiniaturizableWindowMask|NSResizableWindowMask
            backing: NSBackingStoreBuffered
            defer:NO];

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


  prefs.autosaves = NO;
  prefs.privateBrowsingEnabled = YES;
  prefs.javaScriptEnabled = YES;
  prefs.plugInsEnabled = YES;
  prefs.javaScriptCanOpenWindowsAutomatically = NO;
  prefs.javaEnabled = NO;
  prefs.loadsImagesAutomatically = YES;
  prefs.allowsAnimatedImages = YES;


  main = [[WebView alloc] initWithFrame:frame frameName:@"main" groupName:nil];
  main.autoresizingMask = NSViewHeightSizable|NSViewWidthSizable;
  main.preferences = prefs;

  main.UIDelegate = self;
  main.frameLoadDelegate = self;
  main.resourceLoadDelegate = self;

  imageview = [[NSImageView alloc] initWithFrame:frame];
  imageview.autoresizingMask = NSViewHeightSizable|NSViewWidthSizable;
  imageview.imageScaling = NSImageScaleProportionallyUpOrDown;
  
  view = [[[NSView alloc] initWithFrame:frame] autorelease];
  view.autoresizesSubviews = YES;

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
  [ms addItemWithTitle:@"Switch mode" action:@selector(switchPreviewMode:) keyEquivalent:@"m"];
  [ms addItemWithTitle:@"Capture" action:@selector(captureImage:) keyEquivalent:@"c"];
  [mb setSubmenu:ms forItem:mi];
  
  mi = [mb addItemWithTitle:@"Help" action:nil keyEquivalent:@""];
  ms = [[[NSMenu alloc] initWithTitle:mi.title] autorelease];
  [mb setSubmenu:ms forItem:mi];

  [app setMainMenu:mb];
    
  window.contentView = view;

  intro = [[QCView alloc] initWithFrame:frame];
  intro.autoresizingMask = NSViewHeightSizable|NSViewWidthSizable;
  intro.autostartsRendering = YES;
  intro.eraseColor = [NSColor whiteColor];

  if ((val = [info objectForKey:@"IntroAnimation"]))
    [intro loadCompositionFromFile:[bundle pathForResource:val ofType:@"qtz"]];
  
  [view addSubview:main];
  [view addSubview:imageview];
  [view addSubview:preview];

  main.hidden = YES;
  preview.hidden = YES;
  imageview.hidden = YES;
  
  [view addSubview:intro];

  [window makeKeyAndOrderFront:nil];

  [window center];
}

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification {
  [[NSApplication sharedApplication] activateIgnoringOtherApps:YES];
  [[Runtime sharedRuntime] run:@"main"];
  [preview connect];
  [camera connect];
  timer = [NSTimer timerWithTimeInterval:TIMER_INTERVAL
    target:self selector:@selector(handleTimer:)
    userInfo:nil repeats:YES];
  [[NSRunLoop currentRunLoop] addTimer:timer forMode:NSDefaultRunLoopMode];
}

- (void)applicationWillTerminate:(NSNotification *)aNotification {

  if (timer) [timer invalidate];
  timer = nil;
  
  if (preview) [preview stop];
  preview = nil;
  
  if (camera) [camera shutdown];
  camera = nil;

  [[Runtime sharedRuntime] shutdown];
  
  [window release];
}

- (BOOL)applicationShouldTerminateAfterLastWindowClosed:(NSApplication *)sender {
  return YES;
}

//------------------------------------------------------------------------------------------------------------
#pragma mark - ssm
//------------------------------------------------------------------------------------------------------------

-(void)nextState {
  [self gotoState:sm[status].next];
}

-(void)gotoState:(unsigned int)next {
  NSError *err=nil;
  NSLog(@"Switching states [%s => %s]", sm[status].name, sm[next].name);

  [self exitState:status];
  stime = 0;
  
  if (sm[next].init) {
    NSLog(@"Running initializer for state: %s", sm[next].name);
    [self initState:next error:&err];
    sm[next].init = NO;
  }

  if (!err)
    [self enterState:next error:&err];

  if (err) {
    NSLog(@"Unable to transition to next state: %@", [err localizedDescription]);
    [[NSApplication sharedApplication] terminate:nil];
    return ;
  }
  
  status = next;
}

-(void)handleTimer:(NSTimer*)timer {
  stime += TIMER_INTERVAL;
  [self updateState];
  if (!sm[status].limit) return ; // no limit..
  if (stime < sm[status].limit) return ;  
  NSLog(@"current state[%s] timed out", sm[status].name);
  [self gotoState:sm[status].timeout];
}

-(void)initState:(unsigned int)state error:(NSError**)err {
  NSDictionary *info = ([NSBundle mainBundle]).infoDictionary;
  NSString     *val, *url;

  switch(state) {
   case kStatusIdle:
     if (!(val = [info objectForKey:@"FaceAnimation"])) {
       if (err) *err = ERROR(1, "No animation file specified in info plist");
       break ;
     }
     url = [@"http://127.0.0.1:8881/" stringByAppendingString:val];
     [main.mainFrame loadRequest:[NSURLRequest requestWithURL:[NSURL URLWithString:url]]];
     main.hidden = NO;
     break;
   case kStatusPreview:
     if (!preview.device) {
       if (err) *err = ERROR(1, "No Video camera attached");
       break;
     }
   case kStatusCapture:
     if (!camera.device) {
       if (err) *err = ERROR(1, "No SLR Camera attached");
       break ;
     }
  }
}

-(void)updateState {
  if (status == kStatusPreview && controls) {
    [controls button]; // poll button
  }
}


-(void)exitState:(unsigned int)current {

  switch(current) {
   case kStatusIntro:
     if (!intro) break ;
     [intro unloadComposition];
     [intro removeFromSuperview];
     [intro release];
     intro = nil;
     break;
   case kStatusIdle:
     main.hidden = YES;
     [preview stop];
     break ;
   case kStatusPreview:
     preview.hidden = YES;
     [controls brightness:0];
     controls = nil;
     break;
  }
}

-(void)enterState:(unsigned int)next error:(NSError**)err {
  
  switch(next) {
   case kStatusIdle:
     main.hidden = NO;
     [preview start:kModeSentinel];
     break;
   case kStatusPreview:
     [preview start:kModePreview];
     preview.hidden = NO;
     controls = [Controls controlsWithTarget:self];
     [controls brightness:100];
     break ;
  }
  
}

//------------------------------------------------------------------------------------------------------------
#pragma mark - PreViewDelgate
//------------------------------------------------------------------------------------------------------------

-(void)usbDeviceFound:(BOOL)found {
  NSLog(@"USB Video camera found: %d\n", found);
}

-(void)motionDetected {
  NSLog(@"Motion Detect!");
  [self nextState];
}

//------------------------------------------------------------------------------------------------------------
#pragma mark - ControlDelgate
//------------------------------------------------------------------------------------------------------------

-(void)controlChanged:(id)sender reason:(int)rs {
  switch(rs) {
   case 1: [(Controls*)sender brightness:254]; break;
  }
}

//------------------------------------------------------------------------------------------------------------
#pragma mark - PTPCameraDelegate
//------------------------------------------------------------------------------------------------------------

-(void)ptpCameraFound:(BOOL)found {
  NSLog(@"SLR usb camera found: %d\n", found);
}

-(void)ptpCaptureCompleted:(NSString*)imagePath withError:(NSError*)err {
  if (err) {
    NSLog(@"ptpCameraCapture: %@", [err localizedDescription]);
    return ;
  }
  NSLog(@"We captured an image: %@\n", imagePath);
  NSLog(@"Camera status: %d\n", self.camera.status);

  if (imagePath) [[NSFileManager defaultManager] removeItemAtPath:imagePath error:nil];
  
  /*
  NSImage *image = [NSImage imageWithContentsOfFile:imagePath];
  NSImageRep *rep = [[image representations] objectAtIndex:0];
  NSSize imageSize = NSMakeSize(rep.pixelsWide, rep.pixelsHigh);
  NSLog(@"Image dimensions: [%f, %f]\n", imageSize.width, imageSize.height);
  self.imageview.image = image;
  self.imageview.hidden = NO;
  self.main.hidden = YES;
  self.preview.hidden = YES;
  */
}

//------------------------------------------------------------------------------------------------------------
#pragma mark - WebView Delegate.
//------------------------------------------------------------------------------------------------------------

- (void)webView:(WebView *)sender didFinishLoadForFrame:(WebFrame *)frame {
}

- (void)webView:(WebView *)sender didFailLoadWithError:(NSError *)error forFrame:(WebFrame *)frame {
  NSLog(@"failed to load frame: %@\n", [error localizedDescription]);
}

- (void)webView:(WebView *)webView didClearWindowObject:(WebScriptObject *)windowScriptObject forFrame:(WebFrame *)frame {

}

- (void)webView:(WebView *)sender runJavaScriptAlertPanelWithMessage:(NSString *)message {
  NSLog(@"javascript alert: %@\n", message);
}

- (void)webView:(WebView *)webView resource:(id)identifier didFailLoadingWithError:(NSError *)error fromDataSource:(WebDataSource *)dataSource {
  NSLog(@"Error loading resource : %@", error);
}

- (NSURLRequest*) webView:(WebView*)sender
  resource:(id)identifier
  willSendRequest:(NSURLRequest*)request
  redirectResponse:(NSURLResponse*)redirectResponse
  fromDataSource:(WebDataSource*)dataSource
{
  NSURL *url = request.URL;
  NSLog(@"request: %@\n", [url absoluteString]);
  return request;
}

- (void)webView:(WebView *)webView addMessageToConsole:(NSDictionary *)message forFrame:(WebFrame *)frame {
  NSLog(@"Javascript error: %@",message);
}

@end
