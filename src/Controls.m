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

#include <stdio.h>
#include <string.h>
#include <unistd.h>
#include <fcntl.h>
#include <sys/ioctl.h>
#include <errno.h>
#include <paths.h>
#include <termios.h>
#include <sysexits.h>
#include <sys/param.h>
#include <sys/select.h>
#include <sys/time.h>
#include <time.h>
 
#include <CoreFoundation/CoreFoundation.h>
 
#include <IOKit/IOKitLib.h>
#include <IOKit/serial/IOSerialKeys.h>
#include <IOKit/serial/ioss.h>
#include <IOKit/IOBSD.h>

#import "Controls.h"

@interface Controls ()
+(NSString*)find;
-(BOOL)open:(NSString*)device;
-(void)close;
-(void)ioCallback:(NSThread*)parent;
@end

@implementation Controls
@synthesize ready, state, value, delegate;

- (id) init {
  if (self = [super init]) {
    fd = 0;
    ready = NO;
    state = NO;
    value = 0;
    delegate=nil;
  }
  return self;
}

-(void)dealloc {
  [self close];
  [super dealloc];
}

+(Controls*)controlsWithTarget:(NSObject<ControlDelegate>*)target {
  NSString *path;
  Controls *c=nil;
  do {
    if (!(path = [Controls find])) {
      NSLog(@"No serial port found");
      break ;
    }
    c = [[Controls alloc] init];
    if (![c open:path]) {
      NSLog(@"Failed to open port: %@", path);
      break ;
    }
    c.delegate = target;
    return [c autorelease];
  } while (NO) ;

  if (c) [c release];
  return nil;
}

+(NSString*)find {
  io_object_t serialPort;
  io_iterator_t serialPortIterator;
  NSString *tmp=nil, *dev=nil;
  
  IOServiceGetMatchingServices(
    kIOMasterPortDefault, 
    IOServiceMatching(kIOSerialBSDServiceValue), 
    &serialPortIterator);
  
  while ((serialPort = IOIteratorNext(serialPortIterator)) && !dev) {
    tmp = (NSString*)IORegistryEntryCreateCFProperty(
      serialPort, CFSTR(kIOCalloutDeviceKey),     
      kCFAllocatorDefault, 0);
    if ([tmp hasPrefix:@"/dev/cu.usbmodem"])
      dev = [NSString stringWithString:tmp];
    IOObjectRelease(serialPort);
  }
  IOObjectRelease(serialPortIterator);
  return dev;
}

-(BOOL)open:(NSString*)device {
  int d;
  speed_t rate = 9600;
  struct termios options;
  
  if (fd) {
    NSLog(@"Already open\n");
    return YES;
  }

  do {

    if ((d = open([device UTF8String],O_RDWR | O_NOCTTY | O_NONBLOCK)) < 0) {
      NSLog(@"open fd failed\n");
      break ;
    }

    ioctl(d, TIOCEXCL);
    fcntl(d, F_SETFL, 0);
    tcgetattr(d, &options);
    cfmakeraw(&options);
    ioctl(d, IOSSIOSPEED, &rate);
    [self performSelectorInBackground:@selector(ioCallback:) 
                           withObject: [NSThread currentThread]];

    fd = d;

    return YES;
    
  } while (NO);
  
  return NO;
}

-(void)close {
  if (fd) close(fd);
}

-(void)brightness:(int)bright {
  unsigned char buf[3] = {0xFF, 0x02, bright&0xFF};
  if (!fd) return ;
  write(fd, buf, 3);
}

-(void)button {
  unsigned char buf[3] = {0xFF, 0x01, 0x00};
  if (!fd) return ;
  write(fd, buf, 3);
}

-(void)ioCallback:(NSThread*)parent {
  unsigned char buf[3];
  int  cnt=0;

  unsigned char c=0;
  int  rd=0;
  int  reason=kControlNull;
  
  @autoreleasepool {
    
    while (read(fd, &c, 1)) {
      switch (c) {
       case 0xFF:
         cnt=0;
       default:
         buf[cnt++] = c;
         break;
      }
      if (cnt == sizeof(buf)) {
        reason=kControlNull;
        if (buf[0] == 0x6c && buf[1] == 0x62 && buf[2] == 0x21) {
          reason = kControlConnected;
          ready = YES;
        } else if (buf[0] == 0xff) {
          switch (buf[1]) {
           case 0x01:
             reason = kControlButton;
             state = buf[2];
             break ;
           case 0x02:
           case 0x03:
             reason = kControlBrightness;
             value = buf[2];
             break;
          }
        }
        if (delegate && reason != kControlNull) {
          [delegate controlChanged:self reason:reason];
        }
        cnt = 0;
        buf[0] = buf[1] = buf[2] = 0;
      }
    }
  }  
  NSLog(@"ioCallback completed");
}

@end

#if _STANDALONE_TEST_

@interface ControlD : NSObject<ControlDelegate> {
}
@end

@implementation ControlD
-(void)controlChanged:(id)sender reason:(int)reason {
  NSLog(@"Control Changed: %d", reason);
}
@end

int main(int argc, char** argv) {

  @autoreleasepool {

    ControlD* d = [[ControlD alloc] init];
    Controls* c = [Controls controlsWithTarget:d];

    NSLog(@"Running test");
    
    if (!c) return 1;

    while (!c.ready) {
      usleep(100*1000);
    }

    [c button];

    [c brightness:100];
    
    getc(stdin);

    [c brightness:0];
  }
  
  return 0;
}

#endif
