#import <Foundation/Foundation.h>
#import "VideoView.h"
#import "Application.h"
#import "Runtime.h"
#include <unistd.h>

//------------------------------------------------------------------------------------------------------------

#define VIDEO_SEEK_TIMESCALE 6000

//------------------------------------------------------------------------------------------------------------

void video_register_module();

//------------------------------------------------------------------------------------------------------------

static void* VideoViewPlayerRateContext       = &VideoViewPlayerRateContext;
static void* VideoViewPlayerItemStatusContext = &VideoViewPlayerItemStatusContext;
static void* VideoViewLayerReadyForDisplay    = &VideoViewLayerReadyForDisplay;

@interface VideoView ()
@property (strong)   AVPlayer*             player;
@property (strong)   AVPlayerLayer*        playerlayer;
@property (strong)   AVPlayerItem*         playeritem;
@end

@implementation VideoView
@synthesize player, playerlayer,playeritem;
- (id) initWithFrame:(NSRect)r
{
  if (self = [super initWithFrame:r]) {

    player=nil;
    playerlayer=nil;
    playeritem=nil;
    
    self.wantsLayer = YES;
    self.layer = [self makeBackingLayer];

    self.player = [[AVPlayer alloc] init];
    self.layer.backgroundColor = CGColorGetConstantColor(kCGColorBlack);
    self.player.muted  = NO;
    self.player.volume = 1.0;

    [self addObserver:self
     forKeyPath:@"player.rate"
     options:NSKeyValueObservingOptionNew
     context:VideoViewPlayerRateContext];

    [self addObserver:self
     forKeyPath:@"player.currentItem.status"
     options:NSKeyValueObservingOptionNew
     context:VideoViewPlayerItemStatusContext];

  }

  video_register_module();

  return self;
}

- (void) dealloc
{
  if (self.playerlayer)
    [self closeMedia];
  if (self.player)
    [self.player release];
  [super dealloc];
}

- (BOOL) openMedia:(NSString*)mpath
{
  NSError* err=nil;

  NSURL* url = [NSURL fileURLWithPath:mpath isDirectory: NO];
  NSDictionary* options = [NSDictionary
                           dictionaryWithObject: [NSNumber numberWithBool:YES]
                           forKey: AVURLAssetPreferPreciseDurationAndTimingKey ];
  AVURLAsset* asset = [AVURLAsset URLAssetWithURL:url options:options];
  NSArray* testkeys = @[@"playable", @"hasProtectedContent", @"tracks"];
  [asset loadValuesAsynchronouslyForKeys: testkeys completionHandler:^(void) {
    dispatch_async(dispatch_get_main_queue(), ^(void) {
      [self setup: asset forkeys:testkeys];
    });
  }];
  NSLog(@"VideoView: opened(%@)\n", mpath);
  return YES;
}

- (void) closeMedia
{
  AVPlayerLayer* tmp=self.playerlayer;

  [self.player pause];

  if (tmp)
    [self removeObserver:self forKeyPath:@"playerlayer.readyForDisplay"];

  self.playerlayer = nil;

  [tmp release];
}

- (double) nominalFramerate
{
  do {
    if (self.player == nil)
      break;
    if (self.player.currentItem == nil)
      break;
    if (self.player.currentItem.asset == nil)
      break;

    for (AVAssetTrack* track in [self.player.currentItem.asset tracksWithMediaType:AVMediaTypeVideo]) {
      return track.nominalFrameRate;
    }
  } while (0);
  return -1;
}

- (double) duration
{
  do {
    if (self.player == nil)
      break;
    if (self.player.currentItem == nil)
      break;
    if (self.player.currentItem.asset == nil)
      break;
    return CMTimeGetSeconds( self.player.currentItem.asset.duration );
  } while(0);
  return 0;
}

- (void) setup:(AVAsset*) asset forkeys:(NSArray*)keys
{
  NSArray* tracks=nil;

  for (NSString* key in keys) {
    NSError* err=nil;
    if ([asset statusOfValueForKey:key error:&err] == AVKeyValueStatusFailed) {
      [self abort:err];
      NSLog(@"Video: setup failed - status for key: %@\n", key);
      return ;
    }
  }

  if (![asset isPlayable]) {
    [self abort:nil];
    NSLog(@"Video: setup failed - source is not playable\n");
    return ;
  }

  if ([[asset tracksWithMediaType:AVMediaTypeVideo] count] == 0) {
    [self abort:nil];
    NSLog(@"Video: setup failed - source does not contain a video track\n");
    return ;
  }

  AVPlayerLayer* newlayer = [AVPlayerLayer playerLayerWithPlayer:self.player];

  if (!newlayer) {
    [self abort:nil];
    NSLog(@"Video: setup failed - out of memory\n");
    return ;
  }

  newlayer.frame = self.layer.bounds;
  newlayer.autoresizingMask = kCALayerWidthSizable | kCALayerHeightSizable;
  newlayer.hidden = YES;
  [self.layer addSublayer:newlayer];

  self.playerlayer = [newlayer retain];

  [self addObserver:self
   forKeyPath:@"playerlayer.readyForDisplay"
   options:NSKeyValueObservingOptionInitial | NSKeyValueObservingOptionNew
   context:VideoViewLayerReadyForDisplay];

  playeritem = [AVPlayerItem playerItemWithAsset:asset];

  [self.player replaceCurrentItemWithPlayerItem:playeritem];

  NSLog(@"Video: setup completed.. continuing with audio setup\n");

  tracks = [asset tracksWithMediaType:AVMediaTypeAudio];

}

- (void) abort:(NSError*) err
{
  NSLog(@"Abort requested due to: %@\n", (err) ? [err localizedDescription] : @"Unknown Reason");
}

- (void) prerollAndPresent
{
  if (!self.player) return ;

  [self.player prerollAtRate:1.0 completionHandler:^(BOOL done) {
    if (!done) return ;
    NSLog(@"Video primed and ready");
  }];
}

- (void) observeValueForKeyPath:(NSString*)keyPath ofObject:(id)obj change:(NSDictionary*)change context:(void*)context
{

  NSLog(@"Observer responed: %@\n", keyPath);

  if (context == VideoViewPlayerItemStatusContext) {
    AVPlayerStatus status = [change[NSKeyValueChangeNewKey] integerValue];
    switch(status) {
    case AVPlayerItemStatusUnknown:
      break;
    case AVPlayerItemStatusReadyToPlay:
      [self prerollAndPresent];
      break;
    case AVPlayerItemStatusFailed:
      [self abort:nil];
      break;
    }

  } else if (context == VideoViewPlayerRateContext) {
    //[change[NSKeyValueChangeNewKey] floatValue];
  } else if (context == VideoViewLayerReadyForDisplay) {
    if ([change[NSKeyValueChangeNewKey] boolValue] == YES) {
      self.playerlayer.hidden = NO;
    }
  } else {
    [super observeValueForKeyPath:keyPath ofObject:obj change:change context:context];
  }
}

- (BOOL) queryMedia:(NSString*)path query:(NSMutableDictionary*)query
{
  NSURL*        url   = [NSURL fileURLWithPath:path isDirectory: NO];
  AVURLAsset*   asset = [AVURLAsset URLAssetWithURL:url options:nil];
  BOOL          hasVideo = NO, hasAudio = NO;
  NSArray*      videoTracks;
  NSArray*      audioTracks;

  NSLog(@"queryMedia(%@) started\n", path);

  videoTracks = [asset tracksWithMediaType:AVMediaTypeVideo];
  audioTracks = [asset tracksWithMediaType:AVMediaTypeAudio];

  [query setObject:[NSNumber numberWithBool:asset.playable] forKey:@"playable"];
  [query setObject:[NSNumber numberWithBool:asset.hasProtectedContent] forKey:@"protected"];

  for (AVAssetTrack* track in videoTracks) {
    if (!track.playable)
      continue ;
    [query setObject:[NSNumber numberWithDouble:track.nominalFrameRate] forKey:@"framerate"];
    hasVideo = YES;
    break ;
  }

  for (AVAssetTrack* track in audioTracks) {
    if (!track.playable)
      continue;
    [query setObject:[NSNumber numberWithDouble:track.nominalFrameRate] forKey:@"samplerate"];
    hasAudio = YES;
    break;
  }

  [query setObject:[NSNumber numberWithDouble:CMTimeGetSeconds(asset.duration)] forKey:@"duration"];
  [query setObject:[NSNumber numberWithBool:hasVideo] forKey:@"video"];
  [query setObject:[NSNumber numberWithBool:hasAudio] forKey:@"audio"];

  NSLog(@"queryMedia() done\n");

  [asset cancelLoading];

  return hasVideo;
}

@end

//------------------------------------------------------------------------------------------------------------

#define _self ((Application*)[NSApplication sharedApplication].delegate).videoView

PyObject*
video_open_media(PyObject* self, PyObject* args)
{
  PyObject *path=0;
  do {
    if (!PyArg_ParseTuple(args, "O", &path))
      break;
    if (![_self openMedia:[NSString stringWithPyString:path]])
      break;
    Py_RETURN_TRUE;
  } while (0);
  Py_RETURN_FALSE;
}

PyObject*
video_close_media(PyObject* self, PyObject* args)
{
  [_self closeMedia];
  Py_RETURN_NONE;
}

PyObject*
video_query_media(PyObject* self, PyObject* args)
{
  BOOL      result=NO;
  PyObject* path;
  PyObject* d = PyDict_New();
  NSMutableDictionary* q = [NSMutableDictionary dictionary];
  do {

    if (!PyArg_ParseTuple(args, "O", &path))
      break;

    result = [_self queryMedia:[NSString stringWithPyString:path] query:q];

    PyDict_SetItemString(d, "source", path);

    for (NSString* key in [q allKeys]) {
      PyDict_SetItem(d,
                     Py_BuildValue("s", [key UTF8String]),
                     Py_BuildValue("f", [((NSNumber*)[q objectForKey:key]) doubleValue]));

    }

  } while(0);

  PyDict_SetItemString(d, "success", Py_BuildValue("i", result));

  return d;
}

PyObject*
video_media_loaded(PyObject* self, PyObject* args)
{
  do {
    if (_self.playerlayer == nil)
      break;
    Py_RETURN_TRUE;
  } while(0);
  Py_RETURN_FALSE;
}

PyObject*
video_media_ready(PyObject* self, PyObject* args)
{
  do {
    if (_self.playerlayer == nil)
      break;
    if (_self.playerlayer.hidden)
      break;
    Py_RETURN_TRUE;
  } while(0);
  Py_RETURN_FALSE;
}

PyObject*
video_seek_time(PyObject* self, PyObject* args)
{
  double seconds=0;
  CFAbsoluteTime tb=0;
  do {
    if (!PyArg_ParseTuple(args, "d", &seconds))
      break;
    tb = CFAbsoluteTimeGetCurrent();
    [_self.player
     seekToTime:CMTimeMakeWithSeconds(seconds, VIDEO_SEEK_TIMESCALE)
     toleranceBefore:kCMTimeZero
     toleranceAfter:kCMTimeZero
    completionHandler:^(BOOL done) {
      if (!done) return ;
      CFTimeInterval si = CFAbsoluteTimeGetCurrent() - tb;
      NSLog(@"Seek completed! d:%f\n", si);
    }];

  } while(0);
  Py_RETURN_NONE;
}

PyObject*
video_tell_time(PyObject* self, PyObject* args)
{
  return Py_BuildValue("f", CMTimeGetSeconds( _self.player.currentTime ));
}

PyObject*
video_seek_frame(PyObject* self, PyObject* args)
{
  long frame=0;
  double fps=0;
  do {
    if (!PyArg_ParseTuple(args, "l", &frame))
      break;
    fps = [_self nominalFramerate];
    if (fps <= 0)
      break;
    [_self.player
     seekToTime:CMTimeMakeWithSeconds((double)frame/fps, VIDEO_SEEK_TIMESCALE)
     toleranceBefore:kCMTimeZero
     toleranceAfter:kCMTimeZero];

  } while(0);
  Py_RETURN_NONE;
}

PyObject*
video_tell_frame(PyObject* self, PyObject* args)
{
  double fps=0;
  do {
    fps = [_self nominalFramerate];
    if (fps <= 0)
      break;
    return Py_BuildValue("l", (long)(CMTimeGetSeconds( _self.player.currentTime ) * fps));
  } while(0);
  Py_RETURN_NONE;
}

PyObject*
video_get_framerate(PyObject* self, PyObject* args)
{
  return Py_BuildValue("f", [_self nominalFramerate]);
}

PyObject*
video_get_duration(PyObject* self, PyObject* args)
{
  return Py_BuildValue("f", [_self duration]);
}

PyObject*
video_start_playback(PyObject* self, PyObject* args)
{
  do {
    if (_self.playerlayer == nil)
      break ;
    if (_self.playerlayer.hidden)
      break;
    //[_self playheadToTimeline:YES];
  } while(0);
  Py_RETURN_NONE;
}

PyObject*
video_stop_playback(PyObject* self, PyObject* args)
{
  do {
    [_self.player pause];
  } while(0);
  Py_RETURN_NONE;
}

static PyMethodDef video_def[] = {
  {"openMedia",    video_open_media, METH_VARARGS, ""},
  {"closeMedia",   video_close_media, METH_VARARGS, ""},
  {"queryMedia",   video_query_media, METH_VARARGS, ""},
  {"mediaLoaded",  video_media_loaded, METH_VARARGS, ""},
  {"mediaReady",   video_media_ready, METH_VARARGS, ""},
  {"seek",         video_seek_time, METH_VARARGS, ""},
  {"tell",         video_tell_time, METH_VARARGS, ""},
  {"gotoFrame",    video_seek_frame, METH_VARARGS, ""},
  {"atFrame",      video_tell_frame, METH_VARARGS, ""},
  {"framerate",    video_get_framerate, METH_VARARGS, ""},
  {"duration",     video_get_duration, METH_VARARGS, ""},
  {"play",         video_start_playback, METH_VARARGS, ""},
  {"stop",         video_stop_playback, METH_VARARGS, ""},
  {NULL, NULL, 0, NULL}
};

void
video_register_module()
{
  static bool initialized_=false;
  if (initialized_)
    return ;
  [[Runtime sharedRuntime] register:@"video" interface:video_def];
  initialized_=true;
}
