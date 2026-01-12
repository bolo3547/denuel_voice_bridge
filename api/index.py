"""
Vercel Serverless Entry Point
"""

from http.server import BaseHTTPRequestHandler
import json

class handler(BaseHTTPRequestHandler):
    def do_GET(self):
        self.send_response(200)
        self.send_header('Content-type', 'application/json')
        self.end_headers()
        
        if self.path == '/health':
            response = {"status": "ok", "version": "2.0.0"}
        elif self.path == '/billing/plans':
            response = [
                {"tier": "free", "name": "Free", "price": 0},
                {"tier": "pro", "name": "Pro", "price": 29.99},
                {"tier": "enterprise", "name": "Enterprise", "price": 299.99}
            ]
        else:
            response = {
                "status": "ok",
                "service": "Denuel Voice Bridge API",
                "version": "2.0.0",
                "platform": "vercel",
                "endpoints": ["/health", "/billing/plans"]
            }
        
        self.wfile.write(json.dumps(response).encode())
    
    def do_POST(self):
        self.send_response(200)
        self.send_header('Content-type', 'application/json')
        self.end_headers()
        response = {"message": "POST received", "path": self.path}
        self.wfile.write(json.dumps(response).encode())
