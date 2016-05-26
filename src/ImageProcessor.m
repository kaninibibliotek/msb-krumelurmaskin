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
#define ERROR(a,b) [NSError errorWithDomain:ERROR_DOMAIN code:a userInfo:@{NSLocalizedDescriptionKey: @b}]

void
contour_get_size(CvSeq *seq, CvRect *size) {
  int i, mix=INT_MAX, miy=INT_MAX, max=0, may=0;
  for( i=0 ; i<seq->total ; i++ ) {
    CvPoint *pt = (CvPoint*)cvGetSeqElem( seq, i );
    if (pt->x > max) max = pt->x;
    else if (pt->x < mix) mix = pt->x;
    if (pt->y > may) may = pt->y;
    else if (pt->y < miy) miy = pt->y;
  }
  if (size) *size = cvRect(mix, miy, max-mix, may-miy);
}

CvSeq*
contour_filter(CvSeq *seqin, CvMemStorage *mem, int min_size) {
  CvSeq *seqout, *filtered, *ptr;
  CvMemStorage *tmp;
  CvRect r;
  int i;
  
  tmp = cvCreateMemStorage(0);  
  filtered = cvCreateSeq(CV_32SC2, sizeof(CvContour), sizeof(CvPoint), tmp);

  for (ptr=seqin ; ptr ; ptr=ptr->h_next) {
    contour_get_size(ptr, &r);
    if (r.width <= min_size || r.height <= min_size)
      continue ;
    for (i=0 ; i < ptr->total ; i++) {
      cvSeqPush(filtered, (CvPoint*)cvGetSeqElem(ptr, i));
    }
  }
  seqout = cvConvexHull2(filtered, mem, CV_CLOCKWISE, 1);
  cvReleaseMemStorage(&tmp);
  return seqout;
}

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

  NSLog(@"CIImageWithIplImage(%d, %d)", ipl->width, ipl->height);
  
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
-(NSNumber*)boolForKey:(NSString*)key orDefault:(BOOL)val;
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

  if (![self boolForKey:@"enable-key-filter" orDefault:NO])
    return input;
  
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

  CvMemStorage *mem = NULL, *mem2 = NULL;    
  IplImage     *src = NULL, *mask=NULL, *tmp=NULL, *img_r=NULL, *img_g=NULL, *img_b=NULL;
  CvSeq        *seq = NULL, *itr = NULL;
  CvMat        *mat = NULL;
  CvSize       size;
  CGColorRef   greycolor;
  CvScalar     extcolor;
  CvRect       rect;
  CIImage      *input, *output;
  
  int minx=INT_MAX, miny=INT_MAX, maxx=0, maxy=0;

  NSNumber *canny_threshold = [self integerForKey:@"canny-threshold" orDefault:100];
  NSNumber *canny_size      = [self integerForKey:@"canny-size" orDefault:3];
  NSNumber *min_size        = [self integerForKey:@"min-size" orDefault:32];
  NSNumber *blur_size       = [self integerForKey:@"gaussian-size" orDefault:3];
  
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
  mem2 = cvCreateMemStorage(0);
  
  cvCvtColor(src, mask, CV_RGB2GRAY);

  cvSmooth(mask, mask, CV_GAUSSIAN, [blur_size intValue], [blur_size intValue], 0, 0);
  
  cvCanny(mask, mat, [canny_threshold intValue], [canny_threshold intValue], [canny_size intValue] );

  cvDilate(mat, mat, 0, 1);
  
  cvFindContours(mat, mem, &seq, sizeof(CvContour), CV_RETR_EXTERNAL, CV_CHAIN_APPROX_SIMPLE, cvPoint(0, 0));

  extcolor = CV_RGB(255, 0, 0);

  cvSet(tmp, CV_RGB(0, 0, 0), 0);

  seq = contour_filter(seq, mem2, [min_size intValue]);
  
  for (itr=seq; itr != 0; itr = itr->h_next)
    cvDrawContours(tmp, itr, extcolor, CV_RGB(0,0,0), -1, CV_FILLED, CV_AA, cvPoint(0,0));

  cvReleaseMemStorage(&mem);
  
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

  output = CIImageCreateWithIplImage(src, kCIFormatARGB8);

  cvReleaseImage(&src);
  cvReleaseMat(&mat);

  contour_get_size(seq, &rect);
  
  cvReleaseMemStorage(&mem2);

  return output;
  /*
  NSLog(@"Crop [%d, %d, %d, %d]\n", rect.x, rect.y, rect.width, rect.height);

  input = [output imageByCroppingToRect:CGRectMake(rect.x, rect.y, rect.width, rect.height)];

  CIFilter* transform = [CIFilter filterWithName:@"CIAffineTransform"];
  NSAffineTransform* affineTransform = [NSAffineTransform transform];
  [affineTransform translateXBy:-rect.x yBy:-rect.y*2];
  [transform setValue:affineTransform forKey:@"inputTransform"];
  [transform setValue:input forKey:@"inputImage"];
  return [transform valueForKey:@"outputImage"];
  */
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

-(BOOL)writeImage:(CIImage*)image toFile:(NSURL*)fileURL error:(NSError**)error {
  NSDictionary *options;
  CGImageRef output;
  CGImageDestinationRef exporter;

  if (!image | !fileURL) {
    if (error) *error = ERROR(1, "Invalid argument");
    return NO;
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
  return YES;
}

-(void)applyToPath:(NSString*)inputPath error:(NSError**)error {

  NSFileManager *fm=[NSFileManager defaultManager];
  NSString *outputPath = [NSString stringWithFormat:@"%@_cropped.%@",
                               [inputPath stringByDeletingPathExtension],
                               [inputPath pathExtension]];
  NSLog(@"Applying filter to %@", outputPath);

  if (![fm fileExistsAtPath:inputPath]) {
    if (error) *error = ERROR(22, "Input path does not exist");
    return ;
  }
  
  if ([fm fileExistsAtPath:outputPath]) {
    NSLog(@"Removing old %@", outputPath);
    if(![fm removeItemAtPath:outputPath error:error])
      return ;
  }

  CIImage *outputImage,*inputImage = nil;
  
  if (!(inputImage = [self loadImage:[NSURL fileURLWithPath:inputPath isDirectory:NO]])) {
    NSLog(@"Load image failed");
    if (error) *error = ERROR(23, "Could not read inputFile");
    return ;
  }
  
  if (!(outputImage = [self apply:inputImage])) {
    NSLog(@"Apply image failed");
    if (error) *error = ERROR(24, "Apply failed");
    return;
  }
  
  if (![self writeImage:outputImage toFile:[NSURL fileURLWithPath:outputPath isDirectory:NO] error:error]) {
    NSLog(@"Write image failed");
    return ;
  }

  if (![fm removeItemAtPath:inputPath error:error]) {
    NSLog(@"Remove input failed");
    return ;
  }

  if (![fm moveItemAtPath:outputPath toPath:inputPath error:error]) {
    NSLog(@"Move output file failed");
    return ;
  }
  
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

  cvReleaseMemStorage(&s);
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
    return n;
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
    return n;
  return [NSNumber numberWithInt:val];
}

-(NSNumber*)boolForKey:(NSString*)key orDefault:(BOOL)val {
  NSNumber *n;
  if (settings && (n = [settings objectForKey:key]))
    return n;
  return [NSNumber numberWithBool:val];
}

@end

#if _STANDALONE_TEST_
int main(int argc, char **argv) {
  NSError *err=nil;
  
  NSLog(@"ImageProcessor standalone test\n");
  if (argc < 2) {
    NSLog(@"Usage: imgprc <path> <red> <green> <blue> <distance> <slope>\n");
    return 1;
  }

  @autoreleasepool {
    NSString *inputPath = [NSString stringWithCString:argv[1] encoding:NSUTF8StringEncoding];
    NSString *outputPath= [NSString stringWithFormat:@"%@_cropped.%@",
                                 [inputPath stringByDeletingPathExtension], [inputPath pathExtension]];
    int i;
    NSArray *keys = @[@"red", @"green", @"blue", @"distance", @"slope"];
    NSMutableDictionary *settings = [NSMutableDictionary dictionaryWithCapacity:5];
    CIImage *inputImage, *outputImage;
    
    [settings setObject:@"0.21" forKey:keys[0]];
    [settings setObject:@"0.57" forKey:keys[1]];
    [settings setObject:@"0.27" forKey:keys[2]];
    [settings setObject:@"0.20" forKey:keys[3]];
    [settings setObject:@"0.02" forKey:keys[4]];

    for (i=2 ; i < argc ; i++) {
      float v = atof( argv[i] );
      [settings setObject:[NSNumber numberWithFloat:v] forKey:keys[i-2]];
      NSLog(@"%@==%f", keys[i-2], v);
    }
    
    ImageProcessor *ip = [ImageProcessor processorWithSettings:settings];

    do {

      NSURL *fi = [NSURL fileURLWithPath:inputPath isDirectory:NO];
      
      if (!(inputImage = [ip loadImage:fi])) {
        NSLog(@"Could not read input");
        break ;
      }

      if (!(outputImage = [ip apply:inputImage])) {
        NSLog(@"Apply failed for input image");
        break ;
      }
      NSURL *fo = [NSURL fileURLWithPath:outputPath isDirectory:NO];
      
      if (![ip writeImage:outputImage toFile:fo error:&err]) {
        NSLog(@"Unable to write file: %@", [err localizedDescription]);
        break ;
      }
      
    } while (NO);
    
    NSLog(@"About to drain pool\n");

    if (err) {
      NSLog(@"Could not apply: %@", [err localizedDescription]);
    }
    
  }
  
  NSLog(@"Pool drained\n");
  
  return 0;
}
#endif
