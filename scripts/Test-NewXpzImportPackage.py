#!/usr/bin/env python3
"""Regression tests for New-XpzImportPackage.py."""

from __future__ import annotations

import importlib.util
import json
import tempfile
from pathlib import Path
from typing import Any


OBJECT_XML = """<?xml version="1.0" encoding="utf-8"?>
<Object type="11111111-1111-1111-1111-111111111111" name="Cliente">
  <Properties>
    <Property>
      <Name>Name</Name>
      <Value>Cliente</Value>
    </Property>
  </Properties>
</Object>
"""


def load_engine(script_dir: Path) -> Any:
    engine_path = script_dir / "New-XpzImportPackage.py"
    spec = importlib.util.spec_from_file_location("new_xpz_import_package", engine_path)
    if spec is None or spec.loader is None:
        raise SystemExit(f"Unable to load engine: {engine_path}")
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def assert_accepts_regular_object(engine: Any) -> None:
    with tempfile.TemporaryDirectory() as temp_dir:
        front_dir = Path(temp_dir)
        (front_dir / "Cliente.xml").write_text(OBJECT_XML, encoding="utf-8")

        objects, attributes = engine.classify_front_xmls(front_dir)

        assert len(objects) == 1, f"expected 1 object, got {len(objects)}"
        assert len(attributes) == 0, f"expected 0 attributes, got {len(attributes)}"


def assert_blocks_reference_named_object(engine: Any) -> None:
    with tempfile.TemporaryDirectory() as temp_dir:
        front_dir = Path(temp_dir)
        (front_dir / "Cliente_referencia.xml").write_text(OBJECT_XML, encoding="utf-8")

        try:
            engine.classify_front_xmls(front_dir)
        except engine.BlockedError as exc:
            message = str(exc)
            assert message.startswith("XML de referencia/exemplo/template"), message
            return

        raise AssertionError("expected reference-like XML to block packaging")


def assert_collision_gate_reports_next_round(engine: Any) -> None:
    with tempfile.TemporaryDirectory() as temp_dir:
        output_dir = Path(temp_dir)
        front_prefix = "GtaP3_c34f_20260528"
        (output_dir / f"{front_prefix}_01.import_file.xml").write_text("<ExportFile />", encoding="utf-8")
        (output_dir / f"{front_prefix}_02.import_file.xml").write_text("<ExportFile />", encoding="utf-8")

        try:
            engine.check_collision(output_dir / f"{front_prefix}_01.import_file.xml", front_prefix, "01")
        except engine.BlockedError as exc:
            assert exc.reason == "PACKAGE_ROUND_COLLISION", exc.reason
            assert exc.details["nextFreeNN"] == "03", exc.details
            assert exc.details["nextFreeRound"] == 3, exc.details
            return

        raise AssertionError("expected package round collision to block packaging")


def assert_collision_gate_accepts_free_round(engine: Any) -> None:
    with tempfile.TemporaryDirectory() as temp_dir:
        output_dir = Path(temp_dir)
        result = engine.check_collision(output_dir / "GtaP3_c34f_20260528_01.import_file.xml", "GtaP3_c34f_20260528", "01")

        assert result["status"] == "ok", result
        assert result["reason"] == "COLLISION_OK", result
        assert result["requestedNN"] == "01", result


def assert_execution_report_atomic_and_handoff(engine: Any) -> None:
    with tempfile.TemporaryDirectory() as temp_dir:
        report_path = Path(temp_dir) / "execution.json"
        run_id = "11111111-1111-1111-1111-111111111111"
        report_path.write_text(
            json.dumps(
                {
                    "Kind": engine.ExecutionReporter.KIND,
                    "SchemaVersion": engine.ExecutionReporter.SCHEMA_VERSION,
                    "runId": run_id,
                    "currentStage": "preflight",
                    "stageHistory": [{"stage": "preflight"}],
                }
            ),
            encoding="utf-8",
        )
        reporter = engine.ExecutionReporter(report_path, run_id)
        reporter.update(stage="engine-start", note="teste")
        first = json.loads(report_path.read_text(encoding="utf-8"))
        assert first["currentStage"] == "engine-start", first
        assert first["lastWriter"] == "python", first
        assert first["stageHistory"][-1]["stage"] == "engine-start", first
        assert report_path.read_bytes()[:3] != b"\xef\xbb\xbf"
        history_count = len(first["stageHistory"])
        reporter.heartbeat(stage="engine-start", progress="sem mudanca")
        second = json.loads(report_path.read_text(encoding="utf-8"))
        assert len(second["stageHistory"]) == history_count, second

        try:
            engine.ExecutionReporter(report_path, "22222222-2222-2222-2222-222222222222")
        except engine.ReportPublicationError as exc:
            assert "runId divergente" in str(exc), exc
        else:
            raise AssertionError("expected mismatched runId to block handoff")


def main() -> int:
    script_dir = Path(__file__).resolve().parent
    engine = load_engine(script_dir)

    assert_accepts_regular_object(engine)
    assert_blocks_reference_named_object(engine)
    assert_collision_gate_accepts_free_round(engine)
    assert_collision_gate_reports_next_round(engine)
    assert_execution_report_atomic_and_handoff(engine)

    print("Test-NewXpzImportPackage.py: passed")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
