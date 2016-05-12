#include <limits.h>

#pragma GCC diagnostic push
#pragma GCC diagnostic ignored "-Wmissing-declarations"
#pragma GCC diagnostic ignored "-Wimplicit-function-declaration"
#include <opencv2/core/core_c.h>
#include <opencv2/imgproc/imgproc_c.h>
#include <opencv2/highgui/highgui_c.h>
#pragma GCC diagnostic pop

#import "ImageProcessor.h"

#define ERROR_DOMAIN @"ImageProcessorErrorDomain"
#define ERROR(a,b) [NSError errorWithDomain:nil code:a userInfo:@{NSLocalizedDescriptionKey: @b}]

CGImageRef
CGImageCreateWithCIImage(CIImage *image) {
  CGRect rect;
  CGContextRef ctx;
  CGColorSpaceRef colorspace;
  CGColorRef color;
  NSDictionary *options;
  CGImageRef output;
  size_t bytesPerRow;
  CIContext *cix;
  
  if (!image) return nil;
  
  rect = image.extent;
  
  bytesPerRow = rect.size.width * 4;
  if (bytesPerRow % 16)
    bytesPerRow += 16 - (bytesPerRow % 16);
    
  colorspace = CGColorSpaceCreateWithName(kCGColorSpaceSRGB);
  
  ctx = CGBitmapContextCreate(
    NULL,
    (size_t)rect.size.width,
    (size_t)rect.size.height,
    8,
    bytesPerRow,
    colorspace,
    (CGBitmapInfo)kCGImageAlphaPremultipliedLast);

  CGContextSaveGState(ctx);
  color = CGColorCreateGenericRGB(0.0, 0.0, 0.0, 0.0);
  CGContextSetBlendMode(ctx, kCGBlendModeCopy);
  CGContextSetFillColorWithColor(ctx, color);
  CGContextFillRect(ctx, rect);
  CGContextRestoreGState(ctx);
  
  options = @{
    kCIContextWorkingColorSpace : (__bridge id)colorspace,
    kCIContextUseSoftwareRenderer : @NO
  };

  cix = [CIContext contextWithCGContext:ctx options:options];
  
  [cix drawImage:image inRect:rect fromRect:rect];

  output = CGBitmapContextCreateImage(ctx);

  CGColorRelease(color);
  CFRelease(colorspace);
  CGContextRelease(ctx);
  return output;
}

//------------------------------------------------------------------------------------------------------------

IplImage*
IplImageCreateWithCGImage(CGImageRef image, CGColorRef color) {
  size_t width, height;
  CGColorSpaceRef colorspace;
  IplImage *ipl;
  CGContextRef ctx;
  CGRect rect;

  if (!image) return 0;

  width = CGImageGetWidth(image);
  height = CGImageGetHeight(image);

  rect = CGRectMake(0, 0, width, height);
  
  colorspace = CGColorSpaceCreateDeviceRGB();
  ipl = cvCreateImage(cvSize(width, height), IPL_DEPTH_8U, 4);
  ctx = CGBitmapContextCreate(
    ipl->imageData,
    ipl->width,
    ipl->height,
    ipl->depth,
    ipl->widthStep,
    colorspace,
    kCGImageAlphaPremultipliedLast|kCGBitmapByteOrderDefault);

  CGContextSaveGState(ctx);
  if (!color)
    color = CGColorCreateGenericRGB(0.0, 0.0, 0.0, 0.0);
  CGContextSetBlendMode(ctx, kCGBlendModeCopy);
  CGContextSetFillColorWithColor(ctx, color);
  CGContextFillRect(ctx, rect);
  CGContextDrawImage(ctx, CGRectMake(0, 0, width, height), image);
  CGContextRestoreGState(ctx);

  CGColorRelease(color);
  CGContextRelease(ctx);
  CGColorSpaceRelease(colorspace);
  return ipl;
}

//------------------------------------------------------------------------------------------------------------

IplImage*
IplImageCreateWithCIImage(CIImage *image, CGColorRef color) {
  CGContextRef ctx;
  CGColorSpaceRef colorspace;
  NSDictionary *options;
  CGImageRef output;
  size_t bytesPerRow;
  CIContext *cix;
  CGRect rect;
  IplImage *ipl;
  
  if (!image) return 0;

  rect = image.extent;
  
  colorspace = CGColorSpaceCreateDeviceRGB();
  ipl = cvCreateImage(cvSize(rect.size.width, rect.size.height), IPL_DEPTH_8U, 4);
  
  ctx = CGBitmapContextCreate(
    ipl->imageData,
    ipl->width,
    ipl->height,
    ipl->depth,
    ipl->widthStep,
    colorspace,
    kCGImageAlphaPremultipliedLast|kCGBitmapByteOrderDefault);

  CGContextSaveGState(ctx);
  if (!color)
    color = CGColorCreateGenericRGB(0.0, 0.0, 0.0, 0.0);
  CGContextSetBlendMode(ctx, kCGBlendModeCopy);
  CGContextSetFillColorWithColor(ctx, color);
  CGContextFillRect(ctx, rect);
  CGContextRestoreGState(ctx);

  options = @{
    kCIContextWorkingColorSpace : (__bridge id)colorspace,
    kCIContextUseSoftwareRenderer : @NO
  };

  cix = [CIContext contextWithCGContext:ctx options:options];
  
  [cix drawImage:image inRect:rect fromRect:rect];

  CGColorRelease(color);
  CGContextRelease(ctx);
  CGColorSpaceRelease(colorspace);
  
  return ipl;
}

//------------------------------------------------------------------------------------------------------------

CIImage*
CIImageCreateWithIplImage(IplImage *ipl, CIFormat format_) {
  CIImage *output;
  NSData *data;
  size_t width, height;
  CGColorSpaceRef colorspace;
  CGContextRef ctx;
  CIContext *cix;
  CGRect rect;

  if (!ipl) return 0;

  data = [NSData dataWithBytesNoCopy:ipl->imageData length:(ipl->height * ipl->widthStep) freeWhenDone:NO];

  colorspace = CGColorSpaceCreateDeviceRGB();
  
  output = [CIImage imageWithBitmapData:data
                          bytesPerRow:ipl->widthStep
                                 size:CGSizeMake(ipl->width, ipl->height)
                               format:format_
                           colorSpace:colorspace];
  
  CGColorSpaceRelease(colorspace);

  return output;
}

//------------------------------------------------------------------------------------------------------------
#pragma mark - CoreImageExtensions
//------------------------------------------------------------------------------------------------------------

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
-(NSData*)PNGData {
  CGImageRef cg = [self CGImageForProposedRect:NULL
                   context:nil
                   hints:nil];
  NSBitmapImageRep *rep = [[[NSBitmapImageRep alloc] initWithCGImage:cg] autorelease];
  [rep setSize:[self size]];
  return [rep representationUsingType:NSPNGFileType properties:nil];
}
@end

//------------------------------------------------------------------------------------------------------------
#pragma mark - ImageProcessor
//------------------------------------------------------------------------------------------------------------

@interface ImageProcessor ()
-(NSNumber*)doubleForKey:(NSString*)key orDefault:(double)val;
-(NSString*)stringForKey:(NSString*)key orDefault:(NSString*)val;
-(NSNumber*)integerForKey:(NSString*)key orDefault:(int)val;
-(NSArray*)simplifyContour:(NSArray*)contourIn tolerance:(float)tolerance;
@end

@implementation ImageProcessor
@synthesize settings, filter;

-(id)init {
  if (self = [super init]) {
    settings = nil;
    filter = nil;
    last = nil;
  }
  return self;
}

-(void)dealloc {
  if (last) [last release];
  [super dealloc];
}

-(CIImage*)filteredImage:(CIImage*)input {
  if (!filter && (self.filter = [CIFilter filterWithName:@"YVSChromaKeyFilter"])) {
    NSLog(@"Creating standard YVSChromaKeyFilter\n");
    [filter setDefaults];
    CGFloat c[] = {
      [[self doubleForKey:@"key-red" orDefault:0.0] doubleValue],
      [[self doubleForKey:@"key-green" orDefault:1] doubleValue],
      [[self doubleForKey:@"key-blue" orDefault:0] doubleValue]
    };
    NSLog(@"Basecolor: rgb(%f, %f, %f, %f)\n", c[0],c[1],c[2],1.0);
    [filter setDefaults];
    [filter setValue:[CIVector vectorWithX:c[0] Y:c[1] Z:c[2] W:1.0] forKey:@"inputColor"];
    [filter setValue:[self doubleForKey:@"key-distance" orDefault:0.3] forKey:@"inputDistance"];
    [filter setValue:[self doubleForKey:@"key-slope" orDefault:0.02] forKey:@"inputSlopeWidth"];
    NSLog(@"Distance: %f\n", [[filter valueForKey:@"inputDistance"] doubleValue]);
    NSLog(@"Slope: %f\n", [[filter valueForKey:@"inputSlopeWidth"] doubleValue]);
  }
  if (filter) {
    [filter setValue:input forKey:kCIInputImageKey];
    return [filter valueForKey:kCIOutputImageKey];
  }
  return input;
}

-(CIImage*)apply:(CIImage*)image {

  CvMemStorage *mem = NULL;    
  IplImage     *src = NULL, *mask=NULL, *tmp=NULL, *img_r=NULL, *img_g=NULL, *img_b=NULL;
  CvSeq        *seq = NULL, *itr = NULL;
  CvMat        *mat = NULL;
  CvSize       size;
  CGColorRef   greycolor;
  CvScalar     extcolor;
  CGRect       rect;
  CIImage      *input, *output;
  
  int minx=INT_MAX, miny=INT_MAX, maxx=0, maxy=0;

  NSNumber *canny_threshold = [self integerForKey:@"canny-threshold" orDefault:100];
  NSNumber *poly_tolerance  = [self doubleForKey:@"poly-tolerance" orDefault:0.01];
  
  NSMutableArray *contours;
  
  if (!image)
    return nil;

  greycolor = 0; //CGColorCreateGenericRGB(0.5, 0.5, 0.5, 1.0);
  
  src = IplImageCreateWithCIImage(image, greycolor);

  size = cvGetSize(src);

  mask = cvCreateImage(size, IPL_DEPTH_8U, 1);

  tmp = cvCreateImage(size, IPL_DEPTH_8U, 3);
  
  mat = cvCreateMat(size.height, size.width, CV_8U);
  
  mem = cvCreateMemStorage(0);

  cvCvtColor(src, mask, CV_RGB2GRAY);

  cvSmooth(mask, mask, CV_GAUSSIAN, 3, 3, 0, 0);
  
  cvCanny(mask, mat, [canny_threshold intValue], [canny_threshold intValue], 3 );

  cvDilate(mat, mat, 0, 1);
    
  cvFindContours(mat, mem, &seq, sizeof(CvContour), CV_RETR_EXTERNAL, CV_CHAIN_APPROX_SIMPLE, cvPoint(0, 0));

  extcolor = CV_RGB(255, 0, 0);

  cvSet(tmp, CV_RGB(0, 0, 0), 0);

  for (itr=seq; itr != 0; itr = itr->h_next)
    cvDrawContours(tmp, itr, extcolor, CV_RGB(0,0,0), -1, CV_FILLED, CV_AA, cvPoint(0,0));

  cvSplit(tmp, NULL, NULL, mask, NULL);

  cvReleaseImage(&tmp);

  img_r = cvCreateImage(size, IPL_DEPTH_8U, 1);
  img_g = cvCreateImage(size, IPL_DEPTH_8U, 1);
  img_b = cvCreateImage(size, IPL_DEPTH_8U, 1);

  cvSplit(src, img_r, img_g, img_b, NULL);

  cvMerge(mask, img_r, img_g, img_b, src);

  cvReleaseImage(&img_r);
  cvReleaseImage(&img_g);
  cvReleaseImage(&img_b);
  cvReleaseImage(&mask);

  contours = [[NSMutableArray alloc] init];
  for (itr=seq ; itr ; itr=itr->h_next ) {
    NSMutableArray *tmp = [[NSMutableArray alloc] init];
    for( int j=0 ; j<seq->total ; j++ ) {
      CvPoint *pt = (CvPoint*)cvGetSeqElem( seq, j );
      CIVector *v = [CIVector vectorWithX:pt->x Y:pt->y Z:0 W:0];
      [tmp addObject:v];
    }
    [contours addObject:tmp];
    [tmp release];
  }

  output = CIImageCreateWithIplImage(src, kCIFormatARGB8);

  cvReleaseImage(&src);
  cvReleaseMemStorage(&mem);
  cvReleaseMat(&mat);

  for(long c = 0; c < [contours count]; c++ ) {

    NSArray *simpler = [self simplifyContour:[contours objectAtIndex:c]
                                   tolerance:[poly_tolerance doubleValue]];
            
    for (int i=0 ; i < [simpler count] ; i++) {
      CIVector *v = [simpler objectAtIndex:i];
      if (v.X > maxx) maxx = v.X;
      else if(v.X < minx) minx = v.X;
      if (v.Y > maxy) maxy = v.Y;
      else if(v.Y < miny) miny = v.Y;
    }
    
  }
  
  [contours release];
  
  NSLog(@"Crop [%d, %d, %d, %d]\n", minx, miny, maxx, maxy);

  rect = CGRectMake(minx, size.height-maxy, maxx-minx, maxy-miny);

  input = [output imageByCroppingToRect:rect];

  CIFilter* transform = [CIFilter filterWithName:@"CIAffineTransform"];
  NSAffineTransform* affineTransform = [NSAffineTransform transform];
  [affineTransform translateXBy:-rect.origin.x yBy:-rect.origin.y];
  [transform setValue:affineTransform forKey:@"inputTransform"];
  [transform setValue:input forKey:@"inputImage"];
  return [transform valueForKey:@"outputImage"];

}

-(CIImage*)loadImage:(NSURL*)fileURL {
  
  CGImageSourceRef source;
  CGImageRef       image;
  CIImage          *output;
  
  source = CGImageSourceCreateWithURL((__bridge CFURLRef)fileURL, nil);
  if (!source)
    return nil;
  if (!CGImageSourceGetCount(source)) {
    CFRelease(source);
    return nil;
  }
  image = CGImageSourceCreateImageAtIndex(source, 0, nil);
  CFRelease(source);
  if (!image) return nil;

  output = [CIImage imageWithCGImage:image];

  CGImageRelease(image);
  
  return output;
}

-(void)writeImage:(CIImage*)image toFile:(NSURL*)fileURL error:(NSError**)error {
  NSDictionary *options;
  CGImageRef output;
  CGImageDestinationRef exporter;

  if (!image | !fileURL) {
    if (error) *error = ERROR(1, "Invalid argument");
    return ;
  }

  output = CGImageCreateWithCIImage(image);
  
  exporter = CGImageDestinationCreateWithURL(
    (__bridge CFURLRef)fileURL,
    (__bridge CFStringRef)@"public.png",
    1, NULL);

  options = @{ (__bridge id) kCGImageDestinationLossyCompressionQuality : @1.0 };
  CGImageDestinationAddImage(exporter, output, (__bridge CFDictionaryRef)options);
  CGImageDestinationFinalize(exporter);

  CGImageRelease(output);
  CFRelease(exporter);
  
}

-(BOOL)compareDetect:(CIImage*)image {
  CGColorRef   greycolor;
  IplImage *a, *b, *ag, *bg, *d;
  CvMemStorage *s;
  CvSeq *c=0;
  CvSize size;
  CvRect rect;
  BOOL detect=NO;
  
  if (last == nil) {
    last = [image retain];
    return NO;
  }

  greycolor = 0; //CGColorCreateGenericRGB(0.5, 0.5, 0.5, 1.0);
    
  a = IplImageCreateWithCIImage(image, greycolor);
  b = IplImageCreateWithCIImage(last, greycolor);

  [last release];
  last = [image retain];

    
  size = cvGetSize(a);
  ag = cvCreateImage(size, IPL_DEPTH_8U, 1);
  cvCvtColor(a, ag, CV_RGB2GRAY);
  cvReleaseImage(&a);
  
  size = cvGetSize(b);
  bg = cvCreateImage(size, IPL_DEPTH_8U, 1);
  cvCvtColor(b, bg, CV_RGB2GRAY);
  cvReleaseImage(&b);
  
  s = cvCreateMemStorage(0);

  d = cvCreateImage(size, IPL_DEPTH_8U, 1);

  cvAbsDiff(bg, ag, d);

  cvReleaseImage(&ag);
  cvReleaseImage(&bg);

  cvSmooth(d, d, CV_GAUSSIAN, 3, 3, 0, 0);

  cvThreshold(d, d, 25, 255, CV_THRESH_BINARY);

  cvFindContours(d, s, &c, sizeof(CvContour), CV_RETR_EXTERNAL, CV_CHAIN_APPROX_SIMPLE, cvPoint(0, 0));

  cvReleaseImage(&d);

  for( ; c!=0 && !detect ; c = c->h_next) {
    rect = cvBoundingRect(c, 0);
    detect = (rect.width > 0 || rect.height > 0);
  }

  cvClearMemStorage(s);
  c = 0;

  return detect;
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

- (NSArray*)simplifyContour:(NSArray*)contourIn tolerance:(float)tolerance {

  NSMutableArray *contourOut = [[NSMutableArray alloc] init];
  CIVector *v;
  int numOfPoints;

  numOfPoints = [contourIn count];
    
  CvPoint* cvpoints;
    
  cvpoints = (CvPoint*) malloc (numOfPoints * sizeof(CvPoint));
    
  for( int i=0; i<numOfPoints; i++) {
    int j = i % numOfPoints;
    v = [contourIn objectAtIndex:j];
    cvpoints[ i ].x = v.X;
    cvpoints[ i ].y = v.Y;
  }
    
  //-- create contour.
    
  CvContour   contour;
  CvSeqBlock  contour_block;
    
  cvMakeSeqHeaderForArray (
    CV_SEQ_POLYLINE,
    sizeof(CvContour),
    sizeof(CvPoint),
    cvpoints,
    numOfPoints,
    (CvSeq*)&contour,
    &contour_block);
    
  //-- simplify contour.
    
  CvMemStorage* storage;
  storage = cvCreateMemStorage( 1000 );
    
  CvSeq *result = 0;
  result = cvApproxPoly(
    &contour,
    sizeof( CvContour ),
    storage,
    CV_POLY_APPROX_DP,
    cvContourPerimeter( &contour ) * tolerance,
    0);
    
  //-- contour out points.
  
  for( int j=0; j<result->total; j++ ) {
    CvPoint * pt = (CvPoint*)cvGetSeqElem( result, j );
    v = [CIVector vectorWithX:pt->x Y:pt->y Z:0 W:0];
    [contourOut addObject:v];
  }
    
  if( storage != NULL )
    cvReleaseMemStorage( &storage );
    
  free(cvpoints);

  return [contourOut autorelease];
}       

@end

#if _STANDALONE_TEST_
int main(int argc, char **argv) {
  NSError *err=nil;
  
  NSLog(@"ImageProcessor standalone test\n");
  if (argc < 2) {
    NSLog(@"Usage: imgprc <path>\n");
    return 1;
  }

  @autoreleasepool {
    NSString *path = [NSString stringWithCString:argv[1] encoding:NSUTF8StringEncoding];
    CIImage *input, *output;

    ImageProcessor *prc = [[ImageProcessor alloc] init];
    prc.settings = @{
      @"red":      @"0.21",
      @"green":    @"0.57",
      @"blue":     @"0.27",
      @"distance": @"0.20",
      @"slope":    @"0.02"
    };

    for (int i=0 ; i < 1 ; i++) {

      @autoreleasepool {
        input = [prc loadImage:[NSURL fileURLWithPath:path isDirectory:NO]];
        NSLog(@"Testrun %d\n", i);
        output = [prc apply:input];
        if (output) {
          [prc writeImage:output toFile:[NSURL fileURLWithPath:@"output.png" isDirectory:NO] error:&err];
          if (err)
            NSLog(@"An error occured: %@\n", [err localizedDescription]);
        }
      }
      
    }
    
    NSLog(@"About to drain pool\n");
    getchar();
  }
  NSLog(@"Pool drained\n");
  
  return 0;
}
#endif
