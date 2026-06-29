import http.server
import socketserver

class COOPCOEPHandler(http.server.SimpleHTTPRequestHandler):
    def end_headers(self):
        self.send_header("Cross-Origin-Opener-Policy", "same-origin")
        self.send_header("Cross-Origin-Embedder-Policy", "require-corp")
        self.send_header("Cross-Origin-Resource-Policy", "cross-origin")
        self.send_header("Cache-Control", "no-store, no-cache, must-revalidate, max-age=0")
        self.send_header("Pragma", "no-cache")
        self.send_header("Expires", "0")
        super().end_headers()

if __name__ == "__main__":
    with socketserver.TCPServer(("", 8000), COOPCOEPHandler) as httpd:
        httpd.allow_reuse_address = True
        print("Servindo em http://localhost:8000 com headers COOP/COEP (DuckDB multi-thread)")
        httpd.serve_forever()
