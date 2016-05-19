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

#ifndef Controls_H_
#define Controls_H_

#import <Cocoa/Cocoa.h>

enum {
  kControlInvalid,
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
  dispatch_queue_t          ioqueue;  
}

@property (nonatomic, readonly) BOOL ready;
@property (nonatomic, readonly) BOOL state;
@property (nonatomic, readonly) int  value;

@property (nonatomic, retain) NSObject<ControlDelegate> *delegate;

+(Controls*)controlsWithTarget:(NSObject<ControlDelegate>*)target;
-(void)brightness:(int)b;
-(void)button;
-(void)close;
@end

#endif /* Serial_H_ */
