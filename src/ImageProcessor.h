#import <Cocoa/Cocoa.h>
#import <Quartz/Quartz.h>

@interface NSImage (CoreImageExtension)
+(NSImage*)imageWithCIImage:(CIImage*)image;
-(CIImage*)CIImage;
@end

@interface ImageProcessor : NSObject {
  NSDictionary *settings;
  CIFilter     *filter;
}

@property (nonatomic, retain) NSDictionary *settings;
@property (nonatomic, retain) CIFilter     *filter;

+(ImageProcessor*)processorWithSettings:(NSDictionary*)settings;

-(NSImage*)filteredImage:(id)input;

@end
