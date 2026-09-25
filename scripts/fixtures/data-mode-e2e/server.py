"""数据模式 E2E 受控服务：记录每个请求；公开路线端点返回带标记的路线名。

参数：端口 请求日志路径 绑定地址（使用局域网地址，不绑定 0.0.0.0）。
"""
import json, sys, time
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

LOG = sys.argv[2]
MARK = "W6受控服务路线"
SUMMARY = {"routeId": "w6-route", "currentVersionId": "w6-route-v1", "cover": None, "name": MARK,
           "region": "受控环境", "difficulty": "1", "distance": {"meters": 1000},
           "ascent": {"meters": 10}, "estimatedDuration": {"seconds": 600}}

class H(BaseHTTPRequestHandler):
    def _log(self):
        with open(LOG, "a") as f:
            f.write(json.dumps({"t": time.time(), "method": self.command, "path": self.path,
                                "auth": bool(self.headers.get("Authorization"))}) + "\n")
    def do_GET(self):
        self._log()
        if self.path.split("?")[0].endswith("/public-routes/featured") or self.path.split("?")[0].endswith("/public-routes"):
            body = json.dumps({"data": {"items": [SUMMARY]}}).encode()
            self.send_response(200)
            self.send_header("Content-Type", "application/json")
            self.send_header("Cache-Control", "max-age=600")
            self.send_header("Content-Length", str(len(body)))
            self.end_headers(); self.wfile.write(body)
        else:
            body = json.dumps({"error": {"code": "not_found", "message": "w6"}}).encode()
            self.send_response(404); self.send_header("Content-Type", "application/json")
            self.send_header("Content-Length", str(len(body))); self.end_headers(); self.wfile.write(body)
    do_POST = do_GET
    def log_message(self, *a): pass

ThreadingHTTPServer((sys.argv[3], int(sys.argv[1])), H).serve_forever()
