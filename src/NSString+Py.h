#ifndef PyString_H_
#define PyString_H_

#import <Cocoa/Cocoa.h>
#import <Python/Python.h>

@interface NSString (PyString)
+(NSString*)stringWithPyString:(PyObject*)str;
-(PyObject*)pyString;
@end

#endif
