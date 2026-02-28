"""Simple HTTP server with COOP/COEP headers for Godot 4 web export.
Run from the export folder: python serve.py
Then open http://localhost:8060 in your browser.
"""
import http.server
import sys

PORT = 8060

class CoopCoepHandler(http.server.SimpleHTTPRequestHandler):
    def end_headers(self):
        self.send_header("Cross-Origin-Opener-Policy", "same-origin")
        self.send_header("Cross-Origin-Embedder-Policy", "require-corp")
        super().end_headers()

if __name__ == "__main__":
    d = sys.argv[1] if len(sys.argv) > 1 else "."
    with http.server.HTTPServer(("", PORT), lambda *a: CoopCoepHandler(*a, directory=d)) as s:
        print(f"Serving {d} at http://localhost:{PORT}")
        s.serve_forever()
