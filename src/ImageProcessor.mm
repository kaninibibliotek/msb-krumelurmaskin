#include <vector>
#include <string>
#include <limits.h>

#pragma GCC diagnostic push
#pragma GCC diagnostic ignored "-Wmissing-declarations"
#include <opencv2/core/core_c.h>
#include <opencv2/imgproc/imgproc_c.h>
#include <opencv2/highgui/highgui_c.h>
#pragma GCC diagnostic pop

#import "ImageProcessor.h"

#define CANNY_THRESHOLD 100
#define RNG_SEED        12345
#define POLY_TOLERANCE  0.01

#define ERROR(a,b) [NSError errorWithDomain:nil code:a userInfo:@{NSLocalizedDescriptionKey: @b}]

using namespace std;

//------------------------------------------------------------------------------------------------------------

enum {
    POLYGON_FLAGS_NONE   = 0x0,
    POLYGON_FLAGS_UNWIND = 0x01,
    POLYGON_FLAGS_HULL   = 0x02,
    POLYGON_FLAGS_FLIPY  = 0x04
};

//------------------------------------------------------------------------------------------------------------

class Vec2
{
public:
    Vec2()                 : x(0), y(0) {}
    Vec2(int _x, int _y)   : x(_x), y(_y) {}
    Vec2(const Vec2& v)    : x(v.x), y(v.y) {}
    Vec2(const CvPoint* p) : x(p->x), y(p->y) {}    
    virtual ~Vec2() {}
    Vec2& operator=(const Vec2& v) {
        x = v.x; y = v.y;
        return *this;
    }
    int x;
    int y;
};

typedef vector<Vec2> Vec2Arr;

//------------------------------------------------------------------------------------------------------------

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
IplImageCreateWithCGImage(CGImageRef image, CGColorRef color=0) {
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

IplImage*
IplImageCreateWithCIImage(CIImage *image, CGColorRef color=0) {
  CGContextRef ctx;
  CGColorSpaceRef colorspace;
  NSDictionary *options;
  CGImageRef output;
  CGImageDestinationRef exporter;
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

void
poly_simplify(const Vec2Arr& contourIn, Vec2Arr& contourOut, float tolerance )
{
    
    //-- copy points.
    
    int numOfPoints;
    numOfPoints = contourIn.size();
    
    CvPoint* cvpoints;
    cvpoints = new CvPoint[ numOfPoints ];
    
    for( int i=0; i<numOfPoints; i++)
    {
        int j = i % numOfPoints;
        
        cvpoints[ i ].x = contourIn[ j ].x;
        cvpoints[ i ].y = contourIn[ j ].y;
    }
    
    //-- create contour.
    
    CvContour   contour;
    CvSeqBlock  contour_block;
    
    cvMakeSeqHeaderForArray
    (
        CV_SEQ_POLYLINE,
        sizeof(CvContour),
        sizeof(CvPoint),
        cvpoints,
        numOfPoints,
        (CvSeq*)&contour,
        &contour_block
    );
    
    //-- simplify contour.
    
    CvMemStorage* storage;
    storage = cvCreateMemStorage( 1000 );
    
    CvSeq *result = 0;
    result = cvApproxPoly
    (
        &contour,
        sizeof( CvContour ),
        storage,
        CV_POLY_APPROX_DP,
        cvContourPerimeter( &contour ) * tolerance,
        0
    );
    
    //-- contour out points.
    
    contourOut.clear();
    for( int j=0; j<result->total; j++ )
    {
        CvPoint * pt = (CvPoint*)cvGetSeqElem( result, j );
        
        contourOut.push_back( Vec2(pt) );
    }
    
    //-- clean up.
    
    if( storage != NULL )
        cvReleaseMemStorage( &storage );
    
    delete[] cvpoints;
    
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

-(CIImage*)filteredImage:(CIImage*)input {
  if (!filter && (self.filter = [CIFilter filterWithName:@"YVSChromaKeyFilter"])) {
    NSLog(@"Creating standard YVSChromaKeyFilter\n");
    [filter setDefaults];
    CGFloat c[] = {
      [[self doubleForKey:@"red" orDefault:0.0] doubleValue],
      [[self doubleForKey:@"green" orDefault:1] doubleValue],
      [[self doubleForKey:@"blue" orDefault:0] doubleValue]
    };
    NSLog(@"Basecolor: rgb(%f, %f, %f, %f)\n", c[0],c[1],c[2],1.0);
    [filter setDefaults];
    [filter setValue:[CIVector vectorWithX:c[0] Y:c[1] Z:c[2] W:1.0] forKey:@"inputColor"];
    [filter setValue:[self doubleForKey:@"distance" orDefault:0.3] forKey:@"inputDistance"];
    [filter setValue:[self doubleForKey:@"slope" orDefault:0.02] forKey:@"inputSlopeWidth"];
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
  IplImage     *src = NULL, *grey=NULL;
  CvSeq        *seq = NULL;
  CvMat        *mat = NULL;
  CvSize       size;
  CIImage      *input;
  CGColorRef   greycolor;
  CvScalar     extcolor;
  CGRect       rect;
  int minx=INT_MAX, miny=INT_MAX, maxx=0, maxy=0;
  
  vector<Vec2Arr> contours;
  vector<Vec2Arr> result;    
  
  if (!image)
    return nil;

  greycolor = 0; //CGColorCreateGenericRGB(0.5, 0.5, 0.5, 1.0);
  
  src = IplImageCreateWithCIImage(image, greycolor);

  size = cvGetSize(src);

  grey = cvCreateImage(size, IPL_DEPTH_8U, 1);
    
  mat = cvCreateMat(size.height, size.width, CV_8U);
  
  mem = cvCreateMemStorage(0);

  cvCvtColor(src, grey, CV_RGB2GRAY);

  cvSmooth(grey, grey, CV_GAUSSIAN, 3, 3);
  
  cvCanny(grey, mat, CANNY_THRESHOLD, CANNY_THRESHOLD, 3 );

  cvDilate(mat, mat, 0, 1);
    
  cvFindContours(mat, mem, &seq, sizeof(CvContour), CV_RETR_EXTERNAL, CV_CHAIN_APPROX_SIMPLE, cvPoint(0, 0));

#if DEBUGELIBUGG
  for (; seq != 0; seq = seq->h_next) {
    extcolor = CV_RGB( rand()&255, rand()&255, rand()&255 ); //randomly coloring different contours
    cvDrawContours(src, seq, extcolor, CV_RGB(0,0,0), -1, CV_FILLED, 8, cvPoint(0,0));
  }

  char* source_window = "Source";
  cvNamedWindow( source_window, 0);
  cvShowImage( source_window, src);

  getchar();
#endif

  while (seq) {
    Vec2Arr tmp;
    for( int j=0 ; j<seq->total ; j++ ) {
      CvPoint * pt = (CvPoint*)cvGetSeqElem( seq, j );        
      tmp.push_back( Vec2(pt) );
    }
    contours.push_back(tmp);
    seq = seq->h_next;                
  }

  cvReleaseMat(&mat);    
  cvReleaseMemStorage(&mem);
  cvReleaseImage(&src);
  cvReleaseImage(&grey);
  
  for( long c = 0; c < contours.size(); c++ ) {

    Vec2Arr tmp, out;

    poly_simplify(contours[c], out, POLY_TOLERANCE);
            
    for (int i=0 ; i < out.size() ; i++) {
      if (out[i].x > maxx) maxx = out[i].x;
      else if(out[i].x < minx) minx = out[i].x;
      if (out[i].y > maxy) maxy = out[i].y;
      else if(out[i].y < miny) miny = out[i].y;
    }

  }

  NSLog(@"Crop [%d, %d, %d, %d]\n", minx, miny, maxx, maxy);

  rect = CGRectMake(minx, size.height-maxy, maxx-minx, maxy-miny);
  
  input = [image imageByCroppingToRect:rect];

  CIFilter* transform = [CIFilter filterWithName:@"CIAffineTransform"];
  NSAffineTransform* affineTransform = [NSAffineTransform transform];
  [affineTransform translateXBy:-rect.origin.x yBy:-rect.origin.y];
  [transform setValue:affineTransform forKey:@"inputTransform"];
  [transform setValue:input forKey:@"inputImage"];
  input = [transform valueForKey:@"outputImage"];

  return [self filteredImage:input];
  
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

#if _STANDALONE_TEST_
int main(int argc, char **argv) {
  NSError *err=nil;
  
  NSLog(@"ImageProcessor standalone test\n");
  if (argc < 2) {
    NSLog(@"Usage: imgprc <path>\n");
    return 1;
  }
  NSAutoreleasePool *ap = [[NSAutoreleasePool alloc] init];
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

  do {

    input = [prc loadImage:[NSURL fileURLWithPath:path isDirectory:NO]];

    for (int i=0 ; i < 1000 ; i++) {
      NSLog(@"Testrun %d\n", i);
      output = [prc apply:input];

      if (!output) {
        NSLog(@"Apply failed\n");
        break ;
      }

      [prc writeImage:output toFile:[NSURL fileURLWithPath:@"output.png" isDirectory:NO] error:&err];
      
      if (err)
        NSLog(@"An error occured: %@\n", [err localizedDescription]);
    }
    
  } while (false);

  [ap drain];
  
  return 0;
}
#endif
