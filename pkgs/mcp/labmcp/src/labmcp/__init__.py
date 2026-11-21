"""Shared plumbing for the nix-labs MCP servers.

The parts of docs/MCP-RULES.md that are code rather than judgement, so every
server we write gets them the same way:

    import labmcp

    labmcp.protect_stdout()  # first: before anything that loads native code

    mcp = labmcp.server("cad", instructions="…")  # unknown arguments are rejected
    FILES = labmcp.Workspace.from_env("MCP_CAD_WORKDIR")


    @mcp.tool(title="Measure", annotations=labmcp.RUNS_CODE)
    def measure(...): ...

Importing this module loads only Python code (mcp, pydantic) and writes
nothing to stdout, so it may come before `protect_stdout()`.
"""

from __future__ import annotations

import io
import os
import sys
from pathlib import Path

from mcp.server.fastmcp import FastMCP
from mcp.types import ToolAnnotations

__all__ = [
    "OBSERVES",
    "READ_ONLY",
    "RECORDS",
    "RUNS_CODE",
    "WRITES_FILES",
    "Workspace",
    "protect_stdout",
    "server",
]


def protect_stdout() -> None:
    """Keep file descriptor 1 for the protocol alone.

    Over stdio, stdout carries JSON-RPC, and one stray line corrupts the
    session. Native libraries (OpenCASCADE, SoapySDR's driver modules) write
    to fd 1 on their own initiative, which no Python-level redirect catches.
    So fd 1 is pointed at stderr, and the real stdout is handed to Python as
    `sys.stdout` for the MCP transport. Call it before importing anything that
    loads native code, and never print() to stdout afterwards.
    """
    real_stdout_fd = os.dup(1)
    os.dup2(2, 1)  # C-level writes to fd 1 now land on stderr
    sys.stdout = io.TextIOWrapper(
        io.FileIO(real_stdout_fd, "w", closefd=True),
        encoding="utf-8",
        line_buffering=True,
    )


def _forbid_unknown_arguments() -> None:
    # FastMCP validates each tool's arguments with a pydantic model built on
    # ArgModelBase, which drops keys it does not know: a misspelt `gain_db`
    # silently falls back to the default, and the model never learns. There is
    # no public switch (mcp 1.26), so forbid extras on the base before any tool
    # is registered; the models FastMCP derives from it inherit the setting.
    # If an SDK release moves this, the import fails loudly, and
    # checks/mcp-smoke.nix catches a server that accepts unknown keys again.
    from mcp.server.fastmcp.utilities import func_metadata

    base = func_metadata.ArgModelBase
    base.model_config = {**base.model_config, "extra": "forbid"}


def server(name: str, instructions: str) -> FastMCP:
    """A FastMCP server that rejects unknown tool arguments, naming the key."""
    _forbid_unknown_arguments()
    return FastMCP(name, instructions=instructions)


class Workspace:
    """The one directory a server may read and write, and nothing outside it.

    Paths from the model are relative to the root, or absolute beneath it.
    Symlinks are resolved before the check, and `..` cannot climb out. This
    guards against mistakes and prompt-injected paths. It is not a sandbox
    for code the server executes on the model's behalf (see RUNS_CODE).
    """

    def __init__(self, root: Path, env_var: str | None = None) -> None:
        self.root = root.resolve()
        self._env_var = env_var

    @classmethod
    def from_env(cls, env_var: str) -> Workspace:
        """Root from `env_var`, else the working directory: MCP clients start
        stdio servers in the project, so that is where files belong."""
        return cls(Path(os.environ.get(env_var) or os.getcwd()), env_var)

    def path(self, path: str | os.PathLike[str]) -> Path:
        """Resolve `path` inside the workspace, or refuse it."""
        p = Path(path)
        target = (p if p.is_absolute() else self.root / p).resolve()
        if not target.is_relative_to(self.root):
            moved_by = f" (the server's {self._env_var} sets it)" if self._env_var else ""
            raise ValueError(
                f"`{path}` is outside the workspace {self.root}{moved_by}; "
                "use a path relative to it"
            )
        return target


def _hints(*, read_only: bool, destructive: bool, idempotent: bool, open_world: bool) -> ToolAnnotations:
    return ToolAnnotations(
        readOnlyHint=read_only,
        destructiveHint=destructive,
        idempotentHint=idempotent,
        openWorldHint=open_world,
    )


# Every tool carries all four hints, chosen from these presets so that the same
# behaviour is always described the same way. Clients use them to decide what
# runs without asking. When in doubt, pick the more cautious preset.

#: Looks something up: no side effects, and the same answer twice.
READ_ONLY = _hints(read_only=True, destructive=False, idempotent=True, open_world=False)

#: Reads the outside world (a radio, a bus): no side effects, but the answer changes.
OBSERVES = _hints(read_only=True, destructive=False, idempotent=False, open_world=True)

#: Writes into the workspace, replacing files of the same name; same input, same files.
WRITES_FILES = _hints(read_only=False, destructive=True, idempotent=True, open_world=False)

#: Observes the outside world and writes what it saw into the workspace.
RECORDS = _hints(read_only=False, destructive=True, idempotent=False, open_world=True)

#: Executes code the caller supplied, whatever the tool is for: assume it can
#: do anything the user running the server can. Never present it as read-only.
RUNS_CODE = _hints(read_only=False, destructive=True, idempotent=False, open_world=True)
