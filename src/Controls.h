#ifndef Controls_H_
#define Controls_H_

#import <Cocoa/Cocoa.h>

enum {
  kControlNull,
  kControlConnected,
  kControlButton,
  kControlBrightness
};

@protocol ControlDelegate <NSObject>
-(void)controlChanged:(id)sender reason:(int)reason;
@end

@interface Controls : NSObject {
  int                       fd;
  BOOL                      ready;
  BOOL                      state;
  int                       value;
  NSObject<ControlDelegate> *delegate;
}

@property (nonatomic, readonly) BOOL ready;
@property (nonatomic, readonly) BOOL state;
@property (nonatomic, readonly) int  value;

@property (nonatomic, retain) NSObject<ControlDelegate> *delegate;

+(Controls*)controlsWithTarget:(NSObject<ControlDelegate>*)target;
-(void)brightness:(int)b;
-(void)button;
@end

#endif /* Serial_H_ */
