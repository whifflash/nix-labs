"""Speak MCP over stdio to every server this flake builds, the way a client does.

Usage: mcp-smoke.py <servers.json>, a list of {name, command, args, env, strict}.

Every server must keep stdout to JSON-RPC alone, answer `initialize` and list
its tools. A `strict` server is also held to the rest of docs/MCP-RULES.md:
instructions, a title and all four hints on every tool, and an unknown argument
rejected by name. The probe goes to a read-only tool without required arguments,
so a server that wrongly accepts the key does nothing worse than a lookup.

No tool does real work here: no hardware, no network, no files.
"""

from __future__ import annotations

import json
import os
import select
import subprocess
import sys
import tempfile
import time

REPLY_TIMEOUT = 120  # seconds; first start of a Python server can be slow
HINTS = ("readOnlyHint", "destructiveHint", "idempotentHint", "openWorldHint")
UNKNOWN_KEY = "nix_labs_smoke_unknown_argument"


class Failure(Exception):
    pass


class Session:
    def __init__(self, spec: dict, workdir: str) -> None:
        env = dict(os.environ, HOME=workdir, XDG_CACHE_HOME=workdir, MPLCONFIGDIR=workdir, **spec["env"])
        self.stderr = open(os.path.join(workdir, "stderr.log"), "w+")
        self.proc = subprocess.Popen(
            [spec["command"], *spec["args"]],
            cwd=workdir,
            env=env,
            stdin=subprocess.PIPE,
            stdout=subprocess.PIPE,
            stderr=self.stderr,
            text=True,
        )
        self.next_id = 0
        self.stray: list[str] = []
        # stdout is read unbuffered with our own line splitting: select() sees
        # only the OS pipe, so lines already pulled into a Python buffer (two
        # messages in one write) would otherwise wait for data that never comes.
        self._fd = self.proc.stdout.fileno()
        self._pending = b""

    def _read_line(self, deadline: float) -> str | None:
        while b"\n" not in self._pending:
            remaining = deadline - time.monotonic()
            if remaining <= 0 or not select.select([self._fd], [], [], remaining)[0]:
                return None
            chunk = os.read(self._fd, 65536)
            if not chunk:  # EOF: hand back what is left, if anything
                line, self._pending = self._pending, b""
                return line.decode(errors="replace") or None
            self._pending += chunk
        line, self._pending = self._pending.split(b"\n", 1)
        return line.decode(errors="replace") + "\n"

    def _take(self, line: str) -> dict | None:
        try:
            message = json.loads(line)
        except ValueError:
            message = None
        if not isinstance(message, dict) or message.get("jsonrpc") != "2.0":
            self.stray.append(line.rstrip("\n")[:120])
            return None
        return message

    def notify(self, method: str) -> None:
        self.proc.stdin.write(json.dumps({"jsonrpc": "2.0", "method": method}) + "\n")
        self.proc.stdin.flush()

    def request(self, method: str, params: dict) -> dict:
        self.next_id += 1
        msg = {"jsonrpc": "2.0", "id": self.next_id, "method": method, "params": params}
        self.proc.stdin.write(json.dumps(msg) + "\n")
        self.proc.stdin.flush()
        deadline = time.monotonic() + REPLY_TIMEOUT
        while True:
            line = self._read_line(deadline)
            if not line:
                raise Failure(f"no reply to {method} within {REPLY_TIMEOUT}s (exit code {self.proc.poll()})")
            message = self._take(line)
            if message is not None and message.get("id") == self.next_id:
                return message

    def close(self) -> None:
        self.proc.stdin.close()
        deadline = time.monotonic() + 5
        while line := self._read_line(deadline):
            self._take(line)  # output after the last reply counts too
        self.proc.kill()
        self.proc.wait()

    def stderr_tail(self) -> str:
        self.stderr.seek(0)
        return "".join(self.stderr.readlines()[-15:])


def check(spec: dict) -> list[str]:
    problems: list[str] = []
    with tempfile.TemporaryDirectory() as workdir:
        s = Session(spec, workdir)
        try:
            init = s.request(
                "initialize",
                {"protocolVersion": "2025-06-18", "capabilities": {}, "clientInfo": {"name": "mcp-smoke", "version": "0"}},
            )
            if "result" not in init:
                raise Failure(f"initialize failed: {json.dumps(init)[:300]}")
            s.notify("notifications/initialized")
            listed = s.request("tools/list", {})
            tools = listed.get("result", {}).get("tools") or []
            if not tools:
                raise Failure(f"tools/list returned no tools: {json.dumps(listed)[:300]}")

            if spec["strict"]:
                if not init["result"].get("instructions"):
                    problems.append("no `instructions` in the initialize result")
                for tool in tools:
                    hints = tool.get("annotations") or {}
                    if not (tool.get("title") or hints.get("title")):
                        problems.append(f"tool {tool['name']}: no title")
                    missing = [h for h in HINTS if not isinstance(hints.get(h), bool)]
                    if missing:
                        problems.append(f"tool {tool['name']}: missing {', '.join(missing)}")

                probe = next(
                    (
                        t
                        for t in tools
                        if (t.get("annotations") or {}).get("readOnlyHint") is True
                        and not (t.get("inputSchema") or {}).get("required")
                    ),
                    None,
                )
                if probe is None:
                    problems.append("no read-only tool without required arguments to probe unknown-argument handling")
                else:
                    reply = s.request("tools/call", {"name": probe["name"], "arguments": {UNKNOWN_KEY: 1}})
                    refused = "error" in reply or reply.get("result", {}).get("isError") is True
                    if not (refused and UNKNOWN_KEY in json.dumps(reply)):
                        problems.append(f"tool {probe['name']}: accepted an unknown argument instead of rejecting it by name")
            s.close()
        except Failure as exc:
            s.close()
            problems.append(f"{exc}\n--- stderr (tail) ---\n{s.stderr_tail()}")
        if s.stray:
            problems.append("wrote non-JSON-RPC output to stdout: " + " | ".join(s.stray[:5]))
    return problems


def main() -> int:
    servers = json.load(open(sys.argv[1]))
    failed = False
    for spec in servers:
        problems = check(spec)
        level = "strict" if spec["strict"] else "basic"
        if problems:
            failed = True
            print(f"FAIL {spec['name']} ({level})")
            for p in problems:
                print(f"     - {p}")
        else:
            print(f"ok   {spec['name']} ({level})")
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main())
