#import <WebKit/WebKit.h>
#import "Application.h"
#import "Runtime.h"

@interface Application ()
-(void)startServices;
-(void)stopServices;
@end

@implementation Application
@synthesize window, main, preview, camera;

- (id) init {
  if (self = [super init]) {
    window = nil;
    main = nil;
    preview = nil;
    camera = nil;
    timer = nil;
  }
  return self;
}

#pragma mark - Menu actions..

-(void)togglePreview:(id)sender {
  if ([preview running]) {
    main.hidden=NO;
    [preview stop];
    preview.hidden=YES;
  } else {
    main.hidden=YES;
    [preview start];
    preview.hidden=NO;    
  }
      
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

  if ((val = [info objectForKey:@"FaceAnimation"])) {
    [main.mainFrame loadRequest: [NSURLRequest requestWithURL:
      [NSURL URLWithString:[bundle pathForResource:
         [@"html" stringByAppendingPathComponent:val] ofType:@"html"]]]];
  }
  [view addSubview:main];
  [view addSubview:preview];

  main.hidden = YES;
  preview.hidden = YES;
  
  [view addSubview:intro];

  [window makeKeyAndOrderFront:nil];

  [window center];
}

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification {
  [[NSApplication sharedApplication] activateIgnoringOtherApps:YES];
  timer = [NSTimer timerWithTimeInterval:0.5
    target:self selector:@selector(handleIntroTimedOut:)
    userInfo:nil repeats:NO];

  [[NSRunLoop currentRunLoop] addTimer:timer forMode:NSDefaultRunLoopMode];
}

- (void)applicationWillTerminate:(NSNotification *)aNotification {
  if (timer) {
    [timer invalidate];
    [self handleIntroTimedOut:nil];
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

-(void)ptpCameraFound:(BOOL)found {
  NSLog(@"SLR usb camera found: %d\n", found);
}

-(void)handleIntroBegan:(NSNotification*)notification {
  NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
  NSLog(@"Display ready\n");
  [nc removeObserver:self name:QCViewDidStartRenderingNotification object:nil];
  [self startServices];
}

-(void)handleIntroTimedOut:(NSTimer*)t {
if (intro) { //TODO not here
    [intro unloadComposition];
    [intro removeFromSuperview];
    [intro release];
    NSLog(@"Leaving intromode\n");
  }  
  intro = nil;
  timer = nil;
  main.hidden=NO;
  if (!t) return ;
  NSLog(@"Could not initialize services\n");
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
