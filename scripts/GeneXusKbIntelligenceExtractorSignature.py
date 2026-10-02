#!/usr/bin/env python3
"""Canonical signature for the automatic KbIntelligence extractor contract."""

from __future__ import annotations

import argparse
import ast
import hashlib
import json
import sys
from pathlib import Path, PurePosixPath

from GeneXusCanonicalJson import CanonicalJsonError, canonical_bytes, loads_strict


EXTRACTOR_SIGNATURE_VERSION = "16"
EXTRACTOR_SIGNATURE_FORMAT = "manifest-lf-v1"
MANIFEST_RELATIVE_PATH = "scripts/kb-intelligence-extractor-files.json"


class ExtractorSignatureError(ValueError):
    pass


def load_manifest(manifest_path: Path) -> list[str]:
    try:
        raw = manifest_path.read_bytes()
    except OSError as exc:
        raise ExtractorSignatureError(f"cannot read extractor manifest: {exc}") from exc
    try:
        manifest = loads_strict(raw)
    except CanonicalJsonError as exc:
        raise ExtractorSignatureError(f"invalid extractor manifest: {exc}") from exc
    if not isinstance(manifest, dict) or set(manifest) != {"schemaVersion", "files"}:
        raise ExtractorSignatureError("extractor manifest must contain exactly schemaVersion and files")
    if type(manifest["schemaVersion"]) is not int or manifest["schemaVersion"] != 1:
        raise ExtractorSignatureError("extractor manifest schemaVersion must be integer 1")
    files = manifest["files"]
    if not isinstance(files, list) or not files or any(not isinstance(item, str) for item in files):
        raise ExtractorSignatureError("extractor manifest files must be a non-empty array of paths")
    if files != sorted(files):
        raise ExtractorSignatureError("extractor manifest files must be in ordinal path order")
    if len(set(files)) != len(files):
        raise ExtractorSignatureError("extractor manifest contains duplicate file paths")
    for item in files:
        path = PurePosixPath(item)
        if path.is_absolute() or ".." in path.parts or "\\" in item or path.as_posix() != item:
            raise ExtractorSignatureError(f"invalid relative manifest path: {item!r}")
    return files


def _normalize_source(raw: bytes, relative_path: str) -> bytes:
    if raw.startswith(b"\xef\xbb\xbf"):
        raise ExtractorSignatureError(f"UTF-8 BOM is not allowed in signed file: {relative_path}")
    try:
        text = raw.decode("utf-8", errors="strict")
    except UnicodeDecodeError as exc:
        raise ExtractorSignatureError(f"signed file is not strict UTF-8 ({relative_path}): {exc}") from exc
    return text.replace("\r\n", "\n").replace("\r", "\n").encode("utf-8", errors="strict")


def _local_imports(path: Path) -> set[str]:
    try:
        raw = path.read_bytes()
        if raw.startswith(b"\xef\xbb\xbf"):
            raise ExtractorSignatureError(f"UTF-8 BOM is not allowed in signed file: {path}")
        source = raw.decode("utf-8", errors="strict")
        tree = ast.parse(source, filename=str(path))
    except ExtractorSignatureError:
        raise
    except (OSError, UnicodeDecodeError, SyntaxError) as exc:
        raise ExtractorSignatureError(f"cannot inspect static imports in {path}: {exc}") from exc
    modules: set[str] = set()
    for node in ast.walk(tree):
        if isinstance(node, ast.Import):
            modules.update(alias.name.split(".", 1)[0] for alias in node.names)
        elif isinstance(node, ast.ImportFrom) and node.level == 0 and node.module:
            modules.add(node.module.split(".", 1)[0])
    return modules


def validate_static_import_closure(repo_root: Path, files: list[str]) -> None:
    signed = set(files)
    scripts_root = repo_root / "scripts"
    missing: list[str] = []
    for relative in files:
        if not relative.endswith(".py"):
            continue
        source_path = repo_root.joinpath(*PurePosixPath(relative).parts)
        for module in _local_imports(source_path):
            local_path = scripts_root / f"{module}.py"
            if local_path.is_file():
                local_relative = local_path.relative_to(repo_root).as_posix()
                if local_relative not in signed:
                    missing.append(f"{relative} imports unsigned local module {local_relative}")
    if missing:
        raise ExtractorSignatureError("; ".join(sorted(missing)))


def compute_signature(repo_root: Path, manifest_path: Path | None = None) -> dict[str, object]:
    root = repo_root.resolve(strict=True)
    manifest_file = (manifest_path or (root / MANIFEST_RELATIVE_PATH)).resolve(strict=True)
    files = load_manifest(manifest_file)
    validate_static_import_closure(root, files)
    hasher = hashlib.sha256()
    hasher.update(canonical_bytes({"schemaVersion": 1, "files": files}))
    for relative in files:
        path = root.joinpath(*PurePosixPath(relative).parts)
        try:
            resolved = path.resolve(strict=True)
            resolved.relative_to(root)
            normalized = _normalize_source(resolved.read_bytes(), relative)
        except (OSError, ValueError) as exc:
            raise ExtractorSignatureError(f"cannot sign {relative}: {exc}") from exc
        hasher.update(relative.encode("utf-8", errors="strict"))
        hasher.update(b"\0")
        hasher.update(str(len(normalized)).encode("ascii"))
        hasher.update(b"\0")
        hasher.update(normalized)
        hasher.update(b"\0")
    return {
        "extractor_signature_version": EXTRACTOR_SIGNATURE_VERSION,
        "extractor_signature_hash": hasher.hexdigest(),
        "extractor_signature_format": EXTRACTOR_SIGNATURE_FORMAT,
        "manifest_files": files,
    }


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Compute the canonical KbIntelligence extractor signature.")
    parser.add_argument("--repo-root", type=Path, default=Path(__file__).resolve().parent.parent)
    parser.add_argument("--manifest-path", type=Path)
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    try:
        result = compute_signature(args.repo_root, args.manifest_path)
    except (ExtractorSignatureError, OSError) as exc:
        print(f"EXTRACTOR_SIGNATURE_BLOCKED: {exc}", file=sys.stderr)
        return 2
    print(json.dumps(result, ensure_ascii=False, separators=(",", ":")))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
