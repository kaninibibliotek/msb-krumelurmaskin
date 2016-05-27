import sys
import os
import time
import isopod
import threading

app=None

#//------------------------------------------------------------------------------------------------------------

class serve_static_html(isopod.route):
    def get(self, req):
        fn = "%s%s" % (req.app.webdir, req.path)
        if not os.path.exists(fn) or os.path.isdir(fn):
            req.send_error(404, "Invalid path - Resource Not Found")
            return
        self.sendfile(req, fn)

class Krumelur(isopod.app):
    def __init__(self):
        isopod.app.__init__(self, "com.unswornindustries.krumelur")
    def start(self):
        t = threading.Thread(target=self.run, args=("localhost", 8881, False))
        t.start()

#//------------------------------------------------------------------------------------------------------------

def shutdown():
    global app
    print "Bye Bye"
    if app:
        app.shutdown()
    app = None
    
def main():
    global app
    webdir = os.path.dirname(os.path.dirname(__file__))
    webdir = os.path.join(webdir, "html")
    if not os.path.exists(webdir):
        print "Unable to locate webdir: %s" % __file__
        
    app = Krumelur();
    app.webdir = webdir
    app.mount("/*", serve_static_html)

    app.start()
    
if __name__ == "__main__":
    main()
    
