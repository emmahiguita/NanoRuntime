"""Catálogo del PC: archivos GGUF existentes, nunca nombres de modelos inventados."""

import json
import hashlib
import struct
from pathlib import Path

PROJECT_ROOT = Path(__file__).resolve().parents[2]
MODEL_ROOTS = (PROJECT_ROOT, PROJECT_ROOT / "models")


def installed_models() -> list[dict]:
    """Lee solo cabeceras y tamaños; excluye placeholders sin cargar pesos en RAM."""
    models, seen = [], set()
    try:
        library = json.loads(Path(__file__).with_name('model_library.json').read_text(encoding='utf8'))['models']
    except (OSError, ValueError, KeyError):
        library = []
    for directory in MODEL_ROOTS:
        if not directory.is_dir():
            continue
        for candidate in directory.glob("*.gguf"):
            try:
                path = candidate.resolve(strict=True)
                if path in seen or path.parent != directory.resolve():
                    continue
                if path.name.lower().startswith(('mmproj','mtp-','projector','imatrix')):
                    continue
                size = path.stat().st_size
                with path.open("rb") as stream:
                    magic, version, tensors, metadata = struct.unpack("<4sIQQ", stream.read(24))
                if magic != b"GGUF" or version not in (2, 3) or not tensors or not metadata or size < 1048576:
                    continue
                seen.add(path)
                models.append({"id": hashlib.sha256(str(path).encode()).hexdigest()[:24],
                               "name": path.name, "path": str(path), "size_mb": size // 1048576,
                               "size_bytes": size, "is_loaded": False,
                               "catalog": next(({"title":m["title"],"use":m["use"],"parameters":m["parameters"],"quantization":m["quantization"],"repo":m["repo"],"note":m["capability_note"]} for m in library if any(f["role"]=="model" and Path(f["filename"]).name==path.name for f in m["files"])),None)})
            except (OSError, ValueError, struct.error):
                continue
    # Orden estable; el catálogo no decide por el usuario qué modelo activar.
    return sorted(models, key=lambda model: (model["size_mb"], model["name"]))


def resolve_model(identifier: str) -> dict:
    """Una petición solo puede activar un recurso que sigue existiendo en este catálogo."""
    for model in installed_models():
        if identifier in (model["id"], model["path"]):
            return model
    raise ValueError("Selecciona un GGUF real del catálogo local")
