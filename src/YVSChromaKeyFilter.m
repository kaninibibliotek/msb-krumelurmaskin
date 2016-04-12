//
//  YVSChromaKeyFilter.m
//  chromakey
//
//  Created by Kevin Meaney on 20/02/2014.
//  Copyright (c) 2014 Kevin Meaney. All rights reserved.
//

#define STRINGIZE(x) #x
#define STRINGIZE2(x) STRINGIZE(x)
#define SHADER_STRING(text) @ STRINGIZE2(text)

#import <Foundation/Foundation.h>
#import <QuartzCore/QuartzCore.h>

#import "YVSChromaKeyFilter.h"

@interface YVSChromaKeyFilter ()
@property (nonatomic, retain) CIImage   *inputImage;
@property (nonatomic, retain) CIVector  *inputColor;
@property (nonatomic, retain) NSNumber  *inputDistance;
@property (nonatomic, retain) NSNumber  *inputSlopeWidth;
@end

NSString *const YVSChromaKeyFilterString = SHADER_STRING
(
  kernel vec4 apply(sampler inputImage, vec4 inputColor,
                    float inputDistance, float inputSlope)
  {
    vec4 outputColor;
    vec4 foregroundColor = sample(inputImage, samplerCoord(inputImage));
    foregroundColor = unpremultiply(foregroundColor);
    float dist = distance(foregroundColor.rgb, inputColor.rgb);
    float alpha = smoothstep(inputDistance, inputDistance + inputSlope, dist);
    outputColor.a = foregroundColor.a * alpha;
    outputColor.rgb = foregroundColor.rgb;
    outputColor = premultiply(outputColor);
    return outputColor;
  }
);

CIVector *YVSChromaKeyFilterDefaultInputColor;
NSNumber *YVSChromaKeyFilterDefaultInputDistance;
NSNumber *YVSChromaKeyFilterDefaultInputSlopeWidth;

static CIKernel *chromaKeyKernel;

@implementation YVSChromaKeyFilter
@synthesize inputImage, inputColor, inputDistance, inputSlopeWidth;

+(void)initialize
{

    if (self == [YVSChromaKeyFilter class])
    {

        NSArray *kernels = [CIKernel kernelsWithString:YVSChromaKeyFilterString];
        chromaKeyKernel = [kernels[0] retain];
        
        YVSChromaKeyFilterDefaultInputColor = [[CIVector alloc] initWithX:0.0f
                                                                        Y:1.0f
                                                                        Z:0.0f
                                                                        W:1.0];
        YVSChromaKeyFilterDefaultInputDistance   = [[NSNumber alloc] initWithDouble:0.08];
        YVSChromaKeyFilterDefaultInputSlopeWidth = [[NSNumber alloc] initWithDouble:0.06];
        
        [CIFilter registerFilterName:@"YVSChromaKeyFilter"
                         constructor:(id<CIFilterConstructor>)self
                     classAttributes:@{
            kCIAttributeFilterDisplayName : @"Simple Chroma Key.",
             kCIAttributeFilterCategories : @[
                   kCICategoryColorAdjustment, kCICategoryVideo,
                   kCICategoryStillImage, kCICategoryInterlaced,
                   kCICategoryNonSquarePixels]
                                     }
         ];
    }
}

+(void)setDefaults:(CIFilter*)filter withDictionary:(NSDictionary*)settings {
  CIVector *color;
  NSNumber *n;
  double  r=0,g=1,b=0,d=0.2,s=0.02;
  NSString *val;
  if ((val = [settings objectForKey:@"red"]))
    r = [val doubleValue];
  if ((val = [settings objectForKey:@"green"]))
    g = [val doubleValue];
  if ((val = [settings objectForKey:@"blue"]))
    b = [val doubleValue];
  NSLog(@"Calibration color [%f, %f, %f]\n", r, g, b);
  color = [[[CIVector alloc] initWithX:r Y:g Z:b W:1.0] autorelease];
  [filter setValue:color forKey:@"inputColor"];
  if ((val = [settings objectForKey:@"distance"]))
    d = [val doubleValue];
  if ((val = [settings objectForKey:@"slope"]))
    s = [val doubleValue];
  NSLog(@"Distance: %f Slope: %f\n", d, s);
  n = [NSNumber numberWithDouble:d];
  [filter setValue:n forKey:@"inputDistance"];
  n = [NSNumber numberWithDouble:s];
  [filter setValue:n forKey:@"inputSlopeWidth"];

}

+(CIFilter *)filterWithName:(NSString *)name
{
    CIFilter  *filter = [[YVSChromaKeyFilter alloc] init];
    return [filter autorelease];
}

-(id)init
{
    self = [super init];
    
    if (self)
    {
      self.inputColor = YVSChromaKeyFilterDefaultInputColor;
      self.inputDistance = YVSChromaKeyFilterDefaultInputDistance;
      self.inputSlopeWidth = YVSChromaKeyFilterDefaultInputSlopeWidth;
    }
    
    return self;
}

- (CIImage *)outputImage
{
    NSParameterAssert(inputImage != nil &&
                      [inputImage isKindOfClass:[CIImage class]]);
    NSParameterAssert(inputColor != nil &&
                      [inputColor isKindOfClass:[CIVector class]]);
    NSParameterAssert(inputDistance != nil &&
                      [inputDistance isKindOfClass:[NSNumber class]]);
    NSParameterAssert(inputSlopeWidth != nil &&
                      [inputSlopeWidth isKindOfClass:[NSNumber class]]);
    
    // Create output image by applying chroma key filter.
    CIImage *outputImage;
    
    outputImage = [self apply:chromaKeyKernel,
                            [CISampler samplerWithImage:inputImage],
                            self->inputColor, inputDistance, inputSlopeWidth,
                            kCIApplyOptionDefinition, [inputImage definition],
                            nil];
    
    return outputImage;
}

- (NSDictionary *)customAttributes
{
    NSDictionary *inputColorProps = @{
                     kCIAttributeClass : [CIColor class],
                   kCIAttributeDefault : YVSChromaKeyFilterDefaultInputColor,
                      kCIAttributeType : kCIAttributeTypeOpaqueColor };
    
    NSDictionary *inputDistanceProps = @{
                     kCIAttributeClass : [NSNumber class],
                   kCIAttributeDefault : YVSChromaKeyFilterDefaultInputDistance,
                      kCIAttributeType : kCIAttributeTypeDistance };

    NSDictionary *inputSlopeWidthProps = @{
                    kCIAttributeClass : [NSNumber class],
                  kCIAttributeDefault : YVSChromaKeyFilterDefaultInputSlopeWidth,
                     kCIAttributeType : kCIAttributeTypeDistance };

    return @{ kCIInputColorKey : inputColorProps,
              @"inputDistance" : inputDistanceProps,
            @"inputSlopeWidth" : inputSlopeWidthProps };
}


@end
