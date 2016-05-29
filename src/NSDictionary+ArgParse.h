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

#ifndef ArgParse_H_
#define ArgParse_H_

@interface NSDictionary (ArgParse)
+(NSDictionary*)dictionaryFromArgs:(char**)argv count:(int)argc;
-(BOOL)requireKeys:(NSArray*)keys andArgumentCount:(int)cnt;
-(NSDictionary*)update:(NSDictionary*)dict;
@end

@implementation NSDictionary (ArgParse)
+(NSDictionary*)dictionaryFromArgs:(char**)argv count:(int)argc {
  int i=1;
  NSMutableArray* p = [NSMutableArray arrayWithCapacity:0];
  NSMutableDictionary* d = [NSMutableDictionary dictionaryWithCapacity:0];
  while(i < argc) {
    NSString* arg = [NSString stringWithCString:argv[i] encoding:NSUTF8StringEncoding];
    if (![arg hasPrefix:@"-"]) {
      [p addObject:arg];
      i++; continue ;
    }
    if (argc-i < 2) {
      [d setObject:@"true" forKey:[arg substringFromIndex:1]];
      i++; continue ;
    }
    NSString* val = [NSString stringWithCString:argv[i+1] encoding:NSUTF8StringEncoding];
    if ([val hasPrefix:@"-"]) {
      [d setObject:@"true" forKey:[arg substringFromIndex:1]];
      i++; continue ;
    }
    [d setObject:val forKey:[arg substringFromIndex:1]];
    i+=2;
  }
  [d setObject:[NSNumber numberWithInt:[p count]] forKey:@"count"];
  [d setObject:(NSArray*)p forKey:@"arguments"];
  return d;
}
-(BOOL)requireKeys:(NSArray*)keys andArgumentCount:(int)cnt {
  for (NSString *key in keys)
    if ([self objectForKey:key] == nil) return NO;
  if ([[self objectForKey:@"count"] intValue] < cnt) return NO;
  return YES;
}
-(NSDictionary*)update:(NSDictionary*)dict {
  NSMutableDictionary* d = [dict mutableCopy];
  id val;
  for (NSString *key in [d allKeys])
    if ((val = [self objectForKey:key]))
      [d setObject:val forKey:key];
  return d;
}
@end
#endif
