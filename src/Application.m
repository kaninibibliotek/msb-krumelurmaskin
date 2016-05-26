/********************************************************************************************/
/*                                        krumelur                                          */
/*                                 by Unsworn Industries AB                                 */
/*                            Copyright (c) 2016, Nicklas Marelius                          */
/*                                   All rights reserved.                                   */
/*                                                                                          */
/*      Permission is hereby granted, free of charge, to any person obtaining a copy        */
/*      of this software and associated documentation files (the "Software"), to deal       */
/*      in the Software without restriction, including without limitation the rights        */
/*      to use, copy, modify, merge, publish, distribute, sublicense, and/or sell           */
/*      copies of the Software, and to permit persons to whom the Software is               */
/*      furnished to do so, subject to the following conditions:                            */
/*                                                                                          */
/*      The above copyright notice and this permission notice shall be included in all      */
/*      copies or substantial portions of the Software.                                     */
/*                                                                                          */
/*      THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR          */
/*      IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,            */
/*      FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE         */
/*      AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER              */
/*      LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,       */
/*      OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE       */
/*      SOFTWARE.                                                                           */
/*                                                                                          */
/********************************************************************************************/


#import <WebKit/WebKit.h>
#import "NSURL+NetFS.h"
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
#if FAKE_EVENTS
  {"intro",   kStatusIdle,    kStatusIdle, YES, 0.1},
#else
  {"intro",   kStatusIdle,    kStatusIdle, YES, 5.0},
#endif
  {"idle" ,   kStatusPreview, kStatusIdle, YES, 60.0},
  {"preview", kStatusCapture, kStatusIdle, YES, 30.0},
  {"capture", kStatusProcess, kStatusIdle, YES, 10.0},
  {"process", kStatusPublish, kStatusIdle, YES, 8.0},
  {"publish", kStatusIdle,    kStatusIdle, YES, 10.0}
};

//------------------------------------------------------------------------------------------------------------

@interface Application ()
-(void)nextState:(id)argument;
-(void)gotoState:(unsigned int)state withObject:(id)argument;
-(void)handleTimer:(NSTimer*)timer;
-(void)initState:(unsigned int)state error:(NSError**)err;
-(void)updateState;
-(void)exitState:(unsigned int)current;
-(void)enterState:(unsigned int)next withObject:(id)argument error:(NSError**)err;
-(NSURL*)remountStorageLocation;
@end

//------------------------------------------------------------------------------------------------------------

@implementation Application
@synthesize window, main, preview, camera, imageview, controls, cachesURL, storageURL;

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
    cachesURL=nil;
    storageURL=nil;
  }
  return self;
}

//------------------------------------------------------------------------------------------------------------
#pragma mark - Menu actions..
//------------------------------------------------------------------------------------------------------------

-(void)handleNextState:(id)sender {
  [self nextState:nil];
}

#if FAKE_EVENTS
-(void)fakeMotionEvent:(id)sender {
  [self motionDetected];
}
-(void)fakeButtonEvent:(id)sender {
  [self controlChanged:controls reason:kControlButton];
}
#endif

-(BOOL)validateMenuItem:(NSMenuItem*)item {
  return YES;
}

//------------------------------------------------------------------------------------------------------------
#pragma mark - Application Delegate
//------------------------------------------------------------------------------------------------------------

- (void)applicationWillFinishLaunching:(NSNotification *)aNotification {

  CGRect frame = CGRectMake(0, 0, 1024, 768);
  NSBundle *bundle = [NSBundle mainBundle];
  NSApplication *app = [NSApplication sharedApplication];
  NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
  WebPreferences *prefs = [[WebPreferences alloc] init];
  
  id val, info;
  
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
  [[[main mainFrame] frameView] setAllowsScrolling:NO];
  
  main.UIDelegate = self;
  main.frameLoadDelegate = self;
  main.resourceLoadDelegate = self;

  imageview = [[NSImageView alloc] initWithFrame:frame];
  imageview.wantsLayer = YES;
  imageview.layerContentsRedrawPolicy = NSViewLayerContentsRedrawOnSetNeedsDisplay;
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
  [ms addItemWithTitle:@"Next State" action:@selector(handleNextState:) keyEquivalent:@"n"];

#if FAKE_EVENTS
  [ms addItemWithTitle:@"Fake Motion Event" action:@selector(fakeMotionEvent:) keyEquivalent:@"m"];
  [ms addItemWithTitle:@"Fake Button Button" action:@selector(fakeButtonEvent:) keyEquivalent:@"c"];
#endif
  
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
  NSURL         *url;
  NSError       *err;
  NSFileManager *fm     = [NSFileManager defaultManager];
  NSBundle      *bundle = [NSBundle mainBundle];
  NSArray       *array;
  // deal with locations..
  do {
    if (!(url = [fm URLForDirectory:NSCachesDirectory inDomain:NSUserDomainMask appropriateForURL:nil create:YES error:&err])) {
      if (err) NSLog(@"%@", err.localizedDescription);
      NSLog(@"Could not get url for NSCachesDirectory");
      break ;
    }
    url = [url URLByAppendingPathComponent:[bundle bundleIdentifier]];
    if (![fm createDirectoryAtURL:url withIntermediateDirectories:YES attributes:nil error:&err]) {
      if (err) NSLog(@"%@", err.localizedDescription);
      NSLog(@"Failed to create caches directory at %@ falling back to /tmp", [url absoluteString]);
      break;
    }
    cachesURL = url;
  } while(NO);
  
  if (!cachesURL) {
    NSLog(@"Application cache directory not available. falling back to /tmp");
    cachesURL = [NSURL fileURLWithPath:@"/tmp" isDirectory:YES];
  }

  storageURL = [self remountStorageLocation];

  NSLog(@"Cache Location: %@", cachesURL.absoluteString);
  NSLog(@"Storage Location: %@", storageURL.absoluteString);

  camera.downloadDirectory = self.cachesURL;

  NSLog(@"Cleaning cachedir");

  if ((array = [fm contentsOfDirectoryAtPath:cachesURL.path error:nil])) {
    for (NSString *fn in array) {
      if (![fn hasPrefix:@"DSC"] || ![fn hasSuffix:@".JPG"])
        continue ;
      fn = [cachesURL.path stringByAppendingPathComponent:fn];
      NSLog(@"Removing %@", fn);
      [fm removeItemAtPath:fn error:nil];
    }
  }
  
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
//------------------------------------------------------------------------------------------------------------
#pragma mark - ssm
//------------------------------------------------------------------------------------------------------------

-(void)nextState:(id)argument {
  [self gotoState:sm[status].next withObject:argument];
}

-(void)gotoState:(unsigned int)next withObject:argument{
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
    [self enterState:next withObject:argument error:&err];

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
  [self gotoState:sm[status].timeout withObject:nil];
}

-(void)initState:(unsigned int)state error:(NSError**)err {
  NSDictionary *info = ([NSBundle mainBundle]).infoDictionary;
  NSString     *val, *url;
  NSArray      *animations;
  static int    count=0;
  switch(state) {
   case kStatusIdle:
     if (!(animations = [info objectForKey:@"FaceAnimation"])) {
       if (err) *err = ERROR(1, "No animation file specified in info plist");
       break ;
     }
     val = [animations objectAtIndex:count%[animations count]];
     count++;
     url = [@"http://127.0.0.1:8881/" stringByAppendingString:val];
     [main.mainFrame loadRequest:[NSURLRequest requestWithURL:[NSURL URLWithString:url]]];
     main.hidden = NO;
     break;
   case kStatusPreview:
     if (![preview attached]) {
       if (err) *err = ERROR(1, "No Video camera attached");
       break;
     }
   case kStatusCapture:
     if (![camera attached]) {
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
     if (controls)
       [controls release];
     controls = nil;
     preview.hidden = YES;
     [preview stop];
     break;
   case kStatusPublish:
     imageview.image = nil;
     imageview.hidden = YES;
     break;
  }
}

-(void)enterState:(unsigned int)next withObject:(id)argument error:(NSError**)err {

  dispatch_queue_t queue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_LOW, 0L);
  
  switch(next) {
   case kStatusIdle:
     if (status == kStatusIdle) {
       [self initState:kStatusIdle error:err];
       break ;
     }
     main.hidden = NO;
     [preview start:kModeSentinel];
     break;
   case kStatusPreview:
     [preview start:kModePreview];
     preview.hidden = NO;
     controls = [Controls controlsWithTarget:self];
     break ;
   case kStatusCapture:
     [camera capture];
     break;
   case kStatusProcess:
     dispatch_async(queue, ^{
         [self process:argument];
       });
     break ;
   case kStatusPublish:
     imageview.hidden = NO;
     dispatch_async(queue, ^{
         [self publish:argument];
       });
     break;
  }
  
}

-(void)storageLocationChanged:(NSNotification*)notification {
  NSLog(@"Volume changed! %@", notification.name);
}

-(NSURL*)remountStorageLocation {
  NSDictionary *info;
  NSURL        *url, *tmp = [NSURL fileURLWithPath:@"/tmp" isDirectory:YES];
  NSNotificationCenter *nsc = [[NSWorkspace sharedWorkspace] notificationCenter];
  NSString *val, *path=nil;
  NSError *error=nil;
  
  [nsc removeObserver:self];
  
  if (!(info = [[NSBundle mainBundle].infoDictionary objectForKey:@"StorageLocation"])) {
    NSLog(@"StorageLocation not specified in infoplist, falling back to /tmp");
    return tmp;
  }
  if (!(val = [info objectForKey:@"url"])) {
    NSLog(@"StorageLocation does not specify a valid url, falling back to /tmp");
    return tmp;
  }

  url = [NSURL URLWithString:val];
  
  if ([url.scheme isEqualToString:@"file"])
    return url;

  [nsc addObserver:self selector: @selector(storageLocationChanged:) name:NSWorkspaceDidMountNotification object: nil];
  [nsc addObserver:self selector: @selector(storageLocationChanged:) name:NSWorkspaceDidUnmountNotification object:nil];

  [url mount:info path:&path error:&error];

  if (!path) {
    if (error) NSLog(@"%@", error.localizedDescription);
    NSLog(@"Failed to mount volume: %@ ", url.absoluteString);
    return nil;
  }
  return [NSURL fileURLWithPath:path isDirectory:YES];
}

- (void)process:(NSString*)imagePath {
  NSDictionary   *calibration = [[NSBundle mainBundle].infoDictionary objectForKey:@"Calibration"];
  ImageProcessor *imgprc      = [[ImageProcessor alloc] init];
  NSError        *err         = nil;
  NSLog(@"Process: %@", imagePath);
  if (!imagePath) {
    NSLog(@"Invalid file path for process!");
    return ; // let state timeout
  }
  imgprc.settings = [calibration objectForKey:@"Process"];
  [imgprc applyToPath:imagePath error:&err];
  if (err) {
    NSLog(@"Processing failed for %@", imagePath);
  }
  [imgprc release];
  [self nextState:imagePath];
}

- (void)publish:(NSString*)imagePath {
  PyObject *rval, *args;
  NSLog(@"Publish: %@", imagePath);

  NSImage *image = [[NSImage alloc] initWithContentsOfFile:imagePath];

  imageview.image = [image autorelease];
  imageview.hidden = NO;
  [self animate];

}

- (void)animate {
  NSRect r = view.frame;

  imageview.frame = r; // reset position..

  r.origin.x += 100;
  r.origin.y += 100;
  r.size.width /= 8;
  r.size.height /= 8;

  [NSAnimationContext runAnimationGroup:^(NSAnimationContext *context) {
      context.duration = 5.f;
      imageview.animator.frame = r;
    } completionHandler:^(void) {
      NSLog(@"Animation done");
      [self nextState:nil];
    }];  
}


//------------------------------------------------------------------------------------------------------------
#pragma mark - PreViewDelgate
//------------------------------------------------------------------------------------------------------------

-(void)usbDeviceFound:(BOOL)found {
  NSLog(@"USB Video camera found: %d\n", found);
}

-(void)motionDetected {
  NSLog(@"Motion Detect!");
  [self nextState:nil];
}

//------------------------------------------------------------------------------------------------------------
#pragma mark - ControlDelgate
//------------------------------------------------------------------------------------------------------------

-(void)controlChanged:(id)sender reason:(int)rs {
  if (rs == kControlConnected && controls.ready) {
    NSLog(@"Controller ready");
    [controls brightness:250];
    return ;
  }
  if (rs == kControlBrightness) {
    NSLog(@"Brightness changed: %d", controls.value);
    return ;
  }
  if (rs == kControlButton && status == kStatusPreview && (controls == nil || controls.state)) {
    [self nextState:nil];
  }
}

//------------------------------------------------------------------------------------------------------------
#pragma mark - PTPCameraDelegate
//------------------------------------------------------------------------------------------------------------

-(void)ptpCameraFound:(BOOL)found {
  NSLog(@"SLR usb camera found: %d\n", found);
}

-(void)ptpCaptureCompleted:(NSString*)path withError:(NSError*)err {
  NSError *perr=nil;

  if (err) {
    NSLog(@"ptpCameraCapture: %@", [err localizedDescription]);
    return ; // return and let state timeout
  }
  
  NSLog(@"We captured an image: %@\n", path);
  NSLog(@"Camera status: %d\n", self.camera.status);

  [self nextState:path];

}

//------------------------------------------------------------------------------------------------------------
#pragma mark - WebView Delegate.
//------------------------------------------------------------------------------------------------------------

- (void)webView:(WebView *)sender didFinishLoadForFrame:(WebFrame *)webFrame {
  NSDictionary *info = [NSBundle mainBundle].infoDictionary;
  double z = ([info objectForKey:@"WebViewScale"]) ? [[info objectForKey:@"WebViewScale"] doubleValue] : 1.0;
  [main stringByEvaluatingJavaScriptFromString:
                    [NSString stringWithFormat:@"document.documentElement.style.zoom = \"%f\"", z]];

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
