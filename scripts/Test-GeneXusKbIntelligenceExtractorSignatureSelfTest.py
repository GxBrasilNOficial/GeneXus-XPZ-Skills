#!/usr/bin/env python3
"""Fixed-vector and normalization tests for the canonical extractor signature."""

from __future__ import annotations

import json
import tempfile
from pathlib import Path, PurePosixPath

from GeneXusKbIntelligenceExtractorSignature import (
    EXTRACTOR_SIGNATURE_FORMAT,
    EXTRACTOR_SIGNATURE_VERSION,
    ExtractorSignatureError,
    compute_signature,
    load_manifest,
)
from GeneXusCanonicalJson import canonical_bytes


ROOT = Path(__file__).resolve().parent.parent
EXPECTED_VERSION = "16"
EXPECTED_HASH = "aeda5a294dc0f10bfc195c39a0d6f0f3bc0c35e3c59ae6df5a89207599edd588"


def _assert(condition: bool, message: str) -> None:
    if not condition:
        raise AssertionError(message)


def _clone_signed_repository(target: Path) -> None:
    scripts = target / "scripts"
    scripts.mkdir(parents=True)
    manifest_path = ROOT / "scripts" / "kb-intelligence-extractor-files.json"
    for relative in load_manifest(manifest_path):
        source = ROOT.joinpath(*PurePosixPath(relative).parts)
        destination = target.joinpath(*PurePosixPath(relative).parts)
        destination.parent.mkdir(parents=True, exist_ok=True)
        destination.write_bytes(source.read_bytes())
    (scripts / manifest_path.name).write_bytes(manifest_path.read_bytes())


def main() -> int:
    _assert(EXTRACTOR_SIGNATURE_VERSION == EXPECTED_VERSION, "extractor signature version vector changed")
    _assert(EXTRACTOR_SIGNATURE_FORMAT == "manifest-lf-v1", "signature format changed")
    baseline = compute_signature(ROOT)
    _assert(baseline["extractor_signature_hash"] == EXPECTED_HASH, "canonical signature fixed vector changed")

    with tempfile.TemporaryDirectory(prefix="gx-extractor-signature-selftest-") as temp:
        root = Path(temp) / "repo"
        _clone_signed_repository(root)
        copy_hash = compute_signature(root)["extractor_signature_hash"]
        _assert(copy_hash == EXPECTED_HASH, "copied signed files must retain the fixed vector")

        core_path = root / "scripts" / "GeneXusTransactionWritabilityCore.py"
        core_bytes = core_path.read_bytes()
        core_lf = core_bytes.replace(b"\r\n", b"\n").replace(b"\r", b"\n")
        core_path.write_bytes(core_lf.replace(b"\n", b"\r\n"))
        _assert(compute_signature(root)["extractor_signature_hash"] == EXPECTED_HASH,
                "CRLF/LF conversion must preserve the signature")

        core_path.write_bytes(core_path.read_bytes() + b"# core-only mutation\n")
        _assert(compute_signature(root)["extractor_signature_hash"] != EXPECTED_HASH,
                "a core-only edit must invalidate the signature")

    with tempfile.TemporaryDirectory(prefix="gx-extractor-signature-final-newline-") as temp:
        root = Path(temp) / "repo"
        _clone_signed_repository(root)
        source = root / "scripts" / "Query-KbIntelligenceIndex.py"
        source_bytes = source.read_bytes()
        _assert(source_bytes.endswith(b"\n"), "fixture must contain its final newline")
        source.write_bytes(source_bytes[:-1])
        _assert(compute_signature(root)["extractor_signature_hash"] != EXPECTED_HASH,
                "final-newline presence must participate in the signature")

    with tempfile.TemporaryDirectory(prefix="gx-extractor-signature-manifest-") as temp:
        root = Path(temp) / "repo"
        _clone_signed_repository(root)
        manifest_path = root / "scripts" / "kb-intelligence-extractor-files.json"
        manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
        extra = "scripts/extractor-signature-selftest-vector.txt"
        (root / extra).write_text("signed vector input\n", encoding="utf-8", newline="\n")
        manifest["files"].append(extra)
        manifest["files"].sort()
        manifest_path.write_bytes(canonical_bytes(manifest))
        _assert(compute_signature(root)["extractor_signature_hash"] != EXPECTED_HASH,
                "manifest membership changes must invalidate the signature")

    with tempfile.TemporaryDirectory(prefix="gx-extractor-signature-bom-") as temp:
        root = Path(temp) / "repo"
        _clone_signed_repository(root)
        core_path = root / "scripts" / "GeneXusTransactionWritabilityCore.py"
        core_path.write_bytes(b"\xef\xbb\xbf" + core_path.read_bytes())
        try:
            compute_signature(root)
        except ExtractorSignatureError as exc:
            _assert("BOM" in str(exc), "BOM rejection should be explicit")
        else:
            raise AssertionError("UTF-8 BOM in signed source must block the signature")

    print("OK: Test-GeneXusKbIntelligenceExtractorSignatureSelfTest.py")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
