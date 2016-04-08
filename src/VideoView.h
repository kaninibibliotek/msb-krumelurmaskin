#import <Foundation/Foundation.h>
#import <Cocoa/Cocoa.h>
#import <AVFoundation/AVFoundation.h>
#import <CoreMedia/CoreMedia.h>

@protocol ViewViewDelegate <NSObject>
-(void)videoLoaded:(BOOL)ready;
@end

@interface VideoView : NSView
{
  AVAsset               *asset;
  AVPlayer              *player;
  AVPlayerLayer         *playerlayer;
  AVPlayerItem          *playeritem;
  NSMutableArray        *loops;
}

- (BOOL)      openMedia:(NSString*)path;
- (int)       addLoopAt:(double)start to:(double)end;
- (void)      play:(int)loop;
- (void)      closeMedia;
- (double)    nominalFramerate;
- (double)    duration;

@end
