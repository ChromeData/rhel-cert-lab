#!/usr/bin/env python3
"""
Local server for the practice exam.

Serves exam.html and — because a browser cannot launch a terminal on its own — exposes
a couple of endpoints the page calls to open a PowerShell window already SSH'd into a
lab node.

    python serve.py            then open http://127.0.0.1:8899/

Everything is bound to 127.0.0.1. Nothing is reachable off this machine.
"""
import http.server, socketserver, subprocess, os, sys, json, shutil, platform

PORT = 8899
HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.dirname(HERE)

# Where the lab lives. Override with LAB_DIR if you moved it.
LAB = os.environ.get("LAB_DIR", r"C:\rhcsa")

NODES = {
    "node1": {"port": 2201, "title": "node1 - system under test"},
    "node2": {"port": 2202, "title": "node2 - second system"},
}


def launch_terminal(node):
    """Open a real terminal window connected to the node. Windows-first, with
    sensible fallbacks so the page still works on Linux/macOS hosts."""
    info = NODES.get(node)
    if not info:
        return False, f"unknown node: {node}"

    key = os.path.join(LAB, ".ssh", "lab_key")
    if not os.path.exists(key):
        key = os.path.join(REPO, ".ssh", "lab_key")
    ssh = (f'ssh -i "{key}" -o StrictHostKeyChecking=no '
           f'-o UserKnownHostsFile=/dev/null -o LogLevel=ERROR '
           f'-p {info["port"]} root@127.0.0.1')

    try:
        if platform.system() == "Windows":
            ps1 = os.path.join(LAB, f"{node}.ps1")
            if os.path.exists(ps1):
                subprocess.Popen(["powershell.exe", "-NoExit", "-ExecutionPolicy",
                                  "Bypass", "-File", ps1])
            else:
                subprocess.Popen(["powershell.exe", "-NoExit", "-Command", ssh])
        else:
            for term in ("gnome-terminal", "konsole", "xterm"):
                if shutil.which(term):
                    subprocess.Popen([term, "-e", ssh]); break
            else:
                return False, "no terminal emulator found"
        return True, f"opened {node}"
    except Exception as e:                       # noqa: BLE001 - surface it to the page
        return False, str(e)


class Handler(http.server.SimpleHTTPRequestHandler):
    def __init__(self, *a, **kw):
        super().__init__(*a, directory=HERE, **kw)

    def _json(self, code, payload):
        body = json.dumps(payload).encode()
        self.send_response(code)
        self.send_header("Content-Type", "application/json")
        self.send_header("Access-Control-Allow-Origin", "*")   # so a file:// page can call us
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def do_GET(self):
        if self.path.startswith("/launch/"):
            node = self.path.rsplit("/", 1)[-1]
            ok, msg = launch_terminal(node)
            return self._json(200 if ok else 500, {"ok": ok, "msg": msg})
        if self.path == "/":
            self.path = "/exam.html"
        return super().do_GET()

    def log_message(self, fmt, *args):
        pass                                     # keep the console quiet


if __name__ == "__main__":
    socketserver.TCPServer.allow_reuse_address = True
    with socketserver.TCPServer(("127.0.0.1", PORT), Handler) as httpd:
        print(f"  Practice exam:  http://127.0.0.1:{PORT}/")
        print(f"  Lab directory:  {LAB}")
        print("  Ctrl-C to stop.")
        try:
            httpd.serve_forever()
        except KeyboardInterrupt:
            print("\n  stopped.")
