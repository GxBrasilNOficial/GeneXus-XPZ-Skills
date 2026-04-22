#!/usr/bin/env python3
"""Query the KB Intelligence SQLite index."""

from __future__ import annotations

import argparse
import json
import sqlite3
from pathlib import Path


def row_to_dict(cursor: sqlite3.Cursor, row: sqlite3.Row) -> dict[str, object]:
    return {description[0]: row[index] for index, description in enumerate(cursor.description)}


def fetch_all(conn: sqlite3.Connection, sql: str, params: tuple[object, ...]) -> list[dict[str, object]]:
    cursor = conn.execute(sql, params)
    return [row_to_dict(cursor, row) for row in cursor.fetchall()]


def fetch_one(conn: sqlite3.Connection, sql: str, params: tuple[object, ...]) -> dict[str, object] | None:
    cursor = conn.execute(sql, params)
    row = cursor.fetchone()
    if row is None:
        return None
    return row_to_dict(cursor, row)


def limit_rows(rows: list[dict[str, object]], limit: int | None) -> list[dict[str, object]]:
    if limit is None or limit <= 0:
        return rows
    return rows[:limit]


def object_info(conn: sqlite3.Connection, object_type: str, object_name: str) -> dict[str, object]:
    obj = fetch_one(
        conn,
        """
        SELECT object_id, type, name, file_path, last_update, file_hash
        FROM objects
        WHERE type = ? AND name = ?
        """,
        (object_type, object_name),
    )
    if obj is None:
        return {
            "query": "object-info",
            "object": {"type": object_type, "name": object_name},
            "found": False,
        }

    outgoing = fetch_one(
        conn,
        "SELECT COUNT(*) AS count FROM relations WHERE source_object_id = ?",
        (obj["object_id"],),
    )
    incoming = fetch_one(
        conn,
        "SELECT COUNT(*) AS count FROM relations WHERE target_type = ? AND target_name = ?",
        (object_type, object_name),
    )
    return {
        "query": "object-info",
        "object": obj,
        "found": True,
        "outgoing_relations": outgoing["count"] if outgoing else 0,
        "incoming_relations": incoming["count"] if incoming else 0,
    }


def search_objects(conn: sqlite3.Connection, object_name: str, object_type: str | None, limit: int | None) -> dict[str, object]:
    pattern = object_name.replace("*", "%")
    if "%" not in pattern:
        pattern = f"%{pattern}%"

    params: list[object] = [pattern]
    type_clause = ""
    if object_type:
        type_clause = "AND type = ?"
        params.append(object_type)

    rows = fetch_all(
        conn,
        f"""
        SELECT type, name, file_path, last_update
        FROM objects
        WHERE name LIKE ? {type_clause}
        ORDER BY type, name
        """,
        tuple(params),
    )
    total = len(rows)
    return {
        "query": "search-objects",
        "pattern": object_name,
        "object_type": object_type,
        "total": total,
        "shown": len(limit_rows(rows, limit)),
        "results": limit_rows(rows, limit),
    }


def who_uses(conn: sqlite3.Connection, object_type: str, object_name: str, limit: int | None) -> dict[str, object]:
    rows = fetch_all(
        conn,
        """
        SELECT
            r.relation_id,
            o.type AS source_type,
            o.name AS source_name,
            o.file_path AS source_file,
            r.target_type,
            r.target_name,
            r.relation_kind,
            r.confidence,
            e.line,
            e.column,
            e.snippet,
            e.evidence_role,
            e.extractor_rule
        FROM relations r
        JOIN objects o ON o.object_id = r.source_object_id
        JOIN evidence e ON e.evidence_id = r.evidence_id
        WHERE r.target_type = ? AND r.target_name = ?
        ORDER BY o.type, o.name, e.line
        """,
        (object_type, object_name),
    )
    total = len(rows)
    return {
        "query": "who-uses",
        "object": {"type": object_type, "name": object_name},
        "total": total,
        "shown": len(limit_rows(rows, limit)),
        "results": limit_rows(rows, limit),
    }


def what_uses(conn: sqlite3.Connection, object_type: str, object_name: str, limit: int | None) -> dict[str, object]:
    rows = fetch_all(
        conn,
        """
        SELECT
            r.relation_id,
            o.type AS source_type,
            o.name AS source_name,
            o.file_path AS source_file,
            r.target_type,
            r.target_name,
            r.relation_kind,
            r.confidence,
            e.line,
            e.column,
            e.snippet,
            e.evidence_role,
            e.extractor_rule
        FROM relations r
        JOIN objects o ON o.object_id = r.source_object_id
        JOIN evidence e ON e.evidence_id = r.evidence_id
        WHERE o.type = ? AND o.name = ?
        ORDER BY r.target_type, r.target_name, e.line
        """,
        (object_type, object_name),
    )
    total = len(rows)
    return {
        "query": "what-uses",
        "object": {"type": object_type, "name": object_name},
        "total": total,
        "shown": len(limit_rows(rows, limit)),
        "results": limit_rows(rows, limit),
    }


def impact_basic(conn: sqlite3.Connection, object_type: str, object_name: str, limit: int | None) -> dict[str, object]:
    info = object_info(conn, object_type, object_name)
    if info.get("found") is False:
        return {
            "query": "impact-basic",
            "object": {"type": object_type, "name": object_name},
            "found": False,
            "notice": "Impacto tecnico direto baseado no indice; nao representa impacto runtime completo.",
        }

    incoming = who_uses(conn, object_type, object_name, limit)
    outgoing = what_uses(conn, object_type, object_name, limit)
    return {
        "query": "impact-basic",
        "object": info["object"],
        "found": True,
        "incoming_relations": info.get("incoming_relations", 0),
        "outgoing_relations": info.get("outgoing_relations", 0),
        "incoming_shown": incoming.get("shown", 0),
        "outgoing_shown": outgoing.get("shown", 0),
        "dependents": incoming.get("results", []),
        "dependencies": outgoing.get("results", []),
        "notice": "Impacto tecnico direto baseado no indice; nao representa impacto runtime completo.",
    }


def functional_trace_basic(conn: sqlite3.Connection, object_type: str, object_name: str, limit: int | None) -> dict[str, object]:
    impact = impact_basic(conn, object_type, object_name, None)
    if impact.get("found") is False:
        return {
            "query": "functional-trace-basic",
            "object": {"type": object_type, "name": object_name},
            "found": False,
            "technical_trace": [],
            "xml_reading_plan": [],
            "response_contract": [
                "Evidencia direta",
                "Leitura adicional do XML",
                "Inferencia forte",
                "Hipotese",
            ],
            "notice": "Triagem funcional basica baseada em indice tecnico derivado. Nao representa prova funcional completa nem substitui leitura do XML oficial.",
        }

    trace_rows: list[dict[str, object]] = []
    for direction, section in (("incoming", "dependents"), ("outgoing", "dependencies")):
        rows = impact.get(section, [])
        if not isinstance(rows, list):
            continue
        for row in rows:
            if not isinstance(row, dict):
                continue
            trace_row = dict(row)
            trace_row["direction"] = direction
            trace_rows.append(trace_row)

    def trace_sort_key(row: dict[str, object]) -> tuple[int, int, str, str, int]:
        target_type = str(row.get("target_type", ""))
        relation_kind = str(row.get("relation_kind", ""))
        direction_rank = 0 if row.get("direction") == "incoming" else 1
        # For functional triage, resolved/local objects are usually better first
        # than literal CustomType edges, while still preserving every relation.
        target_rank = 1 if target_type == "CustomType" else 0
        resolved_rank = 0 if "resolved" in relation_kind else 1
        line = row.get("line")
        return (direction_rank, target_rank, resolved_rank, target_type, int(line) if isinstance(line, int) else 0)

    trace_rows = limit_rows(sorted(trace_rows, key=trace_sort_key), limit)

    reading_plan_by_file: dict[str, dict[str, object]] = {}
    obj = impact.get("object")
    if isinstance(obj, dict) and obj.get("file_path"):
        reading_plan_by_file[str(obj["file_path"])] = {
            "file_path": obj["file_path"],
            "reason": "Abrir o XML oficial do objeto principal antes de concluir funcionalmente.",
            "trigger": f"{object_type}:{object_name}",
            "index_limit": "O indice confirma existencia e relacoes tecnicas diretas; nao prova semantica funcional completa.",
        }

    for row in trace_rows:
        source_file = row.get("source_file")
        if not source_file:
            continue
        source = f"{row.get('source_type')}:{row.get('source_name')}"
        target = f"{row.get('target_type')}:{row.get('target_name')}"
        reading_plan_by_file.setdefault(
            str(source_file),
            {
                "file_path": source_file,
                "reason": "Abrir o XML oficial para revisar o trecho ancorado pela evidencia tecnica.",
                "trigger": f"{source} -> {target}",
                "index_limit": "A evidencia indica relacao tecnica direta; a conclusao funcional depende da leitura do XML oficial.",
            },
        )

    return {
        "query": "functional-trace-basic",
        "object": impact["object"],
        "found": True,
        "incoming_relations": impact.get("incoming_relations", 0),
        "outgoing_relations": impact.get("outgoing_relations", 0),
        "technical_trace_shown": len(trace_rows),
        "technical_trace": trace_rows,
        "xml_reading_plan": list(reading_plan_by_file.values()),
        "response_contract": [
            "Evidencia direta",
            "Leitura adicional do XML",
            "Inferencia forte",
            "Hipotese",
        ],
        "notice": "Triagem funcional basica baseada em indice tecnico derivado. Nao representa prova funcional completa nem substitui leitura do XML oficial.",
    }


def show_evidence(
    conn: sqlite3.Connection,
    relation_id: int | None,
    source_type: str | None,
    source_name: str | None,
    target_type: str | None,
    target_name: str | None,
    limit: int | None,
) -> dict[str, object]:
    if relation_id is not None:
        rows = fetch_all(
            conn,
            """
            SELECT
                r.relation_id,
                o.type AS source_type,
                o.name AS source_name,
                o.file_path AS source_file,
                r.target_type,
                r.target_name,
                r.relation_kind,
                r.confidence,
                e.line,
                e.column,
                e.snippet,
                e.evidence_role,
                e.extractor_rule
            FROM relations r
            JOIN objects o ON o.object_id = r.source_object_id
            JOIN evidence e ON e.evidence_id = r.evidence_id
            WHERE r.relation_id = ?
            """,
            (relation_id,),
        )
    else:
        required = [source_type, source_name, target_type, target_name]
        if any(value is None for value in required):
            raise SystemExit("show-evidence requires --relation-id or source/target type and name.")
        rows = fetch_all(
            conn,
            """
            SELECT
                r.relation_id,
                o.type AS source_type,
                o.name AS source_name,
                o.file_path AS source_file,
                r.target_type,
                r.target_name,
                r.relation_kind,
                r.confidence,
                e.line,
                e.column,
                e.snippet,
                e.evidence_role,
                e.extractor_rule
            FROM relations r
            JOIN objects o ON o.object_id = r.source_object_id
            JOIN evidence e ON e.evidence_id = r.evidence_id
            WHERE o.type = ? AND o.name = ? AND r.target_type = ? AND r.target_name = ?
            ORDER BY e.line
            """,
            (source_type, source_name, target_type, target_name),
        )
    total = len(rows)
    return {"query": "show-evidence", "total": total, "shown": len(limit_rows(rows, limit)), "results": limit_rows(rows, limit)}


def format_text(result: dict[str, object]) -> str:
    lines: list[str] = []
    query = result.get("query")
    obj = result.get("object")
    if isinstance(obj, dict):
        if result.get("found") is False:
            lines.append(f"{query}: {obj.get('type')}:{obj.get('name')} not found")
            if query in ("impact-basic", "functional-trace-basic"):
                lines.append(str(result.get("notice")))
            return "\n".join(lines)
        lines.append(f"{query}: {obj.get('type')}:{obj.get('name')}")
    else:
        if query == "search-objects":
            lines.append(f"{query}: {result.get('pattern')}")
        else:
            lines.append(str(query))

    if query == "object-info" and isinstance(obj, dict):
        lines.append(f"file: {obj.get('file_path')}")
        lines.append(f"last_update: {obj.get('last_update')}")
        lines.append(f"incoming_relations: {result.get('incoming_relations', 0)}")
        lines.append(f"outgoing_relations: {result.get('outgoing_relations', 0)}")
        return "\n".join(lines)

    if query == "impact-basic" and isinstance(obj, dict):
        lines.append(f"file: {obj.get('file_path')}")
        lines.append(f"last_update: {obj.get('last_update')}")
        lines.append(f"incoming_relations: {result.get('incoming_relations', 0)}")
        lines.append(f"outgoing_relations: {result.get('outgoing_relations', 0)}")
        lines.append(str(result.get("notice")))
        for section, title in (("dependents", "dependents"), ("dependencies", "dependencies")):
            rows = result.get(section, [])
            shown_key = "incoming_shown" if section == "dependents" else "outgoing_shown"
            total_key = "incoming_relations" if section == "dependents" else "outgoing_relations"
            lines.append(f"{title}: {result.get(shown_key, 0)}/{result.get(total_key, 0)}")
            if not isinstance(rows, list) or not rows:
                lines.append("  (no results)")
                continue
            for row in rows:
                if not isinstance(row, dict):
                    continue
                source = f"{row.get('source_type')}:{row.get('source_name')}"
                target = f"{row.get('target_type')}:{row.get('target_name')}"
                lines.append(
                    f"  - #{row.get('relation_id')} {source} -> {target} "
                    f"[{row.get('relation_kind')}, {row.get('confidence')}]"
                )
                lines.append(
                    f"    {row.get('source_file')}:{row.get('line')} "
                    f"{row.get('evidence_role')} via {row.get('extractor_rule')}"
                )
                lines.append(f"    {row.get('snippet')}")
        return "\n".join(lines)

    if query == "functional-trace-basic" and isinstance(obj, dict):
        lines.append(f"file: {obj.get('file_path')}")
        lines.append(f"last_update: {obj.get('last_update')}")
        lines.append(f"incoming_relations: {result.get('incoming_relations', 0)}")
        lines.append(f"outgoing_relations: {result.get('outgoing_relations', 0)}")
        lines.append(str(result.get("notice")))

        trace_rows = result.get("technical_trace", [])
        lines.append(f"technical_trace: {result.get('technical_trace_shown', 0)}")
        if isinstance(trace_rows, list):
            for row in trace_rows:
                if not isinstance(row, dict):
                    continue
                source = f"{row.get('source_type')}:{row.get('source_name')}"
                target = f"{row.get('target_type')}:{row.get('target_name')}"
                lines.append(
                    f"  - {row.get('direction')} #{row.get('relation_id')} {source} -> {target} "
                    f"[{row.get('relation_kind')}, {row.get('confidence')}]"
                )
                lines.append(
                    f"    {row.get('source_file')}:{row.get('line')} "
                    f"{row.get('evidence_role')} via {row.get('extractor_rule')}"
                )
                lines.append(f"    {row.get('snippet')}")

        reading_plan = result.get("xml_reading_plan", [])
        lines.append("xml_reading_plan:")
        if isinstance(reading_plan, list):
            for item in reading_plan:
                if not isinstance(item, dict):
                    continue
                lines.append(f"  - {item.get('file_path')}")
                lines.append(f"    reason: {item.get('reason')}")
                lines.append(f"    trigger: {item.get('trigger')}")
        lines.append("response_contract: Evidencia direta | Leitura adicional do XML | Inferencia forte | Hipotese")
        return "\n".join(lines)

    total = result.get("total", 0)
    shown = result.get("shown", 0)
    lines.append(f"results: {shown}/{total}")

    rows = result.get("results", [])
    if not isinstance(rows, list) or not rows:
        lines.append("(no results)")
        return "\n".join(lines)

    for row in rows:
        if not isinstance(row, dict):
            continue
        if query == "search-objects":
            lines.append(f"- {row.get('type')}:{row.get('name')}")
            lines.append(f"  {row.get('file_path')} last_update={row.get('last_update')}")
            continue
        source = f"{row.get('source_type')}:{row.get('source_name')}"
        target = f"{row.get('target_type')}:{row.get('target_name')}"
        lines.append(
            f"- #{row.get('relation_id')} {source} -> {target} "
            f"[{row.get('relation_kind')}, {row.get('confidence')}]"
        )
        lines.append(
            f"  {row.get('source_file')}:{row.get('line')} "
            f"{row.get('evidence_role')} via {row.get('extractor_rule')}"
        )
        lines.append(f"  {row.get('snippet')}")
    return "\n".join(lines)


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Query a KB Intelligence SQLite index.")
    parser.add_argument("--index-path", required=True, type=Path)
    parser.add_argument(
        "--query",
        required=True,
        choices=[
            "object-info",
            "search-objects",
            "who-uses",
            "what-uses",
            "show-evidence",
            "impact-basic",
            "functional-trace-basic",
        ],
    )
    parser.add_argument("--object-type")
    parser.add_argument("--object-name")
    parser.add_argument("--relation-id", type=int)
    parser.add_argument("--source-type")
    parser.add_argument("--source-name")
    parser.add_argument("--target-type")
    parser.add_argument("--target-name")
    parser.add_argument("--limit", type=int)
    parser.add_argument("--format", choices=["json", "text"], default="json")
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    if not args.index_path.exists():
        raise SystemExit(f"IndexPath not found: {args.index_path}")

    conn = sqlite3.connect(args.index_path)
    try:
        if args.query == "object-info":
            if not args.object_type or not args.object_name:
                raise SystemExit("object-info requires --object-type and --object-name.")
            result = object_info(conn, args.object_type, args.object_name)
        elif args.query == "search-objects":
            if not args.object_name:
                raise SystemExit("search-objects requires --object-name.")
            result = search_objects(conn, args.object_name, args.object_type, args.limit)
        elif args.query == "who-uses":
            if not args.object_type or not args.object_name:
                raise SystemExit("who-uses requires --object-type and --object-name.")
            result = who_uses(conn, args.object_type, args.object_name, args.limit)
        elif args.query == "what-uses":
            if not args.object_type or not args.object_name:
                raise SystemExit("what-uses requires --object-type and --object-name.")
            result = what_uses(conn, args.object_type, args.object_name, args.limit)
        elif args.query == "impact-basic":
            if not args.object_type or not args.object_name:
                raise SystemExit("impact-basic requires --object-type and --object-name.")
            result = impact_basic(conn, args.object_type, args.object_name, args.limit)
        elif args.query == "functional-trace-basic":
            if not args.object_type or not args.object_name:
                raise SystemExit("functional-trace-basic requires --object-type and --object-name.")
            result = functional_trace_basic(conn, args.object_type, args.object_name, args.limit)
        else:
            result = show_evidence(
                conn,
                args.relation_id,
                args.source_type,
                args.source_name,
                args.target_type,
                args.target_name,
                args.limit,
            )
    finally:
        conn.close()

    if args.format == "text":
        print(format_text(result))
    else:
        print(json.dumps(result, indent=2, ensure_ascii=False))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
