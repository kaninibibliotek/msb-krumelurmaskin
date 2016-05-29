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
contour_filter_size(CvSeq *seqin, int min_size) {
  CvSeq *ptr,*tmp=0, *new=0;
  CvRect r;

  for (ptr=seqin ; ptr ; ptr = ptr->h_next) {
    contour_get_size(ptr, &r);
    if (min_size>0 && (r.width <= min_size || r.height <= min_size))
      continue ;
    if (!new) {
      tmp = new = ptr;
      continue ;
    }
    tmp->h_next = ptr;
    ptr->h_prev = tmp;
    tmp = ptr;
  }
  tmp->h_next=0;
  return new;
}

CvSeq*
contour_flatten(CvSeq *seqin, CvMemStorage *mem) {
  CvSeq *flat, *ptr;
  CvMemStorage *tmp;
  CvRect r;
  int i;
  
  flat = cvCreateSeq(CV_32SC2, sizeof(CvContour), sizeof(CvPoint), mem);
  for (ptr=seqin ; ptr ; ptr=ptr->h_next) {
    for (i=0 ; i < ptr->total ; i++) {
      cvSeqPush(flat, (CvPoint*)cvGetSeqElem(ptr, i));
    }
  }
  return flat;
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
@end

//------------------------------------------------------------------------------------------------------------
#pragma mark - ImageProcessor
//------------------------------------------------------------------------------------------------------------

@interface ImageProcessor ()
-(CIImage*)cropImage:(CIImage*)image byContour:(CvSeq*)seq;
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

-(NSArray*)apply:(CIImage*)image {

  CvMemStorage   *mem = NULL;
  IplImage       *src = NULL, *mask=NULL, *tmp=NULL, *img_r=NULL, *img_g=NULL, *img_b=NULL;
  CvSeq          *seq = NULL, *itr = NULL;
  CvMat          *mat = NULL;
  CvSize         size;
  CGColorRef     greycolor;
  CvScalar       extcolor;
  CvRect         rect;
  CIImage        *outimg;
  NSMutableArray *outarr = [NSMutableArray arrayWithCapacity:0];
  
  int minx=INT_MAX, miny=INT_MAX, maxx=0, maxy=0;

  NSNumber *canny_threshold = [self integerForKey:@"canny-threshold" orDefault:100];
  NSNumber *canny_size      = [self integerForKey:@"canny-size" orDefault:3];
  NSNumber *min_size        = [self integerForKey:@"min-size" orDefault:32];
  NSNumber *blur_size       = [self integerForKey:@"gaussian-size" orDefault:3];
  NSNumber *polymode        = [self boolForKey:@"polymode" orDefault:NO];
  
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

  cvSmooth(mask, mask, CV_GAUSSIAN, [blur_size intValue], [blur_size intValue], 0, 0);
  
  cvCanny(mask, mat, [canny_threshold intValue], [canny_threshold intValue], [canny_size intValue] );

  cvDilate(mat, mat, 0, 1);
  
  cvFindContours(mat, mem, &seq, sizeof(CvContour), CV_RETR_EXTERNAL, CV_CHAIN_APPROX_SIMPLE, cvPoint(0, 0));

  extcolor = CV_RGB(255, 0, 0);

  cvSet(tmp, CV_RGB(0, 0, 0), 0);

  seq = contour_filter_size(seq, [min_size intValue]);
      
  for (itr=seq ; itr ; itr = itr->h_next)    
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

  outimg = CIImageCreateWithIplImage(src, kCIFormatARGB8);

  cvReleaseImage(&src);
  cvReleaseMat(&mat);

  if ([polymode boolValue]) {
    for (itr=seq ; itr ; itr = itr->h_next) {
      [outarr addObject:[self cropImage:outimg byContour:itr]];
    }
  } else {
    seq = contour_flatten(seq, mem);
    [outarr addObject:[self cropImage:outimg byContour:seq]];
  }
  cvReleaseMemStorage(&mem);
  return outarr;
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

-(CIImage*)cropImage:(CIImage*)image byContour:(CvSeq*)seq {
  CvMemStorage *mem      = cvCreateMemStorage(0);
  NSNumber     *min_size = [self integerForKey:@"min-size" orDefault:32];
  CvRect       rect;
  CGRect       cr;
  CIImage      *input;
  CvSeq        *hull;

  hull = cvConvexHull2(seq, mem, CV_CLOCKWISE, 1);
  
  contour_get_size(hull, &rect);

  cvReleaseMemStorage(&mem);

  NSLog(@"Crop [%d, %d, %d, %d]\n", rect.x, rect.y, rect.width, rect.height);

  cr.origin.x    = rect.x;
  cr.origin.y    = image.extent.size.height - (rect.y+rect.height);
  cr.size.width  = rect.width;
  cr.size.height = rect.height;
  
  input = [image imageByCroppingToRect:cr];
  
  CIFilter* transform = [CIFilter filterWithName:@"CIAffineTransform"];
  NSAffineTransform* affineTransform = [NSAffineTransform transform];
  [affineTransform translateXBy:-cr.origin.x yBy:-cr.origin.y];
  [transform setValue:affineTransform forKey:@"inputTransform"];
  [transform setValue:input forKey:@"inputImage"];
  return [transform valueForKey:@"outputImage"];

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

#include "NSDictionary+ArgParse.h"

int main(int argc, char **argv) {
  
  NSError        *err=nil;
  NSDictionary   *bundle,*settings,*arguments;
  NSString       *tp,*ta,*tn;
  NSFileManager  *fm;
  ImageProcessor *ip;
  NSArray        *oa;
  CIImage        *ii,*oi;
  NSURL          *fi,*fo;
  int            i;
  BOOL           wait=NO;
  
  NSLog(@"ImageProcessor standalone test\n");

  @autoreleasepool {
    arguments = [NSDictionary dictionaryFromArgs:argv count:argc];
    if (![arguments requireKeys:@[@"o"] andArgumentCount:1]) {
      NSLog(@"Usage imgprc -o <output directory path> <input image path>");
      return 1;
    }

    wait = ([arguments objectForKey:@"wait"] != nil);

    tp  = [NSString stringWithCString:getwd(0) encoding:NSUTF8StringEncoding];
    tp  = [tp stringByAppendingString:@"/Krumeluren.app/Contents/Info.plist"];
    bundle = [NSDictionary dictionaryWithContentsOfFile:tp];

    if (bundle && (bundle = [bundle objectForKey:@"Calibration"]))
      settings = [bundle objectForKey:@"Process"];

    settings = [arguments update:settings];

    if (wait) {
      NSLog(@"Press any key to start");
      getchar();
    }
    
    NSLog(@"settings {");
    for (NSString *key in [settings allKeys])
      NSLog(@" %@: %@", key, [settings objectForKey:key]);
    NSLog(@"}");
    
    ip = [ImageProcessor processorWithSettings:settings];
    
    for(NSString* ipath in [arguments objectForKey:@"arguments"]) {
      
      fi = [NSURL fileURLWithPath:ipath isDirectory:NO];
      
      if (!(ii = [ip loadImage:fi])) {
        NSLog(@"Could not read input: %@", ipath);
        break ;
      }
      NSLog(@"Apply <= %@", fi.path);
      if (!(oa = [ip apply:ii])) {
        NSLog(@"Apply failed for input image");
        break ;
      }

      for(i=0 ; i < [oa count] ; i++) {
        ta = [ipath lastPathComponent];
        tn = [NSString stringWithFormat:@"%@_%02d.png",
                       [ta stringByDeletingPathExtension], i];
        tp = [[arguments objectForKey:@"o"] stringByAppendingPathComponent:tn];
        fo = [NSURL fileURLWithPath:tp isDirectory:NO];
        oi = [oa objectAtIndex:i];
        NSLog(@"Writing => %@", fo.path);
        if (![ip writeImage:oi toFile:fo error:&err]) {
          NSLog(@"Unable to write file: %@", [err localizedDescription]);
          break ;
        }
      }
      if (err) break;
    }
    
    if (err)
      NSLog(@"Could not apply: %@", [err localizedDescription]);

    if (wait) {
      NSLog(@"Press any key to release pool");
      getchar();
    }

    NSLog(@"Releaseing pool");
  }

  NSLog(@"Continue");

  if (wait) {
    NSLog(@"Press any key to exit");
    getchar();
  }
  
  return 0;
}
#endif
