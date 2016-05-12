#import <Cocoa/Cocoa.h>
#import <Quartz/Quartz.h>

@interface NSImage (CoreImageExtensions)
+(NSImage*)imageWithCIImage:(CIImage*)image;
-(CIImage*)CIImage;
-(NSData*)PNGData;
@end

@interface ImageProcessor : NSObject {
  NSDictionary *settings;
  CIFilter     *filter;
  CIImage      *last;
}

@property (nonatomic, retain) NSDictionary *settings;
@property (nonatomic, retain) CIFilter     *filter;

+(ImageProcessor*)processorWithSettings:(NSDictionary*)settings;

-(CIImage*)filteredImage:(CIImage*)input;

-(CIImage*)apply:(CIImage*)input;

-(CIImage*)loadImage:(NSURL*)fileURL;

-(void)writeImage:(CIImage*)image toFile:(NSURL*)fileURL error:(NSError**)err;

-(BOOL)compareDetect:(CIImage*)image;

@end
