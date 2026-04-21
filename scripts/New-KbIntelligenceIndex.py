#!/usr/bin/env python3
"""
Build a minimal GeneXus KB intelligence SQLite index.

Phase 1 scope:
- sources: Procedure, WebPanel
- targets: Procedure, WebPanel
- evidence: effective Source only
"""

from __future__ import annotations

import argparse
import hashlib
import html
import json
import re
import sqlite3
from dataclasses import dataclass
from datetime import datetime, timezone
from pathlib import Path
from typing import Iterable


SOURCE_RE = re.compile(r"<Source(?:\s[^>]*)?>(?P<body>.*?)</Source>", re.IGNORECASE | re.DOTALL)
CDATA_RE = re.compile(r"^\s*<!\[CDATA\[(?P<body>.*)\]\]>\s*$", re.DOTALL)
LAST_UPDATE_RE = re.compile(r'\blastUpdate="([^"]+)"')
PROCEDURE_DIRECT_RE = re.compile(r"\b(?P<name>proc[A-Za-z_][A-Za-z0-9_]*)\s*\(")
PROCEDURE_DOT_CALL_RE = re.compile(r"\b(?P<name>[A-Za-z_][A-Za-z0-9_]*)\s*\.\s*Call\s*\(")
WEBPANEL_DOT_LINK_RE = re.compile(r"\b(?P<name>[A-Za-z_][A-Za-z0-9_]*)\s*\.\s*Link\s*\(")


@dataclass(frozen=True)
class SourceBlock:
    text: str
    start_line: int


@dataclass(frozen=True)
class ObjectInfo:
    object_type: str
    name: str
    path: Path
    rel_path: str
    last_update: str | None
    file_hash: str


@dataclass(frozen=True)
class Evidence:
    source_type: str
    source_name: str
    target_type: str
    target_name: str
    relation_kind: str
    source_file: str
    line: int
    column: int
    snippet: str
    evidence_role: str
    extractor_rule: str
    confidence: str


def read_text(path: Path) -> str:
    return path.read_text(encoding="utf-8-sig", errors="replace")


def sha256_text(text: str) -> str:
    return hashlib.sha256(text.encode("utf-8", errors="replace")).hexdigest()


def line_number_at(text: str, index: int) -> int:
    return text.count("\n", 0, index) + 1


def collect_objects(source_root: Path, object_type: str) -> dict[str, ObjectInfo]:
    folder = source_root / object_type
    objects: dict[str, ObjectInfo] = {}
    if not folder.exists():
        return objects

    for path in sorted(folder.glob("*.xml")):
        text = read_text(path)
        last_update_match = LAST_UPDATE_RE.search(text)
        rel_path = path.relative_to(source_root).as_posix()
        name = path.stem
        objects[name] = ObjectInfo(
            object_type=object_type,
            name=name,
            path=path,
            rel_path=rel_path,
            last_update=last_update_match.group(1) if last_update_match else None,
            file_hash=sha256_text(text),
        )
    return objects


def unwrap_source_body(raw_body: str) -> str:
    body = raw_body
    cdata_match = CDATA_RE.match(body)
    if cdata_match:
        return cdata_match.group("body")
    return html.unescape(body)


def source_blocks(xml_text: str) -> Iterable[SourceBlock]:
    for match in SOURCE_RE.finditer(xml_text):
        raw_body = match.group("body")
        body_start = match.start("body")
        cdata_prefix = re.match(r"\s*<!\[CDATA\[", raw_body, re.DOTALL)
        if cdata_prefix:
            body_start += cdata_prefix.end()
        body = unwrap_source_body(raw_body)
        if not body.strip():
            continue
        if body.lstrip().startswith("<"):
            continue
        yield SourceBlock(text=body, start_line=line_number_at(xml_text, body_start))


def active_line(line: str) -> str:
    stripped = line.lstrip()
    if stripped.startswith("//"):
        return ""
    return line.split("//", 1)[0]


def add_evidence(
    evidences: list[Evidence],
    *,
    source: ObjectInfo,
    target_type: str,
    target_name: str,
    relation_kind: str,
    line: int,
    column: int,
    snippet: str,
    extractor_rule: str,
) -> None:
    evidences.append(
        Evidence(
            source_type=source.object_type,
            source_name=source.name,
            target_type=target_type,
            target_name=target_name,
            relation_kind=relation_kind,
            source_file=source.rel_path,
            line=line,
            column=column,
            snippet=compact_snippet(snippet),
            evidence_role="Source efetivo",
            extractor_rule=extractor_rule,
            confidence="direct",
        )
    )


def compact_snippet(text: str, limit: int = 220) -> str:
    snippet = " ".join(text.strip().split())
    if len(snippet) <= limit:
        return snippet
    return snippet[: limit - 3].rstrip() + "..."


def extract_evidence(
    source_root: Path,
    source_objects: Iterable[ObjectInfo],
    procedure_names: set[str],
    webpanel_names: set[str],
) -> list[Evidence]:
    evidences: list[Evidence] = []

    for source in source_objects:
        xml_text = read_text(source.path)
        for block in source_blocks(xml_text):
            for offset, line in enumerate(block.text.splitlines()):
                cleaned = active_line(line)
                if not cleaned.strip():
                    continue
                line_no = block.start_line + offset

                for match in PROCEDURE_DOT_CALL_RE.finditer(cleaned):
                    target_name = match.group("name")
                    if target_name in procedure_names:
                        add_evidence(
                            evidences,
                            source=source,
                            target_type="Procedure",
                            target_name=target_name,
                            relation_kind="calls_procedure",
                            line=line_no,
                            column=match.start("name") + 1,
                            snippet=line,
                            extractor_rule="procedure_dot_call",
                        )

                for match in PROCEDURE_DIRECT_RE.finditer(cleaned):
                    target_name = match.group("name")
                    if target_name in procedure_names:
                        add_evidence(
                            evidences,
                            source=source,
                            target_type="Procedure",
                            target_name=target_name,
                            relation_kind="calls_procedure",
                            line=line_no,
                            column=match.start("name") + 1,
                            snippet=line,
                            extractor_rule="procedure_direct_call",
                        )

                for match in WEBPANEL_DOT_LINK_RE.finditer(cleaned):
                    target_name = match.group("name")
                    if target_name in webpanel_names:
                        add_evidence(
                            evidences,
                            source=source,
                            target_type="WebPanel",
                            target_name=target_name,
                            relation_kind="calls_webpanel",
                            line=line_no,
                            column=match.start("name") + 1,
                            snippet=line,
                            extractor_rule="webpanel_dot_link",
                        )

    unique: dict[tuple[str, str, str, str, int, str], Evidence] = {}
    for evidence in evidences:
        key = (
            evidence.source_type,
            evidence.source_name,
            evidence.target_type,
            evidence.target_name,
            evidence.line,
            evidence.extractor_rule,
        )
        unique[key] = evidence
    return list(unique.values())


def create_schema(conn: sqlite3.Connection) -> None:
    conn.executescript(
        """
        DROP TABLE IF EXISTS relations;
        DROP TABLE IF EXISTS evidence;
        DROP TABLE IF EXISTS objects;
        DROP TABLE IF EXISTS metadata;

        CREATE TABLE metadata (
            key TEXT PRIMARY KEY,
            value TEXT NOT NULL
        );

        CREATE TABLE objects (
            object_id INTEGER PRIMARY KEY AUTOINCREMENT,
            type TEXT NOT NULL,
            name TEXT NOT NULL,
            file_path TEXT NOT NULL,
            last_update TEXT,
            file_hash TEXT NOT NULL,
            UNIQUE(type, name)
        );

        CREATE TABLE evidence (
            evidence_id INTEGER PRIMARY KEY AUTOINCREMENT,
            source_file TEXT NOT NULL,
            line INTEGER NOT NULL,
            column INTEGER NOT NULL,
            snippet TEXT NOT NULL,
            evidence_role TEXT NOT NULL,
            extractor_rule TEXT NOT NULL
        );

        CREATE TABLE relations (
            relation_id INTEGER PRIMARY KEY AUTOINCREMENT,
            source_object_id INTEGER NOT NULL,
            target_type TEXT NOT NULL,
            target_name TEXT NOT NULL,
            relation_kind TEXT NOT NULL,
            evidence_id INTEGER NOT NULL,
            confidence TEXT NOT NULL,
            FOREIGN KEY(source_object_id) REFERENCES objects(object_id),
            FOREIGN KEY(evidence_id) REFERENCES evidence(evidence_id)
        );

        CREATE INDEX idx_objects_type_name ON objects(type, name);
        CREATE INDEX idx_relations_target ON relations(target_type, target_name);
        CREATE INDEX idx_relations_source ON relations(source_object_id);
        """
    )


def write_index(
    output_path: Path,
    source_root: Path,
    objects: list[ObjectInfo],
    evidences: list[Evidence],
) -> None:
    output_path.parent.mkdir(parents=True, exist_ok=True)
    if output_path.exists():
        output_path.unlink()

    conn = sqlite3.connect(output_path)
    try:
        create_schema(conn)
        generated_at = datetime.now(timezone.utc).isoformat()
        conn.executemany(
            "INSERT INTO metadata(key, value) VALUES (?, ?)",
            [
                ("generated_at", generated_at),
                ("source_root", str(source_root)),
                ("phase", "1"),
                ("scope", "Procedure,WebPanel"),
            ],
        )

        for obj in objects:
            conn.execute(
                """
                INSERT INTO objects(type, name, file_path, last_update, file_hash)
                VALUES (?, ?, ?, ?, ?)
                """,
                (obj.object_type, obj.name, obj.rel_path, obj.last_update, obj.file_hash),
            )

        object_ids = {
            (row[0], row[1]): row[2]
            for row in conn.execute("SELECT type, name, object_id FROM objects")
        }

        for evidence in evidences:
            cursor = conn.execute(
                """
                INSERT INTO evidence(source_file, line, column, snippet, evidence_role, extractor_rule)
                VALUES (?, ?, ?, ?, ?, ?)
                """,
                (
                    evidence.source_file,
                    evidence.line,
                    evidence.column,
                    evidence.snippet,
                    evidence.evidence_role,
                    evidence.extractor_rule,
                ),
            )
            evidence_id = cursor.lastrowid
            source_object_id = object_ids[(evidence.source_type, evidence.source_name)]
            conn.execute(
                """
                INSERT INTO relations(source_object_id, target_type, target_name, relation_kind, evidence_id, confidence)
                VALUES (?, ?, ?, ?, ?, ?)
                """,
                (
                    source_object_id,
                    evidence.target_type,
                    evidence.target_name,
                    evidence.relation_kind,
                    evidence_id,
                    evidence.confidence,
                ),
            )

        conn.commit()
    finally:
        conn.close()


def validation_report(
    source_root: Path,
    objects_by_type: dict[str, dict[str, ObjectInfo]],
    evidences: list[Evidence],
) -> dict[str, object]:
    def has_relation(source_type: str, source_name: str, target_type: str, target_name: str, rule: str) -> bool:
        return any(
            evidence.source_type == source_type
            and evidence.source_name == source_name
            and evidence.target_type == target_type
            and evidence.target_name == target_name
            and evidence.extractor_rule == rule
            for evidence in evidences
        )

    cases = [
        {
            "id": "case-1-webpanel-procedure-dot-call",
            "source": "WebPanel:wpRelatoriosDeMovimentosDeVolumes",
            "target": "Procedure:procPlanilhaVolumeMovimento",
            "expected_rule": "procedure_dot_call",
            "status": "passed"
            if has_relation(
                "WebPanel",
                "wpRelatoriosDeMovimentosDeVolumes",
                "Procedure",
                "procPlanilhaVolumeMovimento",
                "procedure_dot_call",
            )
            else "failed",
        },
        {
            "id": "case-2-procedure-direct-call",
            "source": "Procedure:PreenchXmlNFE",
            "target": "Procedure:procLeParteDeStringXml",
            "expected_rule": "procedure_direct_call",
            "status": "passed"
            if has_relation(
                "Procedure",
                "PreenchXmlNFE",
                "Procedure",
                "procLeParteDeStringXml",
                "procedure_direct_call",
            )
            else "failed",
        },
        {
            "id": "case-3-comment-does-not-create-relation",
            "source": "Procedure:PreenchXmlNFE",
            "target": "Procedure:procCodigoDeBarrasDobson2of5",
            "status": "failed"
            if has_relation(
                "Procedure",
                "PreenchXmlNFE",
                "Procedure",
                "procCodigoDeBarrasDobson2of5",
                "procedure_direct_call",
            )
            else "passed",
            "expectation": "comment-only procedure reference must not create a direct relation",
        },
        {
            "id": "case-4-visual-layout-does-not-create-relation",
            "source": "WebPanel:promptCompradorDeGado",
            "target": "Procedure:procEmpresaLiberadaProUsuario",
            "status": "failed"
            if has_relation(
                "WebPanel",
                "promptCompradorDeGado",
                "Procedure",
                "procEmpresaLiberadaProUsuario",
                "procedure_direct_call",
            )
            else "passed",
            "expectation": "visual-layout Source reference must not create a direct relation",
        },
    ]

    return {
        "generated_at": datetime.now(timezone.utc).isoformat(),
        "source_root": str(source_root),
        "objects_read_by_type": {key: len(value) for key, value in objects_by_type.items()},
        "objects_written": sum(len(value) for value in objects_by_type.values()),
        "relations_written": len(evidences),
        "cases": cases,
    }


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Build a minimal KB intelligence SQLite index.")
    parser.add_argument("--source-root", required=True, type=Path)
    parser.add_argument("--output-path", required=True, type=Path)
    parser.add_argument("--validation-report-path", type=Path)
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    source_root = args.source_root.resolve()
    if not source_root.exists():
        raise SystemExit(f"SourceRoot not found: {source_root}")

    procedures = collect_objects(source_root, "Procedure")
    webpanels = collect_objects(source_root, "WebPanel")
    objects_by_type = {"Procedure": procedures, "WebPanel": webpanels}
    objects = [*procedures.values(), *webpanels.values()]

    evidences = extract_evidence(
        source_root,
        objects,
        procedure_names=set(procedures),
        webpanel_names=set(webpanels),
    )
    write_index(args.output_path.resolve(), source_root, objects, evidences)

    report = validation_report(source_root, objects_by_type, evidences)
    if args.validation_report_path:
        report_path = args.validation_report_path.resolve()
        report_path.parent.mkdir(parents=True, exist_ok=True)
        report_path.write_text(json.dumps(report, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")

    print(json.dumps(report, indent=2, ensure_ascii=False))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
