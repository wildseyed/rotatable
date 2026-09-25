#!/usr/bin/env python3
"""REST testing API for rotatable — runs on the desktop, forwards to the
norns matron REPL via tools/deploy.py's websocket channel.

    python3 tools/api.py [port]        # default 8787

Endpoints (JSON in/out):
  GET  /state                     level, objects, connections, amps
  POST /place    {"type":"filter","x":0.3,"y":0.1,"angle":1.0}
  POST /move     {"id":2,"x":0.4,"y":0.2}
  POST /rotate   {"id":2,"angle":3.1}
  POST /key      {"n":3,"z":1}    (drive UI keys like hands)
  POST /enc      {"n":2,"d":5}
  POST /mute     {"a":1,"b":2}
  POST /remove   {"id":2}
  POST /clear
  POST /lua      {"code":"..."}   single-chunk escape hatch (ordered)
  GET  /amps
"""
import json, sys, re
from http.server import BaseHTTPRequestHandler, HTTPServer
sys.path.insert(0, __file__.rsplit("/", 1)[0])
from deploy import creds, ws_run

HOST, USER, PW = creds()

def run_lua(code, timeout=8):
    out = ws_run(HOST, code, timeout=timeout)
    text = "".join(out)
    if "lua:" in text and "error" in text.lower():
        raise RuntimeError(text.strip()[:400])
    return text

def state():
    text = run_lua("T.state()")
    m = re.search(r"\{.*\}", text, re.S)
    if not m:
        raise RuntimeError("no state in reply: " + text[:200])
    return json.loads(m.group(0))

ACTIONS = {
    "/place":  lambda p: "T.add('%s', %s, %s, %s)" % (
        p["type"], p.get("x", 0), p.get("y", 0), p.get("angle", 0)),
    "/move":   lambda p: "T.move(%d, %s, %s)" % (p["id"], p["x"], p["y"]),
    "/rotate": lambda p: "T.rot(%d, %s)" % (p["id"], p["angle"]),
    "/set":    lambda p: "T.set(%d, '%s', %s)" % (
        p["id"], p["param"],
        ("'%s'" % p["value"]) if isinstance(p["value"], str) else p["value"]),
    "/load":   lambda p: "T.load(%d, '%s')" % (p["id"], p["path"]),
    "/step":   lambda p: "T.step(%d, %d, %s, %s, %s)" % (
        p["id"], p["step"],
        str(p["on"]).lower() if "on" in p else "nil",
        p.get("pitch", "nil"), p.get("vel", "nil")),
    "/key":    lambda p: "T.key(%d, %d)" % (p["n"], p["z"]),
    "/enc":    lambda p: "T.enc(%d, %d)" % (p["n"], p["d"]),
    "/mute":   lambda p: "T.mute(%d, %d)" % (p["a"], p["b"]),
    "/remove": lambda p: "T.remove(%d)" % p["id"],
    "/clear":  lambda p: "T.clear()",
    "/lua":    lambda p: p["code"],
}

class Handler(BaseHTTPRequestHandler):
    def _send(self, code, obj):
        body = json.dumps(obj).encode()
        self.send_response(code)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def _body(self):
        n = int(self.headers.get("Content-Length", 0))
        return json.loads(self.rfile.read(n) or b"{}")

    def do_GET(self):
        try:
            if self.path == "/state":
                self._send(200, state())
            elif self.path == "/amps":
                text = run_lua("T.amps()")
                m = re.search(r"amp_l=([\d.]+) amp_r=([\d.]+)", text)
                self._send(200, {"amp_l": float(m.group(1)), "amp_r": float(m.group(2))})
            else:
                self._send(404, {"error": "unknown endpoint"})
        except Exception as e:
            self._send(500, {"error": str(e)})

    def do_POST(self):
        try:
            if self.path not in ACTIONS:
                self._send(404, {"error": "unknown endpoint"})
                return
            payload = self._body()
            result = run_lua(ACTIONS[self.path](payload))
            reply = {"ok": True}
            m = re.search(r"\{.*\}", result, re.S)
            if self.path == "/lua" and m:
                reply["result"] = result.strip()[:2000]
            self._send(200, reply)
        except Exception as e:
            self._send(500, {"error": str(e)})

    def log_message(self, *a):
        pass

if __name__ == "__main__":
    port = int(sys.argv[1]) if len(sys.argv) > 1 else 8787
    print(f"rotatable api on http://localhost:{port} (norns at {HOST})")
    HTTPServer(("127.0.0.1", port), Handler).serve_forever()
