#import <WebKit/WebKit.h>
#import "Application.h"
#import "Runtime.h"

@interface Application ()
-(void)startServices;
-(void)stopServices;
@end

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
  }
  return self;
}

#pragma mark - Menu actions..

-(void)togglePreview:(id)sender {
  if ([preview running])
    [preview stop];
  if (preview.mode == kModePreview) {
    main.hidden=NO;
    preview.hidden=YES;
    [preview start:kModeSentinel];
  } else {
    main.hidden=YES;
    preview.hidden=NO;
    [preview start:kModePreview];
  }
}

-(void)switchPreviewMode:(id)sender {
  if (preview.mode == kModePreview)
    [preview switchMode:kModeSentinel];
  else
    [preview switchMode:kModePreview];
}

-(void)captureImage:(id)sender {
  if (!self.camera) {
    NSLog(@"Can not capture image: Camera not initialized\n");
    return ;
  }
  if (!self.camera.device) {
    NSLog(@"Can not capture image: No Device Found\n");
    return ;
  }
  [self.camera capture];
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

  [nc addObserver:self 
      selector:@selector(handleIntroBegan:) 
      name:QCViewDidStartRenderingNotification
      object:nil];

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
  timer = [NSTimer timerWithTimeInterval:2.5
    target:self selector:@selector(handleIntroTimeout:)
    userInfo:@"intro" repeats:NO];
  
  [[NSRunLoop currentRunLoop] addTimer:timer forMode:NSDefaultRunLoopMode];
}

- (void)applicationWillTerminate:(NSNotification *)aNotification {
  if (timer) {
    [timer invalidate];
  }
  
  [self stopServices];

  self.preview = nil;
  self.camera = nil;
  [window release];
}

-(void)startServices {
  NSLog(@"Starting services\n");
  [[Runtime sharedRuntime] run:@"main"];
  [preview connect];
  [camera connect];
}

-(void)stopServices {
  NSLog(@"Stopping services\n");
  if ([preview running])
    [preview stop];
  [preview shutdown];
  [camera shutdown];
  [[Runtime sharedRuntime] shutdown];
}

- (BOOL)applicationShouldTerminateAfterLastWindowClosed:(NSApplication *)sender {
  return YES;
}

-(void)usbDeviceFound:(BOOL)found {
  NSLog(@"USB Video camera found: %d\n", found);
}

-(void)motionDetected {
  NSLog(@"Motion Detect!");
  [preview stop];
  [self togglePreview:nil];
  NSLog(@"Starting timer");
  timer = [NSTimer timerWithTimeInterval:5
                                  target:self selector:@selector(handleCaptureTimeout:)
                                userInfo:@"capture" repeats:NO];
  [[NSRunLoop currentRunLoop] addTimer:timer forMode:NSDefaultRunLoopMode];
}

-(void)controlChanged:(id)sender reason:(int)rs {
  switch(rs) {
   case 1: [(Controls*)sender brightness:254]; break;
  }
}

-(void)ptpCameraFound:(BOOL)found {
  NSLog(@"SLR usb camera found: %d\n", found);
}

-(void)ptpCaptureCompleted:(NSString*)imagePath withError:(NSError*)err {
  NSLog(@"We captured an image: %@\n", (err) ? [err localizedDescription] : @"Success!");
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

-(void)handleIntroBegan:(NSNotification*)notification {
  NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
  NSLog(@"Display ready\n");
  [nc removeObserver:self name:QCViewDidStartRenderingNotification object:nil];
  [self startServices];
}

-(void)handleCaptureTimeout:(NSTimer*)t {
  NSLog(@"Capture timed out");
  [self togglePreview:nil];
  timer = nil;
}

-(void)handleIntroTimeout:(NSTimer*)t {
  NSDictionary *info = ([NSBundle mainBundle]).infoDictionary;
  NSString     *val;
  
  if (intro) { //TODO not here
    [intro unloadComposition];
    [intro removeFromSuperview];
    [intro release];
    NSLog(@"Leaving intromode\n");
  }

  if ((val = [info objectForKey:@"FaceAnimation"])) {
    NSString *urlstr = [@"http://127.0.0.1:8881/" stringByAppendingString:val];
    NSLog(@"Loading face: %@\n", urlstr);
    [main.mainFrame loadRequest:
           [NSURLRequest requestWithURL:[NSURL URLWithString:urlstr]]];
  }

  intro = nil;
  timer = nil;
  main.hidden=NO;
  [preview start:kModeSentinel];
}

#pragma mark - WebView Delegate.

- (void)webView:(WebView *)sender didFinishLoadForFrame:(WebFrame *)frame {
}

- (void)webView:(WebView *)sender didFailLoadWithError:(NSError *)error forFrame:(WebFrame *)frame {
  NSLog(@"failed to load frame: %@\n", [error localizedDescription]);
}

- (void)webView:(WebView *)webView didClearWindowObject:(WebScriptObject *)windowScriptObject forFrame:(WebFrame *)frame {
  /*
  Application *app = (Application*)[NSApplication sharedApplication].delegate;
  [windowScriptObject setValue:app.api forKey:@"api"];
  [windowScriptObject setValue:app.console forKey:@"console"];
  */
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
