#/********************************************************************************************/
#/*    isopod.py. Very tiny ssl app server                                                   */
#/*    http://www.assertfail.org                                                             */
#/*                                                                                          */
#/* Copyright (c) sheepresearch 2016                                                         */
#/* All rights reserved.                                                                     */
#/*                                                                                          */
#/* Redistribution and use in source and binary forms, with or without modification,         */
#/* are permitted provided that the following conditions are met:                            */
#/*                                                                                          */
#/*     1. Redistributions of source code must retain the above copyright notice,            */
#/*        this list of conditions and the following disclaimer.                             */
#/*                                                                                          */
#/*     2. Redistributions in binary form must reproduce the above copyright notice,         */
#/*        this list of conditions and the following disclaimer in the documentation         */
#/*        and/or other materials provided with the distribution.                            */
#/*                                                                                          */
#/*     3. Neither the name assertfail.org nor the names of its                              */
#/*        contributors may be used to endorse or promote products derived from this         */
#/*        software without specific prior written permission.                               */
#/*                                                                                          */
#/* THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY      */
#/* EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF  */
#/* MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL   */
#/* THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,     */
#/* SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT */
#/* OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)*/
#/* HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY,    */
#/* OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS    */
#/* SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.                             */
#/*                                                                                          */
#/********************************************************************************************/

import os
import BaseHTTPServer
import SimpleHTTPServer
import SocketServer
import Cookie
import threading
import mimetypes
import urllib
import socket
import ssl
import json
import time
import uuid
import atexit
import signal
import random

from datetime import datetime, timedelta
from urlparse import urlparse

#//------------------------------------------------------------------------------------------------

class RequestHandler(BaseHTTPServer.BaseHTTPRequestHandler):
    def setup(self):
        self.connection = self.request
        self.rfile = socket._fileobject(self.request, "rb", self.rbufsize)
        self.wfile = socket._fileobject(self.request, "wb", self.wbufsize)
        self.app = self.server.app
        self.method = None

    def do_HEAD(self):
        if self.headers.has_key("cookie"):
            c = Cookie.SimpleCookie( self.headers.getheader("cookie") );
            if c.has_key("session") and not c["session"].value == None:
                self.session = self.app.getsession(c["session"].value)

    def do_GET(self):
        self.do_HEAD()
        route = self.app.routefor(self.path)
        if route:
            return route().get(self)
        self.send_error(404, "Resource not found: " +self.path)

    def do_POST(self):
        self.do_HEAD()
        route = self.app.routefor(self.path)
        if route:
            return route().post(self)
        self.send_error(404, "Resource not found: " +self.path)

#//------------------------------------------------------------------------------------------------

class HTTPServer(SocketServer.ThreadingMixIn, BaseHTTPServer.HTTPServer):
    def __init__(self, address, app, keyfile=None, certificate=None):
        self.app = app;
        BaseHTTPServer.HTTPServer.__init__(self, address, RequestHandler)
        socket_ = socket.socket(self.address_family, self.socket_type)
        if keyfile and certificate:
            self.socket = ssl.SSLSocket(socket_, keyfile=keyfile, certfile=certificate)
        else:
            self.socket = socket_
        self.server_bind()
        self.server_activate()

#//------------------------------------------------------------------------------------------------
#//------------------------------------------------------------------------------------------------
#//------------------------------------------------------------------------------------------------

class method:
    def __init__(self, typ):
        self.typ = typ
    def __call__(self, fn):
        fn.method_ = self.typ
        fn.bound_  = True
        return fn

class app(object):
    IDLE_INTERVAL=5.0
    POLL_INTERVAL=0.1
    def __init__(self, identifier=""):
        self.identifier = identifier
        self.keyfile = None
        self.certificate = None
        self.routes = {}
        self.sessions = {}
        self.terminated = False
        self.idletask = []
    def ssl(self, keyfile=None, certificate=None, enable=True):
        if enable:
            self.keyfile = keyfile
            self.certificate = certificate
    def mount(self, path, clz):
        self.routes[path] = clz
    def routefor(self, path):
        for key,route in self.routes.items():
            if key.endswith("*") and path.startswith(key[:-1]):
                return route
            elif key == path:
                return route
        return None

    def addidle(self, task):
        self.idletask.append(task)

    def shutdown(self, *args):
        print "TERMINATED"
        self.terminated = True

    def getsession(self, sessionid=None):
        if not sessionid == None and self.sessions.has_key(sessionid):
            return self.sessions[sessionid]
        sessionid = str(uuid.uuid4())
        self.sessions[sessionid] = {"created": time.time(), "id": sessionid}
        return self.sessions[sessionid]

    def run(self, hostname, port=8080, console=True):
        server = HTTPServer((hostname, port), self, self.keyfile, self.certificate)

        server_thread = threading.Thread(target=server.serve_forever)
        server_thread.daemon = True
        server_thread.start()
        tm = app.IDLE_INTERVAL
        if console:
            signal.signal(signal.SIGINT, self.shutdown)
        print "Application started..."
        while not self.terminated:
            tm -= app.POLL_INTERVAL
            time.sleep(app.POLL_INTERVAL)
            # post main loop, deal with idle tasks.
            if tm > 0:
                continue
            for task in self.idletask: task()
            tm = app.IDLE_INTERVAL
        print "Application exited.."
        print "Shutdown server.."
        server.shutdown()
        server.server_close()

#//------------------------------------------------------------------------------------------------

class route(object):
    def __init__(self, path=None):
        self.path = path
    def get(self, req):
        if self.path and req.path.startswith("/%s" % self.path):
             return self.call_(req, "GET")
        req.send_error(404, "Resource not found: " + req.path)
    def post(self, req):
        if self.path and req.path.startswith("/%s" % self.path):
            return self.call_(req, "POST")
        req.send_error(404, "Resource not found: " + req.path)
    def call_(self, req, typ_):
        args = req.path[1:].split("/")[1:]
        if len(args) > 0 and hasattr(self, args[0]):
            if callable(getattr(self, args[0])):
                fn = getattr(self, args[0]);
                if hasattr(fn, "bound_") and fn.method_ == typ_:
                    return fn(req,args[1:])
        req.send_error(400, "Resource Not Found: " + req.path)
    def accept(self, req, contenttype):
        if req.headers.getheader("content-type") == contenttype:
            return True
        req.send_error(400, "Invalid format: !" + contenttype);
        return False
    def recv(self, req):
        if req.headers.has_key("content-length"):
            return req.rfile.read(int(req.headers.getheader("content-length")))
        return ""
    def recvobj(self, req):
        try:
            if self.accept(req, "application/json"):
                return json.loads(self.recv(req))
        except: pass
        return {}
    def sendobj(self, req, obj):
        self.sendjson(req, json.dumps(obj))
    def sendjson(self, req, data):
        req.send_response(200)
        req.send_header("Content-Type", "application/json")
        req.send_header("Content-Length", str(len(data)))
        req.end_headers()
        req.wfile.write(data)
    def sendfile(self, req, path, mimetype=None):
        if mimetype == None:
            mimetype, encoding = mimetypes.guess_type(path)
        fp = None
        try:
            fp = open(path, "r")
            fi = os.fstat(fp.fileno())
            req.send_response(200)
            req.send_header("Content-Type", mimetype);
            req.send_header("Content-Length", str(fi.st_size))
            req.end_headers()
            req.wfile.write(fp.read())
        except Exception, err:
            req.send_error(500, "Internal server error: " + req.path)
            raise
        finally:
            if fp != None: fp.close()
