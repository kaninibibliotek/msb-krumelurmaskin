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

#import <Cocoa/Cocoa.h>
#import <AVFoundation/AVFoundation.h>
#import "ImageProcessor.h"

typedef enum {
  kModePreview,
  kModeSentinel
} PreviewMode;

@protocol PreViewDelegate <NSObject>
-(void)usbDeviceFound:(BOOL)found;
-(void)motionDetected;
@end

@interface PreView : NSView<AVCaptureVideoDataOutputSampleBufferDelegate> {
  AVCaptureSession           *captureSession;
  AVCaptureDevice            *device;
  ImageProcessor             *imgprc;
  NSImageView                *imageView;
  NSString                   *target;
  id<PreViewDelegate>        delegate;
  PreviewMode                mode;
  int                        senc;
}

@property (nonatomic, retain) NSString            *target;
@property (nonatomic, readonly) AVCaptureDevice   *device;
@property (nonatomic, retain) id<PreViewDelegate> delegate;
@property (nonatomic, readonly) PreviewMode       mode;

-(void)connect;
-(void)shutdown;
-(void)start:(PreviewMode)mode;
-(void)stop;
-(BOOL)running;
-(void)switchMode:(PreviewMode)mode;

@end
