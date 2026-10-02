#!/usr/bin/env python3
"""Synthetic contract tests for the materialized writability query path."""

from __future__ import annotations

import importlib.util
import sqlite3
from pathlib import Path

from GeneXusCanonicalJson import canonical_text
from GeneXusTransactionWritabilityCore import WRITABILITY_RULE_VERSION
from GeneXusKbIntelligenceExtractorSignature import EXTRACTOR_SIGNATURE_FORMAT, EXTRACTOR_SIGNATURE_VERSION


SCRIPT_DIR = Path(__file__).resolve().parent
ENGINE_PATH = SCRIPT_DIR / "Query-KbIntelligenceIndex.py"


def _load_query_engine():
    spec = importlib.util.spec_from_file_location("writability_query_selftest", ENGINE_PATH)
    if spec is None or spec.loader is None:
        raise AssertionError("query module could not be loaded")
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    module.compute_signature = lambda _root: {
        "extractor_signature_version": EXTRACTOR_SIGNATURE_VERSION,
        "extractor_signature_hash": "a" * 64,
        "extractor_signature_format": EXTRACTOR_SIGNATURE_FORMAT,
    }
    return module


def _identity(transaction_guid: str, level_guid: str, attribute_guid: str, ordinal: int) -> dict[str, object]:
    return {
        "transaction": {"type": "Transaction", "guid": transaction_guid, "name": "Customer",
                        "path": "Transaction/Customer.xml", "rootKind": "corpus"},
        "partType": "part-source-guid",
        "level": {"guid": level_guid, "pathOrdinals": [ordinal]},
        "attribute": {"type": "Attribute", "guid": attribute_guid, "name": "CustomerName",
                       "path": "Attribute/CustomerName.xml", "rootKind": "corpus"},
    }


def _envelope(identity: dict[str, object]) -> str:
    return canonical_text({
        "kind": "gx-writability-evidence", "schemaVersion": 1,
        "ruleVersion": WRITABILITY_RULE_VERSION, "identity": identity,
        "basis": "synthetic-test", "coverage": "complete-in-model",
        "reasonCodes": ["own-physical"], "provenance": {},
        "evidenceSummary": "synthetic occurrence",
    })


def _seed(conn: sqlite3.Connection) -> None:
    conn.executescript("""
        CREATE TABLE metadata (key TEXT PRIMARY KEY, value TEXT NOT NULL);
        CREATE TABLE objects (
            object_id INTEGER PRIMARY KEY, type TEXT NOT NULL, name TEXT NOT NULL,
            origin TEXT NOT NULL, guid TEXT, file_path TEXT NOT NULL, last_update TEXT,
            file_hash TEXT NOT NULL, is_generated_object INTEGER NOT NULL DEFAULT 0,
            pattern_object_id TEXT, instance_key TEXT
        );
        CREATE TABLE transaction_attribute_writability (
            writability_id INTEGER PRIMARY KEY, transaction_object_id INTEGER NOT NULL,
            transaction_name TEXT NOT NULL, level_name TEXT NOT NULL, attribute_name TEXT NOT NULL,
            key_in_level INTEGER NOT NULL, is_redundant INTEGER NOT NULL, classification TEXT NOT NULL,
            writable INTEGER, can_assign_in_new INTEGER, reason TEXT NOT NULL, evidence TEXT NOT NULL,
            writability_rule_version TEXT NOT NULL
        );
    """)
    metadata = {
        "schema_version": "5", "writability_rule_version": WRITABILITY_RULE_VERSION,
        "extractor_signature_version": EXTRACTOR_SIGNATURE_VERSION,
        "extractor_signature_hash": "a" * 64,
        "extractor_signature_format": EXTRACTOR_SIGNATURE_FORMAT,
        "writability_rows_expected": "2", "writability_rows_written": "2", "writability_rows_lost": "0",
    }
    conn.executemany("INSERT INTO metadata(key,value) VALUES (?,?)", metadata.items())
    conn.execute("INSERT INTO objects VALUES (1,'Transaction','Customer','corpus','10000000-0000-4000-8000-000000000001',"
                 "'Transaction/Customer.xml',NULL,'x',0,NULL,NULL)")
    for writability_id, ordinal, level_guid, attribute_guid in (
        (1, 0, "20000000-0000-4000-8000-000000000001", "30000000-0000-4000-8000-000000000001"),
        (2, 1, "20000000-0000-4000-8000-000000000002", "30000000-0000-4000-8000-000000000002"),
    ):
        identity = _identity("10000000-0000-4000-8000-000000000001", level_guid, attribute_guid, ordinal)
        conn.execute("""INSERT INTO transaction_attribute_writability VALUES
            (?,1,'Customer','Customer','CustomerName',0,0,'own-physical',1,1,'own-physical',?,?)""",
                     (writability_id, _envelope(identity), WRITABILITY_RULE_VERSION))


def main() -> int:
    engine = _load_query_engine()
    conn = sqlite3.connect(":memory:")
    try:
        _seed(conn)
        result = engine.transaction_attributes(conn, "Customer")
        rows = result["results"]
        if len(rows) != 2:
            raise AssertionError(f"expected both occurrences; got {len(rows)}")
        identities = [row["identity"]["level"]["pathOrdinals"] for row in rows]
        if identities != [[0], [1]]:
            raise AssertionError(f"occurrence order/identity lost: {identities}")
        if any(not isinstance(row["evidence"], dict) or row["decisionState"] != "not-requested" for row in rows):
            raise AssertionError("automatic envelope or non-authorizing query contract missing")

        conn.execute("UPDATE transaction_attribute_writability SET evidence=? WHERE writability_id=1",
                     (canonical_text({**rows[0]["evidence"], "provenance": {"fixture": True}}),))
        try:
            engine.transaction_attributes(conn, "Customer")
        except engine.WritabilityIndexError as exc:
            if exc.reason != "writability-evidence-invalid":
                raise AssertionError(f"unexpected malformed-envelope reason: {exc.reason}") from exc
        else:
            raise AssertionError("unknown provenance fields must fail closed")
        conn.execute("UPDATE transaction_attribute_writability SET evidence=? WHERE writability_id=1",
                     (_envelope(rows[0]["identity"]),))

        conn.execute("DELETE FROM metadata WHERE key='extractor_signature_format'")
        try:
            engine.transaction_writable_attributes(conn, "Customer")
        except engine.WritabilityIndexError as exc:
            if exc.reason != "writability-metadata-missing":
                raise AssertionError(f"unexpected legacy-index reason: {exc.reason}") from exc
        else:
            raise AssertionError("legacy writability metadata must be blocked before reading rows")
    finally:
        conn.close()
    print("OK: Test-GeneXusKbIntelligenceWritabilityQuerySelfTest.py")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
