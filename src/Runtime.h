#ifndef Runtime_H_
#define Runtime_H_

#import <Cocoa/Cocoa.h>
#import <Python/Python.h>

#import "NSString+Py.h"

@interface Runtime : NSObject {
}

-(id)init;
-(BOOL)run:(NSString*)m;
-(void)shutdown;

@end

#endif
