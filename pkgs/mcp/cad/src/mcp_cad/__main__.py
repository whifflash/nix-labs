"""MCP server for parametric CAD: build123d scripts in, solids and pictures out.

Transport is stdio JSON-RPC, so **stdout belongs to the protocol**. OpenCASCADE
and its Python bindings write to file descriptor 1 on their own initiative, which
would corrupt every message — so fd 1 is pointed at stderr before anything else
and the real stdout is handed to Python for the MCP transport. Do not print() to
stdout anywhere in this package.
"""

from __future__ import annotations

import io
import os
import sys


def _protect_stdout() -> None:
    real_stdout_fd = os.dup(1)
    os.dup2(2, 1)  # C-level writes to fd 1 now land on stderr
    sys.stdout = io.TextIOWrapper(
        io.FileIO(real_stdout_fd, "w", closefd=True),
        encoding="utf-8",
        line_buffering=True,
    )


_protect_stdout()

import inspect  # noqa: E402
import json  # noqa: E402
import shutil  # noqa: E402
import subprocess  # noqa: E402
import tempfile  # noqa: E402
from pathlib import Path  # noqa: E402
from typing import Annotated, Any  # noqa: E402

from mcp.server.fastmcp import FastMCP  # noqa: E402
from mcp.server.fastmcp.utilities.types import Image  # noqa: E402
from pydantic import Field  # noqa: E402

from . import runner  # noqa: E402

mcp = FastMCP(
    "cad",
    instructions=(
        "Parametric CAD. Write build123d Python, assign the solid to `result`, and pass it "
        "as `script`. `preview` renders images you can look at; `measure` gives exact mass "
        "properties from the B-rep kernel. If you are unsure whether a class or method "
        "exists, call `list_api` first rather than guessing — inventing API is the usual way "
        "generated CAD fails. Units are millimetres. STEP is the format to export for CNC, "
        "STL or 3MF for 3D printing."
    ),
)

WORKDIR = Path(os.environ.get("MCP_CAD_WORKDIR", os.getcwd()))
F3D = os.environ.get("MCP_CAD_F3D", "f3d")
OPENSCAD = os.environ.get("MCP_CAD_OPENSCAD", "openscad")

Script = Annotated[
    str,
    Field(description="build123d Python. Assign the finished solid to `result` (or call show_object)."),
]
OutDir = Annotated[
    str,
    Field(default="build", description="Directory for exports, relative to the working directory."),
]

# Camera directions f3d understands, as (name, --camera-direction value).
VIEWS = {
    "iso": "-1,-1,1",
    "front": "0,-1,0",
    "right": "-1,0,0",
    "top": "0,0,-1",
}


def _resolve(path: str) -> Path:
    p = Path(path).expanduser()
    return p if p.is_absolute() else WORKDIR / p


def _render(model_file: Path, view: str, size: tuple[int, int]) -> bytes:
    """Render a mesh/solid file offscreen with f3d and return the PNG bytes."""
    if shutil.which(F3D) is None:
        raise RuntimeError(f"{F3D} not found on PATH — the cad lab provides it")
    with tempfile.TemporaryDirectory() as tmp:
        png = Path(tmp) / f"{view}.png"
        cmd = [
            F3D,
            str(model_file),
            "--output",
            str(png),
            "--resolution",
            f"{size[0]},{size[1]}",
            "--camera-direction",
            VIEWS[view],
            "--up",
            "+Z",  # CAD convention, not f3d's graphics default
            "--grid",
            "--ambient-occlusion",
        ]
        proc = subprocess.run(cmd, capture_output=True, text=True, timeout=120)
        if not png.exists():
            raise RuntimeError(f"f3d produced no image: {proc.stderr.strip() or proc.stdout.strip()}")
        return png.read_bytes()


@mcp.tool()
def run(
    script: Script,
    formats: Annotated[
        list[str],
        Field(default=["step", "stl"], description="Any of: step, stl, glb, 3mf, brep"),
    ] = ["step", "stl"],  # noqa: B006 - MCP schema wants a concrete default
    out_dir: OutDir = "build",
    name: Annotated[str, Field(default="model", description="Base filename for the exports")] = "model",
) -> dict[str, Any]:
    """Execute a build123d script and export the solid. STEP keeps the B-rep; STL/3MF are meshes."""
    model = runner.run(script, workdir=WORKDIR)
    written = runner.export(model.shape, _resolve(out_dir), name, formats)
    return {"exports": written, **runner.measure(model.shape)}


@mcp.tool()
def measure(script: Script) -> dict[str, Any]:
    """Volume, surface area, centre of mass, bounding box and validity — exact, from the kernel."""
    return runner.measure(runner.run(script, workdir=WORKDIR).shape)


@mcp.tool(structured_output=False)
def preview(
    script: Script,
    views: Annotated[
        list[str],
        Field(default=["iso"], description=f"Any of: {', '.join(VIEWS)}"),
    ] = ["iso"],  # noqa: B006
    width: Annotated[int, Field(ge=128, le=2048)] = 800,
    height: Annotated[int, Field(ge=128, le=2048)] = 600,
) -> list:
    """Render the model and return PNGs, so you can see what the script actually built."""
    unknown = [v for v in views if v not in VIEWS]
    if unknown:
        raise ValueError(f"unknown view(s) {unknown}; have: {', '.join(VIEWS)}")

    model = runner.run(script, workdir=WORKDIR)
    with tempfile.TemporaryDirectory() as tmp:
        exported = runner.export(model.shape, Path(tmp), "preview", ["glb"])
        glb = Path(exported["glb"]["path"])
        out: list[Any] = [
            Image(data=_render(glb, view, (width, height)), format="png") for view in views
        ]
    out.append(json.dumps(runner.measure(model.shape), indent=2))
    return out


@mcp.tool()
def list_api(
    pattern: Annotated[
        str, Field(default="", description="Case-insensitive substring, e.g. 'fillet' or 'Box'")
    ] = "",
) -> dict[str, Any]:
    """List build123d's public API with signatures — check here before calling something unfamiliar."""
    import build123d

    needle = pattern.lower()
    classes: dict[str, str] = {}
    functions: dict[str, str] = {}
    for name in dir(build123d):
        if name.startswith("_") or (needle and needle not in name.lower()):
            continue
        obj = getattr(build123d, name)
        try:
            sig = str(inspect.signature(obj))
        except (TypeError, ValueError):
            sig = ""
        if inspect.isclass(obj):
            classes[name] = f"{name}{sig}"
        elif callable(obj):
            functions[name] = f"{name}{sig}"

    return {
        "version": build123d.__version__,
        "classes": dict(sorted(classes.items())),
        "functions": dict(sorted(functions.items())),
        "hint": "Objects go in a BuildPart/BuildSketch/BuildLine context, or compose algebraically with +, - and &.",
    }


@mcp.tool(structured_output=False)
def openscad_render(
    source: Annotated[str, Field(description="OpenSCAD source (.scad language, not Python)")],
    out_dir: OutDir = "build",
    name: Annotated[str, Field(default="part", description="Base filename")] = "part",
    export_format: Annotated[str, Field(default="stl", description="stl, 3mf, off or csg")] = "stl",
) -> list:
    """Compile OpenSCAD source to a mesh and return a rendered PNG. Mesh only — OpenSCAD has no STEP."""
    if shutil.which(OPENSCAD) is None:
        raise RuntimeError(f"{OPENSCAD} not found on PATH — the cad lab provides it")

    target_dir = _resolve(out_dir)
    target_dir.mkdir(parents=True, exist_ok=True)
    scad = target_dir / f"{name}.scad"
    scad.write_text(source)
    mesh = target_dir / f"{name}.{export_format}"

    proc = subprocess.run(
        [OPENSCAD, "-o", str(mesh), str(scad)], capture_output=True, text=True, timeout=600
    )
    if not mesh.exists():
        raise RuntimeError(f"openscad failed: {proc.stderr.strip() or proc.stdout.strip()}")

    return [
        Image(data=_render(mesh, "iso", (800, 600)), format="png"),
        json.dumps(
            {"scad": str(scad), "mesh": str(mesh), "bytes": mesh.stat().st_size}, indent=2
        ),
    ]


def main() -> None:
    mcp.run()


if __name__ == "__main__":
    main()
