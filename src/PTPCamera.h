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

#ifndef PTPCamera_H_
#define PTPCamera_H_

#import <Cocoa/Cocoa.h>
#import <ImageCaptureCore/ImageCaptureCore.h>

@protocol PTPCameraDelegate <NSObject>
-(void)ptpCameraFound:(BOOL)found;
-(void)ptpCaptureCompleted:(NSString*)imagePath withError:(NSError*)err;
@end

@interface PTPCamera : NSObject<ICDeviceBrowserDelegate, ICCameraDeviceDelegate, ICCameraDeviceDownloadDelegate> {
  NSString               *target;
  ICDeviceBrowser        *deviceBrowser;
  id <PTPCameraDelegate> delegate;
  ICCameraDevice         *device;
  NSTimer                *timer;
  unsigned int           status;
  ICCameraItem           *curitem;
}

@property (nonatomic, retain)   NSString              *target;
@property (nonatomic, retain)   id<PTPCameraDelegate> delegate;
@property (nonatomic, readonly) ICCameraDevice        *device;
@property (nonatomic, readonly) unsigned int          status;

-(void)connect;
-(void)capture;
-(void)shutdown;

@end

#endif
