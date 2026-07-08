#!/usr/bin/env python3
"""
TCO AI Helper — lets the TCO Agreement Generator draft with YOUR Claude
subscription (no API key).

How it works: this tiny program listens on your own computer only
(http://127.0.0.1:8765). When you click "Draft with Claude" in the app, the
app hands the notes to this helper, and the helper asks Claude through the
Claude Code command ("claude"), which is signed in with your Claude account.

One-time setup:
  1. Install Claude Code from https://claude.ai/download and sign in once
     with your Claude account (your subscription covers it).
  2. Start this helper (double-click "Start TCO AI Helper.bat" on Windows,
     or run:  python3 tco_ai_helper.py  on Mac).
  3. Leave the window open while you use the app.
"""
import json
import subprocess
from http.server import BaseHTTPRequestHandler, HTTPServer

PORT = 8765


def run_claude(prompt):
    try:
        p = subprocess.run(
            ["claude", "-p", "--output-format", "text"],
            input=prompt, capture_output=True, text=True, timeout=300,
        )
        if p.returncode != 0:
            return None, (p.stderr or "claude exited with an error").strip()[:400]
        return p.stdout, None
    except FileNotFoundError:
        return None, ("Claude Code is not installed (command 'claude' not found). "
                      "Install it from https://claude.ai/download and sign in once.")
    except subprocess.TimeoutExpired:
        return None, "Claude took too long to answer. Try again."


class Handler(BaseHTTPRequestHandler):
    def _cors(self):
        self.send_header("Access-Control-Allow-Origin", "*")
        self.send_header("Access-Control-Allow-Methods", "GET,POST,OPTIONS")
        self.send_header("Access-Control-Allow-Headers", "Content-Type")

    def _json(self, code, obj):
        body = json.dumps(obj).encode("utf-8")
        self.send_response(code)
        self._cors()
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def do_OPTIONS(self):
        self.send_response(204)
        self._cors()
        self.end_headers()

    def do_GET(self):
        if self.path == "/health":
            self._json(200, {"ok": True, "service": "tco-ai-helper"})
        else:
            self._json(404, {"ok": False, "error": "not found"})

    def do_POST(self):
        if self.path != "/draft":
            self._json(404, {"ok": False, "error": "not found"})
            return
        n = int(self.headers.get("Content-Length") or 0)
        prompt = self.rfile.read(n).decode("utf-8", errors="replace")
        if not prompt.strip():
            self._json(400, {"ok": False, "error": "empty prompt"})
            return
        print("  … drafting with Claude (this can take up to a minute)")
        text, err = run_claude(prompt)
        if err is None:
            print("  ✓ draft returned to the app")
            self._json(200, {"ok": True, "text": text})
        else:
            print("  ✗ " + err)
            self._json(500, {"ok": False, "error": err})

    def log_message(self, *args):  # keep the window quiet
        pass


if __name__ == "__main__":
    print("TCO AI Helper is running at http://127.0.0.1:%d" % PORT)
    print("It only accepts connections from this computer.")
    print("It drafts using YOUR Claude subscription via Claude Code ('claude').")
    print("Leave this window open while you use the TCO Agreement Generator.")
    print("Press Ctrl+C to stop.")
    try:
        HTTPServer(("127.0.0.1", PORT), Handler).serve_forever()
    except KeyboardInterrupt:
        print("\nStopped.")
