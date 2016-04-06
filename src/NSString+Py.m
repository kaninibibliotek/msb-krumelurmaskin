#import "NSString+Py.h"

@implementation NSString(PyString)

+(NSString*)stringWithPyString:(PyObject*)str {
  return [NSString stringWithCString:PyString_AsString(str) encoding:NSUTF8StringEncoding];
}

-(PyObject*)pyString {
  return PyString_FromStringAndSize([self UTF8String], [self length]);
}

@end
