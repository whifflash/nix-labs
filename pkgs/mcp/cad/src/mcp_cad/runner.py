"""Execute a build123d script and get a shape out of it.

Shared by the MCP server and `cad-watch`, so both agree on what a "model script"
is: a normal Python file that either assigns its solid to `result`, or hands
shapes to `show_object()` the way the CAD editors do.

Scripts run unsandboxed, with the privileges of whoever started the tool.
"""

from __future__ import annotations

import runpy
from dataclasses import dataclass
from pathlib import Path
from typing import Any

EXPORT_FORMATS = ("step", "stl", "glb", "3mf", "brep")


class ScriptError(RuntimeError):
    """The model script failed, or produced nothing we can export."""


@dataclass
class Model:
    shape: Any
    source: str
    path: Path | None = None


def _is_shape(obj: Any) -> bool:
    try:
        from build123d import Shape
    except ImportError:  # pragma: no cover - build123d is a hard dependency
        return False
    return isinstance(obj, Shape)


def _unwrap(obj: Any) -> Any:
    """Accept a builder (`BuildPart`) as readily as a bare shape."""
    for attr in ("part", "sketch", "line"):
        inner = getattr(obj, attr, None)
        if inner is not None and _is_shape(inner):
            return inner
    return obj


def run(source: str, path: Path | None = None, workdir: Path | None = None) -> Model:
    """Run `source` and return the shape it produced."""
    captured: list[Any] = []

    def show_object(obj: Any, *_args: Any, **_kwargs: Any) -> Any:
        """The convention every CAD editor uses; here it just records the shape."""
        captured.append(obj)
        return obj

    script_globals: dict[str, Any] = {
        "__name__": "__main__",
        "show_object": show_object,
        "show": show_object,  # ocp_vscode spells it this way
    }
    if path is not None:
        script_globals["__file__"] = str(path)

    cwd = Path.cwd()
    try:
        if workdir is not None:
            workdir.mkdir(parents=True, exist_ok=True)
            import os

            os.chdir(workdir)
        exec(compile(source, str(path or "<model>"), "exec"), script_globals)  # noqa: S102
    except Exception as exc:
        raise ScriptError(f"{type(exc).__name__}: {exc}") from exc
    finally:
        if workdir is not None:
            import os

            os.chdir(cwd)

    for candidate in (script_globals.get("result"), *reversed(captured)):
        if candidate is None:
            continue
        shape = _unwrap(candidate)
        if _is_shape(shape):
            return Model(shape=shape, source=source, path=path)

    raise ScriptError(
        "the script produced no shape — assign the solid to `result`, "
        "or pass it to show_object(...)"
    )


def export(shape: Any, out_dir: Path, stem: str, formats: list[str]) -> dict[str, dict[str, Any]]:
    """Write `shape` in each requested format; return {format: {path, bytes}}."""
    from build123d import Mesher, export_brep, export_gltf, export_step, export_stl

    out_dir.mkdir(parents=True, exist_ok=True)
    written: dict[str, dict[str, Any]] = {}

    for fmt in formats:
        fmt = fmt.lower()
        if fmt not in EXPORT_FORMATS:
            raise ScriptError(f"unknown export format {fmt!r} (have: {', '.join(EXPORT_FORMATS)})")
        target = out_dir / f"{stem}.{fmt}"
        if fmt == "step":
            export_step(shape, str(target))
        elif fmt == "stl":
            export_stl(shape, str(target))
        elif fmt == "glb":
            export_gltf(shape, str(target), binary=True)
        elif fmt == "brep":
            export_brep(shape, str(target))
        elif fmt == "3mf":
            mesher = Mesher()
            mesher.add_shape(shape)
            mesher.write(str(target))
        written[fmt] = {"path": str(target), "bytes": target.stat().st_size}

    return written


def measure(shape: Any) -> dict[str, Any]:
    """Mass properties, taken from the B-rep rather than from a tessellation."""
    bbox = shape.bounding_box()
    centre = shape.center()
    return {
        "volume_mm3": round(shape.volume, 4),
        "area_mm2": round(shape.area, 4),
        "center_of_mass": [round(centre.X, 4), round(centre.Y, 4), round(centre.Z, 4)],
        "bounding_box": {
            "min": [round(bbox.min.X, 4), round(bbox.min.Y, 4), round(bbox.min.Z, 4)],
            "max": [round(bbox.max.X, 4), round(bbox.max.Y, 4), round(bbox.max.Z, 4)],
            "size": [round(bbox.size.X, 4), round(bbox.size.Y, 4), round(bbox.size.Z, 4)],
        },
        # `is_valid` is a property on build123d shapes, not a method.
        "is_valid": bool(shape.is_valid),
        "solids": len(shape.solids()),
        "faces": len(shape.faces()),
        "edges": len(shape.edges()),
    }
