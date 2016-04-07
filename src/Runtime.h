#ifndef Runtime_H_
#define Runtime_H_

#import <Cocoa/Cocoa.h>
#import <Python/Python.h>

#import "NSString+Py.h"

@interface Runtime : NSObject {
  PyThreadState *state;
}

+(Runtime*)sharedRuntime;
-(BOOL)run:(NSString*)m;
-(void)shutdown;
-(BOOL)callable:(PyObject*)obj symbol:(NSString*)name;
-(PyObject*)call:(PyObject*)obj symbol:(NSString*)name arguments:(PyObject*)args;
-(BOOL)voidcall:(PyObject*)obj symbol:(NSString*)name arguments:(PyObject*)args;
-(void)register:(NSString*)module interface:(PyMethodDef*)def;

@end

#endif
