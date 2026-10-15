"""Screenshot routes of the Flutter web build in headless Chrome.

Usage (via shots.sh): shots.py <build_dir> <out_dir> name=/route [name=/route ...]
Serves <build_dir> as a single-page app, opens each route on a phone-sized
viewport, waits for Flutter to render, saves <out_dir>/<name>.png and prints
browser console errors. Each route is a fresh page load (in-memory state resets).
"""
import base64, http.server, json, os, socket, subprocess, sys, threading, time, urllib.request

import websocket  # installed by shots.sh

CHROME = os.environ.get("CHROME", "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome")
WAIT = float(os.environ.get("SHOT_WAIT", "10"))


def free_port():
    s = socket.socket(); s.bind(("127.0.0.1", 0)); p = s.getsockname()[1]; s.close(); return p


def serve(root, port):
    class H(http.server.SimpleHTTPRequestHandler):
        def __init__(self, *a, **k): super().__init__(*a, directory=root, **k)
        def do_GET(self):
            if not os.path.isfile(os.path.join(root, self.path.split("?")[0].lstrip("/"))):
                self.path = "/index.html"
            return super().do_GET()
        def log_message(self, *a): pass
    srv = http.server.ThreadingHTTPServer(("127.0.0.1", port), H)
    threading.Thread(target=srv.serve_forever, daemon=True).start()


def main():
    build, out, routes = sys.argv[1], sys.argv[2], sys.argv[3:]
    os.makedirs(out, exist_ok=True)
    web, dbg = free_port(), free_port()
    serve(build, web)
    chrome = subprocess.Popen([CHROME, "--headless=new", f"--remote-debugging-port={dbg}", "--remote-allow-origins=*",
                               f"--user-data-dir={out}/.chrome", "--window-size=412,860", "about:blank"],
                              stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    try:
        for _ in range(50):
            try:
                tabs = json.load(urllib.request.urlopen(f"http://127.0.0.1:{dbg}/json")); break
            except Exception: time.sleep(0.2)
        ws = websocket.create_connection([t for t in tabs if t["type"] == "page"][0]["webSocketDebuggerUrl"])
        n = [0]

        def call(method, **params):
            n[0] += 1; ws.send(json.dumps({"id": n[0], "method": method, "params": params}))
            while True:
                m = json.loads(ws.recv())
                log(m)
                if m.get("id") == n[0]: return m

        def log(m):
            if m.get("method") == "Runtime.exceptionThrown":
                print("  EXCEPTION:", json.dumps(m["params"]["exceptionDetails"])[:300])
            elif m.get("method") == "Runtime.consoleAPICalled" and m["params"]["type"] in ("error", "warning"):
                print("  console:", " ".join(str(a.get("value", a.get("description", ""))) for a in m["params"]["args"])[:300])

        call("Runtime.enable"); call("Page.enable")
        call("Emulation.setDeviceMetricsOverride", width=412, height=860, deviceScaleFactor=2, mobile=True)
        for r in routes:
            name, route = r.split("=", 1)
            call("Page.navigate", url=f"http://127.0.0.1:{web}{route}")
            end = time.time() + WAIT; ws.settimeout(0.5)
            while time.time() < end:
                try: log(json.loads(ws.recv()))
                except Exception: pass
            ws.settimeout(None)
            png = call("Page.captureScreenshot", format="png")["result"]["data"]
            path = os.path.join(out, f"{name}.png")
            open(path, "wb").write(base64.b64decode(png))
            print("saved", path)
    finally:
        chrome.terminate()


if __name__ == "__main__":
    main()
