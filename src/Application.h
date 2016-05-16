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
#import <WebKit/WebKit.h>
#import <Quartz/Quartz.h>
#import <WebKit/WebKit.h>

#import "VideoView.h"
#import "PreView.h"
#import "PTPCamera.h"
#import "Controls.h"

#define app_ ((Application*)[NSApplication sharedApplication].delegate)
  
@interface Application : NSObject <NSApplicationDelegate, NSWindowDelegate, PreViewDelegate, PTPCameraDelegate, ControlDelegate> {
  NSWindow     *window;
  WebView      *main;
  PreView      *preview;
  PTPCamera    *camera;
  QCView       *intro;
  NSView       *view;
  NSTimer      *timer;
  NSImageView  *imageview;
  Controls     *controls;
  unsigned int status;
  double       stime;
}

@property (nonatomic, retain) NSWindow    *window;
@property (nonatomic, retain) WebView     *main;
@property (nonatomic, retain) PreView     *preview;
@property (nonatomic, retain) PTPCamera   *camera;
@property (nonatomic, retain) NSImageView *imageview;
@property (nonatomic, retain) Controls    *controls;

@end
