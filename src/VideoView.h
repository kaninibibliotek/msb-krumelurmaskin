#import <Foundation/Foundation.h>
#import <Cocoa/Cocoa.h>
#import <AVFoundation/AVFoundation.h>
#import <CoreMedia/CoreMedia.h>

@interface VideoView : NSView
{
    AVPlayer*             player;
    AVPlayerLayer*        playerlayer;
    AVPlayerItem*         playeritem;
}

- (BOOL)      queryMedia:(NSString*)path query:(NSMutableDictionary*)query;
- (BOOL)      openMedia:(NSString*)path;
- (void)      closeMedia;
- (double)    nominalFramerate;
- (double)    duration;

@end
