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

#import <Foundation/Foundation.h>
#import <NetFS/NetFS.h>
#import "NSURL+NetFS.h"

#define ERROR_DOMAIN @"NSURL+NetFSErrorDomain"
#define ERROR(a,b) [NSError errorWithDomain:ERROR_DOMAIN code:a userInfo:@{NSLocalizedDescriptionKey: @b}]

@implementation NSURL(NetFS)
-(BOOL)mount:(NSDictionary*)options path:(NSString**)path error:(NSError**)error {

  CFURLRef    cfurl    = (__bridge CFURLRef) self;
  CFStringRef cfuser   = 0L;
  CFStringRef cfpasswd = 0L;
  CFArrayRef  mp       = 0L;
  NSString    *value;
  int         i,r;

  if (options && (value = [options objectForKey:@"username"]))
    cfuser = (__bridge CFStringRef)value;

  if (options && (value = [options objectForKey:@"password"]))
    cfpasswd = (__bridge CFStringRef)value;
  
  if ((r = NetFSMountURLSync(cfurl, 0L, cfuser, cfpasswd, 0L, 0L, &mp)) != 0) {
    if (error) *error = ERROR(r, "The requested url could not be mounted");
    return NO;
  }
  if (CFArrayGetCount(mp) == 0) {
    if (error) *error = ERROR(0, "mount returned success but no mountpoint created");
    CFRelease(mp);
    return NO;
  }
  if (path)
    *path = [NSString stringWithString:(__bridge NSString*)CFArrayGetValueAtIndex(mp, 0)];
  CFRelease(mp);
  return YES;
}

@end

#if _STANDALONE_TEST_

int main(int argc, char** argv) {

  NSURL               *url;
  NSMutableDictionary *options;
  NSString            *path;
  NSError             *err;
  
  if (argc < 2) {
    NSLog(@"Usage: mnt <url> <user> <passwd>");
    return 1;
  }
  
  @autoreleasepool {

    url = [NSURL URLWithString:[NSString stringWithCString:argv[1] encoding:NSUTF8StringEncoding]];
    options = [NSMutableDictionary dictionaryWithCapacity:2];
    
    if (argc > 2)
      [options setObject:[NSString stringWithCString:argv[2] encoding:NSUTF8StringEncoding] forKey:@"username"];
    
    if (argc > 3)
      [options setObject:[NSString stringWithCString:argv[3] encoding:NSUTF8StringEncoding] forKey:@"password"];

    if (![url mount:options path:&path error:&err]) {
      NSLog(@"Mount failed for %@", url.absoluteString);
      if (err) NSLog(@"Error %@ code:%ld",  [err localizedDescription], [err code]);
      return 1;
    }

    NSLog(@"Volume successfully mounted: %@", path);
  }
  
  return 0;
}

#endif
