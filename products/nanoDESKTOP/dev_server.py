import http.server
import socketserver
import urllib.request
import urllib.error
import sys
import os

PORT = int(sys.argv[1]) if len(sys.argv) > 1 else 3001
DIRECTORY = os.path.join(os.path.dirname(os.path.abspath(__file__)), 'ui')
BACKEND_URL = 'http://127.0.0.1:8080'

class ProxyAndStaticHandler(http.server.SimpleHTTPRequestHandler):
    def __init__(self, *args, **kwargs):
        super().__init__(*args, directory=DIRECTORY, **kwargs)

    def end_headers(self):
        self.send_header('Cache-Control', 'no-cache, no-store, must-revalidate')
        self.send_header('Pragma', 'no-cache')
        self.send_header('Expires', '0')
        super().end_headers()

    def do_OPTIONS(self):
        self.send_response(200)
        self.send_header('Access-Control-Allow-Origin', '*')
        self.send_header('Access-Control-Allow-Methods', 'GET, POST, PUT, DELETE, OPTIONS')
        self.send_header('Access-Control-Allow-Headers', 'Content-Type, Authorization, X-Requested-With')
        self.send_header('Content-Length', '0')
        self.end_headers()

    def _is_backend_route(self):
        p = self.path
        return (
            p.startswith('/api/') or
            p.startswith('/completion') or
            p.startswith('/health') or
            p.startswith('/readiness') or
            p.startswith('/liveness') or
            p.startswith('/cancel') or
            p.startswith('/benchmark')
        )

    def do_GET(self):
        if self._is_backend_route():
            self._proxy_request('GET')
        else:
            super().do_GET()

    def do_POST(self):
        if self._is_backend_route():
            self._proxy_request('POST')
        else:
            self.send_error(404, "Endpoint not found")

    def _proxy_request(self, method):
        target_url = f"{BACKEND_URL}{self.path}"
        content_length = int(self.headers.get('Content-Length', 0))
        body = self.rfile.read(content_length) if content_length > 0 else None

        req_headers = {}
        for k, v in self.headers.items():
            if k.lower() not in ('host', 'content-length'):
                req_headers[k] = v

        req = urllib.request.Request(target_url, data=body, headers=req_headers, method=method)
        try:
            with urllib.request.urlopen(req, timeout=120) as resp:
                self.send_response(resp.status)
                for header, value in resp.getheaders():
                    if header.lower() not in ('transfer-encoding', 'content-length', 'access-control-allow-origin'):
                        self.send_header(header, value)
                self.send_header('Access-Control-Allow-Origin', '*')
                
                # Check for streaming/chunked or regular content
                resp_data = resp.read()
                self.send_header('Content-Length', str(len(resp_data)))
                self.end_headers()
                self.wfile.write(resp_data)
        except urllib.error.HTTPError as e:
            err_data = e.read()
            self.send_response(e.code)
            self.send_header('Content-Type', 'application/json')
            self.send_header('Access-Control-Allow-Origin', '*')
            self.send_header('Content-Length', str(len(err_data)))
            self.end_headers()
            self.wfile.write(err_data)
        except Exception as e:
            err_body = f'{{"error": "{str(e)}", "backend_url": "{BACKEND_URL}"}}'.encode('utf-8')
            self.send_response(502)
            self.send_header('Content-Type', 'application/json')
            self.send_header('Access-Control-Allow-Origin', '*')
            self.send_header('Content-Length', str(len(err_body)))
            self.end_headers()
            self.wfile.write(err_body)

if __name__ == '__main__':
    socketserver.TCPServer.allow_reuse_address = True
    with socketserver.TCPServer(("", PORT), ProxyAndStaticHandler) as httpd:
        print(f"Serving nanoDESKTOP on port {PORT} with backend proxy to {BACKEND_URL}")
        httpd.serve_forever()
