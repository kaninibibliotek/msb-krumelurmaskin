#import "Runtime.h"

@implementation Runtime

-(id)init {
  if (self = [super init]) {
    Py_Initialize();
    PyUnicode_SetDefaultEncoding("utf-8");
  }
  return self;
}

-(BOOL)run:(NSString*)m {
  NSError *err;
  NSString *path, *data;
  PyObject *syspath = PySys_GetObject("path");
  NSBundle *bundle = [NSBundle mainBundle];

  if (!(path =[bundle pathForResource:@"lib" ofType:nil])) {
    NSLog(@"Unable to locate required path: lib\n");
    return NO;
  }
  NSLog(@"Appending %@ to path\n", path);
  PyList_Append(syspath, [path pyString]);
  if (!(path = [bundle pathForResource:m ofType:@"py" inDirectory:@"lib"])) {
    NSLog(@"Module %@ not found\n", m);
    return NO;
  }
  NSLog(@"Loading [%@] %@\n", m, path);
  data = [NSString stringWithContentsOfFile:path encoding:NSUTF8StringEncoding error:&err];
  if (err) {
    NSLog(@"An error occured readin resource %@\n", m);
    return NO;
  }
  
  PyRun_SimpleString([data UTF8String]);
  
  if (PyErr_Occurred()) {
    NSLog(@"Error parsing module\n");
    PyErr_Print();
    PyErr_Clear();
    return NO;
  }

  return YES;
}

-(void)shutdown {
  [self voidcall:nil symbol:@"shutdown" arguments:nil];
  Py_Finalize();
}

-(BOOL)callable:(PyObject*)obj symbol:(NSString*)name {
  BOOL      res = NO;
  PyObject* attr;
    
    if (nil == name)
      return NO;
  
  if (!obj && (obj = PyImport_AddModule("__main__")) == 0L)
    return NO;
      
  if (!PyObject_HasAttrString(obj, [name UTF8String]))
    return false;

  if ((attr = PyObject_GetAttrString(obj, [name UTF8String])) != NULL) {
    res = (PyCallable_Check(attr) != 0);
    Py_DECREF(attr);
  }    
  
  return res;
}

-(PyObject*)call:(PyObject*)obj symbol:(NSString*)name arguments:(PyObject*)args {
  PyObject *attr=0L,*res=0L;
  
  if (!obj && (obj = PyImport_AddModule("__main__")) == 0L)
    return 0L;
    
  if ((attr = PyObject_GetAttrString(obj, [name UTF8String])) == NULL)
    return 0L;
    
  if (PyCallable_Check(attr))
    res = PyObject_CallObject(attr, args);
    
  if (args != NULL)
    Py_DECREF(args);
    
  Py_DECREF(attr);    
    
  if (PyErr_Occurred()) {
    NSLog(@"py_call_attr(%@) an error occurred\n", name);
    PyErr_Print();
    PyErr_Clear();
  }

  return res;
}

-(BOOL)voidcall:(PyObject*)obj symbol:(NSString*)name arguments:(PyObject*)args {
    
  BOOL status = NO;
  
  PyObject *attr=0L,*res=0L;

  if (!obj && (obj = PyImport_AddModule("__main__")) == 0L)
    return NO;

  if ((attr = PyObject_GetAttrString(obj, [name UTF8String])) == 0L)
    return NO;

  do {
            
    if (!PyCallable_Check(attr))
      break ;

    res = PyObject_CallObject(attr, args);
        
    if (0L != res)
      Py_DECREF(res);
        
    status = true;

  } while (NO);
    
  if (args != NULL)
    Py_DECREF(args);
    
  if (attr != NULL)
    Py_DECREF(attr);
    
  if (PyErr_Occurred()) {
    NSLog(@"py_call_attr_void(%@) an error occurred\n", name);
    PyErr_Print();
    PyErr_Clear();
    status = false;
  }

  return status;

}

@end
