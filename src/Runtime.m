#import "Runtime.h"

@implementation Runtime

+(Runtime*)sharedRuntime {
  static Runtime* rt=0L;
  if (!rt) rt = [[Runtime alloc] init];
  return rt;
}

-(id)init {
  if (self = [super init]) {
    state=0L;
    Py_Initialize();
    PyEval_InitThreads();
    PyUnicode_SetDefaultEncoding("utf-8");
    state = PyEval_SaveThread();
  }
  return self;
}

-(BOOL)run:(NSString*)m {
  NSError *err=nil;
  NSString *path, *data;
  PyObject *syspath = 0;
  BOOL success=NO;
  NSBundle *bundle = [NSBundle mainBundle];

  @synchronized(self) {
    do {
      
      if (state)
        PyEval_RestoreThread(state);

      syspath = PySys_GetObject("path");

      if (!(path =[bundle pathForResource:@"lib" ofType:nil])) {
        NSLog(@"Unable to locate required path: lib\n");
        break ;
      }
      
      NSLog(@"Appending %@ to path\n", path);

      PyList_Append(syspath, [path pyString]);

      if (!(path = [bundle pathForResource:m ofType:@"py" inDirectory:@"lib"])) {
        NSLog(@"Module %@ not found\n", m);
        break ;
      }
      
      NSLog(@"Loading [%@] %@\n", m, path);

      data = [NSString stringWithContentsOfFile:path encoding:NSUTF8StringEncoding error:&err];

      if (err) {
        NSLog(@"An error occured readin resource %@ %@\n", m, [err localizedDescription]);
        break ;
      }
  
      PyRun_SimpleString([data UTF8String]);
  
      if (PyErr_Occurred()) {
        NSLog(@"Error parsing module\n");
        PyErr_Print();
        PyErr_Clear();
        break ;
      }
      success = YES;
    } while(NO);
    state = PyEval_SaveThread();
  }
  return success;
}

-(void)shutdown {
  [self voidcall:nil symbol:@"shutdown" arguments:nil];
  @synchronized(self) {
    PyEval_RestoreThread(state);
    Py_Finalize();
    PyThreadState_Swap(0L);
    PyEval_ReleaseLock();
    state = 0;
  }
}

-(BOOL)callable:(PyObject*)obj symbol:(NSString*)name {
  BOOL      res = NO;
  PyObject* attr;

  @synchronized(self) {
    do {
      PyEval_RestoreThread(state);
      
      if (nil == name)
        break ;
  
      if (!obj && (obj = PyImport_AddModule("__main__")) == 0L)
        break ;
      
      if (!PyObject_HasAttrString(obj, [name UTF8String]))
        break ;

      if ((attr = PyObject_GetAttrString(obj, [name UTF8String])) != NULL) {
        res = (PyCallable_Check(attr) != 0);
        Py_DECREF(attr);
      }
    } while(NO);
    state = PyEval_SaveThread();
  }
  return res;
}

-(PyObject*)call:(PyObject*)obj symbol:(NSString*)name arguments:(PyObject*)args {
  PyObject *attr=0L,*res=0L;

  @synchronized(self) {
    do {
      PyEval_RestoreThread(state);
      
      if (!obj && (obj = PyImport_AddModule("__main__")) == 0L)
        break ;
    
      if ((attr = PyObject_GetAttrString(obj, [name UTF8String])) == NULL)
        break ;
    
      if (PyCallable_Check(attr))
        res = PyObject_CallObject(attr, args);
    
      if (args != NULL) Py_DECREF(args);
    
      Py_DECREF(attr);
    
      if (PyErr_Occurred()) {
        NSLog(@"py_call_attr(%@) an error occurred\n", name);
        PyErr_Print();
        PyErr_Clear();
      }
      
    } while(NO);
    state = PyEval_SaveThread();
  }
  return res;
}

-(BOOL)voidcall:(PyObject*)obj symbol:(NSString*)name arguments:(PyObject*)args {
    
  BOOL status = NO;
  
  PyObject *attr=0L,*res=0L;

  @synchronized(self) {
    do {
      PyEval_RestoreThread(state);

      if (!obj && (obj = PyImport_AddModule("__main__")) == 0L)
        break ;
      if ((attr = PyObject_GetAttrString(obj, [name UTF8String])) == 0L)
        break ;
      if (!PyCallable_Check(attr))
        break ;

      res = PyObject_CallObject(attr, args);
        
      if (0L != res) Py_DECREF(res);
        
      if (args != NULL) Py_DECREF(args);
    
      if (attr != NULL) Py_DECREF(attr);
    
      if (PyErr_Occurred()) {
        NSLog(@"py_call_attr_void(%@) an error occurred\n", name);
        PyErr_Print();
        PyErr_Clear();
      }
      status = YES;
    } while(NO);
    state = PyEval_SaveThread();
  }
  return status;
}

-(void)register:(NSString*)module interface:(PyMethodDef*)def {
  @synchronized(self) {
    PyEval_RestoreThread(state);
    Py_InitModule([module UTF8String], def);
    state = PyEval_SaveThread();
  }
}

@end
