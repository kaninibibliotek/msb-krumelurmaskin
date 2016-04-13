#import "ImageProcessor.h"

#pragma GCC diagnostic push
#pragma GCC diagnostic ignored "-Wmissing-declarations"
#include <opencv2/highgui.hpp>
#include <opencv2/imgproc.hpp>
#pragma GCC diagnostic pop

@interface ImageProcessor ()
-(NSNumber*)doubleForKey:(NSString*)key orDefault:(double)val;
-(NSString*)stringForKey:(NSString*)key orDefault:(NSString*)val;
-(NSNumber*)integerForKey:(NSString*)key orDefault:(int)val;
@end

@implementation NSImage (CoreImageExtension)
+(NSImage*)imageWithCIImage:(CIImage*)image {
  if (!image) return nil;
  NSCIImageRep *r = [NSCIImageRep imageRepWithCIImage:image];
  NSImage* i = [[NSImage alloc] initWithSize:[r size]];
  [i addRepresentation:r];
  return [i autorelease];
}

-(CIImage*)CIImage {
  return [CIImage imageWithData:[self TIFFRepresentation]];
}
@end

@implementation ImageProcessor
@synthesize settings, filter;

-(id)init {
  if (self = [super init]) {
    settings = nil;
    filter = nil;
  }
  return self;
}

-(NSImage*)filteredImage:(id)inptr {
  CIImage *input = nil, *output = nil;
  if ([inptr isKindOfClass:[NSImage class]])
    input = [(NSImage*)inptr CIImage];
  else
    input = (CIImage*)inptr;
  if (!filter && (self.filter = [CIFilter filterWithName:@"YVSChromaKeyFilter"])) {
    NSLog(@"Creating standard YVSChromaKeyFilter\n");
    [filter setDefaults];
    CGFloat c[4] = {
      [[self doubleForKey:@"red" orDefault:0.0] doubleValue],
      [[self doubleForKey:@"green" orDefault:1] doubleValue],
      [[self doubleForKey:@"blue" orDefault:0] doubleValue],
      1.0
    };
    NSLog(@"Basecolor: rgba(%f, %f, %f, %f)\n", c[0],c[1],c[2],c[3]);
    [filter setDefaults];
    [filter setValue:[CIVector vectorWithValues:c count:4] forKey:@"inputColor"];
    [filter setValue:[self doubleForKey:@"distance" orDefault:0.3] forKey:@"inputDistance"];
    [filter setValue:[self doubleForKey:@"slope" orDefault:0.02] forKey:@"inputSlopeWidth"];
    NSLog(@"Distance: %f\n", [[filter valueForKey:@"inputDistance"] doubleValue]);
    NSLog(@"Slope: %f\n", [[filter valueForKey:@"inputSlopeWidth"] doubleValue]);
  }
  if (filter) {
    [filter setValue:input forKey:kCIInputImageKey];
    output = [filter valueForKey:kCIOutputImageKey];
  } else {
    output = input;
  }
  return [NSImage imageWithCIImage:output];
}

+(ImageProcessor*)processorWithSettings:(NSDictionary*)s {
  ImageProcessor* ip = [[ImageProcessor alloc] init];
  ip.settings = s;
  return [ip autorelease];
}

-(NSNumber*)doubleForKey:(NSString*)key orDefault:(double)val {
  NSNumber *n;
  if (settings && (n = [settings objectForKey:key]))
    return [NSNumber numberWithDouble:[n doubleValue]];
  return [NSNumber numberWithDouble:val];
}
  
-(NSString*)stringForKey:(NSString*)key orDefault:(NSString*)val {
  NSString *s;
  if (settings && (s = [settings objectForKey:key]))
    return s;
  return val;
}

-(NSNumber*)integerForKey:(NSString*)key orDefault:(int)val {
  NSNumber *n;
  if (settings && (n = [settings objectForKey:key]))
    return [NSNumber numberWithInt:[n intValue]];
  return [NSNumber numberWithInt:val];
}

@end
