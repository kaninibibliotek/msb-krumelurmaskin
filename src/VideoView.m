#import <Foundation/Foundation.h>
#import "VideoView.h"
#import "Application.h"
#import "Runtime.h"
#include <unistd.h>

//------------------------------------------------------------------------------------------------------------

#define VIDEO_SEEK_TIMESCALE 6000

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
    asset=nil;
    player=nil;
    playerlayer=nil;
    playeritem=nil;
    loops = [[NSMutableArray alloc] init];
    self.wantsLayer = YES;
    self.layer = [self makeBackingLayer];

    self.player = [[AVPlayer alloc] init];
    self.layer.backgroundColor = CGColorGetConstantColor(kCGColorWhite);
    self.player.muted  = NO;
    self.player.volume = 1.0;

    self.autoresizingMask = NSViewHeightSizable|NSViewWidthSizable;

    [self addObserver:self
     forKeyPath:@"player.rate"
     options:NSKeyValueObservingOptionNew
     context:VideoViewPlayerRateContext];

    [self addObserver:self
     forKeyPath:@"player.currentItem.status"
     options:NSKeyValueObservingOptionNew
     context:VideoViewPlayerItemStatusContext];

  }
  return self;
}

- (void) dealloc
{
  [loops release];
  if (self.playerlayer)
    [self closeMedia];
  if (player)
    [player release];
  [super dealloc];
}

- (BOOL) openMedia:(NSString*)mpath
{
  NSError* err=nil;
  
  [loops removeAllObjects];

  NSURL* url = [NSURL fileURLWithPath:mpath isDirectory: NO];
  NSDictionary* options = [NSDictionary
                           dictionaryWithObject: [NSNumber numberWithBool:YES]
                           forKey: AVURLAssetPreferPreciseDurationAndTimingKey ];
  AVURLAsset* asset_ = [AVURLAsset URLAssetWithURL:url options:options];
  NSArray* testkeys = @[@"playable", @"hasProtectedContent", @"tracks"];
  [asset_ loadValuesAsynchronouslyForKeys: testkeys completionHandler:^(void) {
    dispatch_async(dispatch_get_main_queue(), ^(void) {
      [self setup: asset_ forkeys:testkeys];
    });
  }];
  NSLog(@"VideoView: opened(%@)\n", mpath);
  return YES;
}

-(int)addLoopAt:(double)start to:(double)end {
  [loops addObject:@[
    [NSNumber numberWithDouble:start], 
    [NSNumber numberWithDouble:end]]];
  return [loops count] - 1;
}

- (void)play:(int)loopIndex {
  if (!asset) {
    NSLog(@"Can not play, no asset loaded\n");
    return ;
  }
  
  NSArray* loop = [loops objectAtIndex:loopIndex];
  CMTimeRange range = CMTimeRangeMake(
    CMTimeMakeWithSeconds(((NSNumber*)[loop objectAtIndex:0]).doubleValue, asset.duration.timescale),
    CMTimeMakeWithSeconds(((NSNumber*)[loop objectAtIndex:1]).doubleValue, asset.duration.timescale));
  CMTimeRangeShow(range);
  AVMutableComposition *comp = [[[AVMutableComposition alloc] init] autorelease];
  [comp insertTimeRange:range ofAsset:asset atTime:comp.duration error:nil];

  playeritem = [AVPlayerItem playerItemWithAsset:comp];

  [[NSNotificationCenter defaultCenter] addObserver:self
    selector:@selector (videoPlayerItemDidReachEnd:)
    name:AVPlayerItemDidPlayToEndTimeNotification
    object:playeritem];

  [player replaceCurrentItemWithPlayerItem:playeritem];
  
  [player play];
}

- (void) closeMedia
{
  if (asset) [asset release];

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

- (void) setup:(AVAsset*) asset_ forkeys:(NSArray*)keys
{
  NSArray* tracks=nil;
  if (asset) [asset release];
  asset=nil;

  for (NSString* key in keys) {
    NSError* err=nil;
    if ([asset_ statusOfValueForKey:key error:&err] == AVKeyValueStatusFailed) {
      [self abort:err];
      NSLog(@"Video: setup failed - status for key: %@\n", key);
      return ;
    }
  }

  if (![asset_ isPlayable]) {
    [self abort:nil];
    NSLog(@"Video: setup failed - source is not playable\n");
    return ;
  }

  if ([[asset_ tracksWithMediaType:AVMediaTypeVideo] count] == 0) {
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

  asset = [asset_ retain];

  NSLog(@"All shook up\n");

}

- (void) abort:(NSError*) err
{
  NSLog(@"Abort requested due to: %@\n", (err) ? [err localizedDescription] : @"Unknown Reason");
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
      // success [self prerollAndPresent];
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

-(void)videoPlayerItemDidReachEnd:(NSNotification*)notification {
  NSLog(@"We are at the loops end\n");
  if (!playeritem) return ;
  [playeritem seekToTime:kCMTimeZero];
  [player play];
}

@end

