#!/usr/bin/env python3
"""Deploy rotatable/ to the norns and optionally load it via maiden's REPL.

Usage:
    python3 tools/deploy.py           # sync files only
    python3 tools/deploy.py --load    # sync + load script on device
    python3 tools/deploy.py --shot    # sync + load + pull a screenshot to /tmp/norns.png

Credentials: .device/norns-ip-address, .device/norns-ssh-credetials
"""
import os, sys, json, socket, base64, struct, time

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
REMOTE = "/home/we/dust/code/rotatable"
# publish layout: script lives at repo root; only these sync to the device
SYNC_FILES = ["rotatable.lua"]
SYNC_DIRS = ["lib"]

def creds():
    with open(os.path.join(ROOT, ".device/norns-ip-address")) as f:
        host = f.read().strip()
    user = pw = None
    with open(os.path.join(ROOT, ".device/norns-ssh-credetials")) as f:
        for line in f:
            if line.startswith("username:"):
                user = line.split(":", 1)[1].strip()
            elif line.startswith("password:"):
                pw = line.split(":", 1)[1].strip()
    return host, user, pw

def sync(host, user, pw):
    import paramiko
    c = paramiko.SSHClient()
    c.set_missing_host_key_policy(paramiko.AutoAddPolicy())
    c.connect(host, username=user, password=pw, timeout=10)
    sftp = c.open_sftp()
    try:
        sftp.mkdir(REMOTE)
    except IOError:
        pass
    n = 0
    for fn in SYNC_FILES:
        sftp.put(os.path.join(ROOT, fn), REMOTE + "/" + fn)
        n += 1
        print("put", fn)
    for d in SYNC_DIRS:
        base = os.path.join(ROOT, d)
        for dirpath, _, files in os.walk(base):
            rel = os.path.relpath(dirpath, ROOT)
            rdir = REMOTE + "/" + rel
            try:
                sftp.mkdir(rdir)
            except IOError:
                pass
            for fn in files:
                lp = os.path.join(dirpath, fn)
                sftp.put(lp, rdir + "/" + fn)
                n += 1
                print("put", os.path.relpath(lp, ROOT))
    c.close()
    print(f"{n} file(s) synced to {REMOTE}")

def ws_run(host, lua, timeout=8):
    """Send Lua to maiden's websocket REPL (port 5555) and return output lines."""
    key = base64.b64encode(os.urandom(16)).decode()
    s = socket.create_connection((host, 5555), timeout=timeout)
    req = (f"GET / HTTP/1.1\r\nHost: {host}:5555\r\nUpgrade: websocket\r\n"
           f"Connection: Upgrade\r\nSec-WebSocket-Key: {key}\r\n"
           f"Sec-WebSocket-Protocol: bus.sp.nanomsg.org\r\nSec-WebSocket-Version: 13\r\n\r\n")
    s.sendall(req.encode())
    resp = b""
    while b"\r\n\r\n" not in resp:
        resp += s.recv(4096)
    if b"101" not in resp.split(b"\r\n", 1)[0]:
        raise RuntimeError("maiden WS handshake failed: " + resp.decode(errors="replace")[:200])
    # read any leftover after headers
    buf = resp.split(b"\r\n\r\n", 1)[1]

    def send_text(text):
        payload = text.encode()
        mask = os.urandom(4)
        header = b"\x81"
        n = len(payload)
        if n < 126:
            header += bytes([0x80 | n])
        elif n < 65536:
            header += bytes([0x80 | 126]) + struct.pack(">H", n)
        else:
            header += bytes([0x80 | 127]) + struct.pack(">Q", n)
        masked = bytes(b ^ mask[i % 4] for i, b in enumerate(payload))
        s.sendall(header + mask + masked)

    def recv_msgs(deadline):
        nonlocal buf
        out = []
        while time.time() < deadline:
            s.settimeout(max(0.05, deadline - time.time()))
            try:
                chunk = s.recv(65536)
            except socket.timeout:
                break
            if not chunk:
                break
            buf += chunk
            while len(buf) >= 2:
                ln = buf[1] & 0x7F
                off = 2
                if ln == 126:
                    if len(buf) < 4: break
                    ln = struct.unpack(">H", buf[2:4])[0]; off = 4
                elif ln == 127:
                    if len(buf) < 10: break
                    ln = struct.unpack(">Q", buf[2:10])[0]; off = 10
                if len(buf) < off + ln: break
                payload = buf[off:off + ln]; buf = buf[off + ln:]
                opcode = buf[0] & 0x0F if False else None
                out.append(payload.decode(errors="replace"))
        return out

    send_text(lua + "\n")
    msgs = recv_msgs(time.time() + timeout)
    s.close()
    return msgs

def load_script(host):
    out = ws_run(host, "norns.script.load('code/rotatable/rotatable.lua')")
    print("maiden:", [m[:200] for m in out] or "(no reply)")

def screenshot(host, user, pw, dest="/tmp/norns.png"):
    # export_screenshot saves to ~/dust/data/<script>/<name>.png on device
    ws_run(host, "screen.export_screenshot('shot')", timeout=5)
    time.sleep(1.5)
    import paramiko
    c = paramiko.SSHClient()
    c.set_missing_host_key_policy(paramiko.AutoAddPolicy())
    c.connect(host, username=user, password=pw, timeout=10)
    c.open_sftp().get("/home/we/dust/data/rotatable/shot.png", dest)
    c.close()
    print("screenshot ->", dest)

if __name__ == "__main__":
    host, user, pw = creds()
    sync(host, user, pw)
    if "--load" in sys.argv or "--shot" in sys.argv:
        try:
            load_script(host)
        except Exception as e:
            print("WARN: auto-load failed:", e)
            print("Load manually: SELECT > rotatable on the device (or maiden REPL: norns.script.load('code/rotatable/rotatable.lua'))")
    if "--shot" in sys.argv:
        try:
            screenshot(host, user, pw)
        except Exception as e:
            print("WARN: screenshot failed:", e)
