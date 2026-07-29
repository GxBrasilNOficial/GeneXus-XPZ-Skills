#!/usr/bin/env python3
"""Query the KB Intelligence SQLite index."""

from __future__ import annotations

import argparse
import html
import json
import re
import sqlite3
import sys
from pathlib import Path

_SCRIPT_DIR = Path(__file__).resolve().parent
if str(_SCRIPT_DIR) not in sys.path:
    sys.path.insert(0, str(_SCRIPT_DIR))

from GeneXusObjectTypeCatalogCore import (  # noqa: E402
    CatalogOverrideDiagnosticError,
    resolve_effective_object_type_catalog_for_query,
)


EXPECTED_SCHEMA_VERSION = "4"
LEVEL_RE = re.compile(r"<Level\b(?P<attrs>[^>]*)>(?P<body>.*?)</Level>", re.IGNORECASE | re.DOTALL)
LEVEL_ATTRIBUTE_RE = re.compile(
    r"<Attribute\b(?P<attrs>[^>]*)>(?P<name>.*?)</Attribute>",
    re.IGNORECASE | re.DOTALL,
)
XML_ATTR_RE = re.compile(r'(?P<name>[A-Za-z_][A-Za-z0-9_]*)="(?P<value>[^"]*)"')
PROPERTY_RE = re.compile(
    r"<Property>\s*<Name>(?P<name>.*?)</Name>\s*<Value>(?P<value>.*?)</Value>\s*</Property>",
    re.IGNORECASE | re.DOTALL,
)
INSTANCE_KEY_GUID_PREFIX_RE = re.compile(
    r"^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}-"
)

SEMANTIC_QUERIES = frozenset(
    {"who-uses", "what-uses", "impact-basic", "functional-trace-basic"}
)
EXIT_QUERY_NOT_SEMANTIC_FOR_TYPE = 11
EXIT_CATALOG_OVERRIDE_BLOCKED = 2
_CATALOG_TYPES_CACHE: dict[tuple[str | None, str | None, str], dict[str, dict[str, object]]] = {}


def _catalog_cache_key(
    index_path: Path,
    parallel_kb_root: Path | None,
    catalog_override_path: Path | None,
) -> tuple[str | None, str | None, str]:
    parallel_key = str(parallel_kb_root.resolve()) if parallel_kb_root is not None else None
    override_key = (
        str(catalog_override_path.resolve()) if catalog_override_path is not None else None
    )
    return parallel_key, override_key, str(index_path.resolve())


def load_catalog_types_by_name(
    index_path: Path,
    parallel_kb_root: Path | None = None,
    catalog_override_path: Path | None = None,
) -> dict[str, dict[str, object]]:
    """Effective catalog (base + optional override), aligned with Build-KbIntelligenceIndex."""
    cache_key = _catalog_cache_key(index_path, parallel_kb_root, catalog_override_path)
    cached = _CATALOG_TYPES_CACHE.get(cache_key)
    if cached is not None:
        return cached

    merged, _override_path = resolve_effective_object_type_catalog_for_query(
        index_path,
        parallel_kb_root=parallel_kb_root,
        catalog_override_path=catalog_override_path,
    )
    types_by_name = merged["types"]
    if not isinstance(types_by_name, dict):
        raise RuntimeError("Invalid effective object type catalog: missing types map")

    _CATALOG_TYPES_CACHE[cache_key] = types_by_name
    return types_by_name


def semantic_query_allowed(
    object_type: str,
    types_by_name: dict[str, dict[str, object]],
) -> tuple[bool, dict[str, object] | None]:
    """Return whether semantic index queries are allowed for this canonical type name."""
    entry = types_by_name.get(object_type)
    if entry is None:
        return True, None
    return bool(entry.get("queryableByKbIntelligence", True)), entry


def build_semantic_blocked_result(
    query: str,
    object_type: str,
    object_name: str,
    entry: dict[str, object] | None,
) -> dict[str, object]:
    inventory_eligible = entry.get("inventoryEligible") if entry is not None else None
    return {
        "query": query,
        "blocked": True,
        "reason": "QUERY_NOT_SEMANTIC_FOR_TYPE",
        "object": {"type": object_type, "name": object_name},
        "catalog": {
            "queryableByKbIntelligence": False,
            "inventoryEligible": inventory_eligible,
        },
        "notice": (
            "Tipo apto a inventario (object-info, search-objects, list-by-type), nao a "
            "who-uses/what-uses/impact-basic/functional-trace-basic com o extrator atual. "
            "Grafos vazios nao significam ausencia de impacto do addon ou da configuracao."
        ),
        "suggested_queries": ["object-info", "search-objects", "list-by-type"],
    }


def format_semantic_blocked_text(result: dict[str, object]) -> str:
    obj = result.get("object")
    if not isinstance(obj, dict):
        obj = {}
    lines = [
        f"{result.get('query')}: BLOCKED ({result.get('reason')})",
        f"object: {obj.get('type')}:{obj.get('name')}",
        str(result.get("notice")),
        "suggested_queries: " + ", ".join(result.get("suggested_queries", [])),
    ]
    return "\n".join(lines)


def build_catalog_override_blocked_result(exc: CatalogOverrideDiagnosticError) -> dict[str, object]:
    diagnostic = dict(exc.diagnostic)
    return {
        "blocked": True,
        "reason": diagnostic.get("reason"),
        "status": diagnostic.get("status", "OVERRIDE_RESOLUTION_BLOCKED"),
        "diagnosticReason": diagnostic.get("diagnosticReason"),
        "fieldPath": diagnostic.get("fieldPath"),
        "overridePath": diagnostic.get("overridePath"),
        "message": diagnostic.get("message", str(exc)),
        "catalogOverrideDiagnostic": diagnostic,
    }


def format_catalog_override_blocked_text(result: dict[str, object]) -> str:
    return "\n".join(
        [
            f"catalog override: BLOCKED ({result.get('status')})",
            f"reason: {result.get('reason')} / {result.get('diagnosticReason')}",
            f"field: {result.get('fieldPath')}",
            f"override: {result.get('overridePath')}",
            str(result.get("message")),
        ]
    )


def validate_schema_version(conn: sqlite3.Connection) -> None:
    row = conn.execute(
        "SELECT value FROM metadata WHERE key = 'schema_version'"
    ).fetchone()
    if row is None:
        raise SystemExit(
            "Index schema version not found in metadata. "
            "This index was built by an older engine that predates schema versioning. "
            "Rebuild the index with Build-KbIntelligenceIndex before querying."
        )
    index_version = row[0]
    if index_version != EXPECTED_SCHEMA_VERSION:
        raise SystemExit(
            f"Index schema version mismatch: index has {index_version}, "
            f"engine expects {EXPECTED_SCHEMA_VERSION}. "
            "Rebuild the index before querying."
        )
    cursor = conn.execute("PRAGMA table_info(objects)")
    columns = {row[1] for row in cursor.fetchall()}
    if "guid" not in columns:
        raise SystemExit(
            "Index schema is missing required column 'guid' in objects table. "
            "Rebuild the index with the current engine before querying."
        )


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


def metadata_map(conn: sqlite3.Connection) -> dict[str, str]:
    rows = fetch_all(conn, "SELECT key, value FROM metadata", ())
    return {str(row["key"]): str(row["value"]) for row in rows}


def resolve_index_file(conn: sqlite3.Connection, file_path: object) -> Path:
    path = Path(str(file_path))
    if path.is_absolute():
        return path
    source_root = metadata_map(conn).get("source_root")
    if not source_root:
        raise SystemExit("Index metadata does not expose source_root; rebuild index before file-backed queries.")
    return Path(source_root) / path


def read_indexed_text(conn: sqlite3.Connection, file_path: object) -> str:
    resolved = resolve_index_file(conn, file_path)
    if not resolved.is_file():
        raise SystemExit(f"Indexed XML file not found on disk: {resolved}")
    return resolved.read_text(encoding="utf-8-sig")


def parse_xml_attrs(raw_attrs: str) -> dict[str, str]:
    return {match.group("name"): html.unescape(match.group("value")) for match in XML_ATTR_RE.finditer(raw_attrs)}


def parse_properties(xml_text: str) -> dict[str, str]:
    properties: dict[str, str] = {}
    for match in PROPERTY_RE.finditer(xml_text):
        name = html.unescape(match.group("name")).strip()
        value = html.unescape(match.group("value")).strip()
        if name:
            properties[name] = value
    return properties


def fetch_object(conn: sqlite3.Connection, object_type: str, object_name: str) -> dict[str, object] | None:
    return fetch_one(
        conn,
        """
        SELECT object_id, type, name, guid, file_path, last_update, file_hash, is_generated_object, pattern_object_id, instance_key
        FROM objects
        WHERE type = ? AND LOWER(name) = LOWER(?)
        """,
        (object_type, object_name),
    )


def limit_rows(rows: list[dict[str, object]], limit: int | None) -> list[dict[str, object]]:
    if limit is None or limit <= 0:
        return rows
    return rows[:limit]


def generated_filter_clause(generated_filter: str | None) -> str:
    """Clausula SQL literal para o filtro autoral x gerado (sem params; valores literais 0/1)."""
    if generated_filter == "generated":
        return "AND is_generated_object = 1"
    if generated_filter == "authored":
        return "AND is_generated_object = 0"
    return ""


def generated_filter_from_args(args: argparse.Namespace) -> str | None:
    if getattr(args, "generated", False):
        return "generated"
    if getattr(args, "authored", False):
        return "authored"
    return None


def derive_instance_name(instance_key: object) -> str | None:
    """Nome da instancia WorkWithForWeb derivado do instance_key.

    Convencao GeneXus: <GUID canonico 8-4-4-4-12>-<nome>. Ancora no GUID + primeiro
    hifen; nunca faz split cego (o GUID tem hifens internos). Hifens dentro do nome
    sao preservados. NULL / nao-canonico / nome vazio -> None (nao derivavel).
    """
    if instance_key is None:
        return None
    text = str(instance_key)
    match = INSTANCE_KEY_GUID_PREFIX_RE.match(text)
    if not match:
        return None
    name = text[match.end():]
    return name or None


def classify_instance_filter(value: str) -> dict[str, str]:
    """Classifica o argumento --instance-key em modo full-key ou instance-name.

    full-key sse o valor comeca com GUID canonico + hifen E ha nome depois; caso
    contrario, instance-name. Uma chave <GUID>- sem nome nao e chave valida -> erro.
    A auto-deteccao e contrato documentado (ver README-kb-intelligence.md).
    """
    match = INSTANCE_KEY_GUID_PREFIX_RE.match(value)
    if match:
        if match.end() >= len(value):
            raise SystemExit(
                "--instance-key: chave completa exige <GUID>-<nome>; nome ausente apos o GUID."
            )
        return {"mode": "full-key", "value": value}
    return {"mode": "instance-name", "value": value}


def index_metadata(conn: sqlite3.Connection) -> dict[str, object]:
    rows = fetch_all(
        conn,
        """
        SELECT key, value
        FROM metadata
        ORDER BY key
        """,
        (),
    )
    metadata = {str(row["key"]): row["value"] for row in rows}
    last_index_build_run_at = metadata.get("last_index_build_run_at")
    if not last_index_build_run_at:
        raise SystemExit(
            "index-metadata requires metadata.last_index_build_run_at; "
            "legacy or incompatible index detected, regenerate before using it for triage."
        )
    return {
        "query": "index-metadata",
        "metadata": metadata,
        "last_index_build_run_at": last_index_build_run_at,
    }


def object_info(conn: sqlite3.Connection, object_type: str, object_name: str) -> dict[str, object]:
    obj = fetch_object(conn, object_type, object_name)
    if obj is None:
        return {
            "query": "object-info",
            "object": {"type": object_type, "name": object_name},
            "found": False,
        }

    obj["instance_name"] = derive_instance_name(obj.get("instance_key"))
    outgoing = fetch_one(
        conn,
        "SELECT COUNT(*) AS count FROM relations WHERE source_object_id = ?",
        (obj["object_id"],),
    )
    incoming = fetch_one(
        conn,
        "SELECT COUNT(*) AS count FROM relations WHERE target_type = ? AND LOWER(target_name) = LOWER(?)",
        (object_type, object_name),
    )
    return {
        "query": "object-info",
        "object": obj,
        "found": True,
        "outgoing_relations": outgoing["count"] if outgoing else 0,
        "incoming_relations": incoming["count"] if incoming else 0,
    }


def attribute_info(conn: sqlite3.Connection, attribute_name: str) -> dict[str, object]:
    obj = fetch_object(conn, "Attribute", attribute_name)
    if obj is None:
        return {
            "query": "attribute-info",
            "attribute": attribute_name,
            "found": False,
        }
    xml_text = read_indexed_text(conn, obj["file_path"])
    properties = parse_properties(xml_text)
    formula_expression = properties.get("Formula")
    based_on = properties.get("idBasedOn")
    return {
        "query": "attribute-info",
        "attribute": obj["name"],
        "found": True,
        "object": obj,
        "isFormula": formula_expression is not None,
        "formulaExpression": formula_expression,
        "basedOn": based_on,
        "properties": properties,
    }


def nullable_bool_from_sqlite(value: object) -> bool | None:
    if value is None:
        return None
    return bool(int(value))


def fetch_materialized_writability_rows(
    conn: sqlite3.Connection,
    transaction_name: str,
) -> list[dict[str, object]]:
    materialized = fetch_all(
        conn,
        """
        SELECT
            w.transaction_name,
            w.level_name,
            w.attribute_name,
            w.key_in_level,
            w.is_redundant,
            w.classification,
            w.writable,
            w.can_assign_in_new,
            w.reason,
            w.evidence,
            w.writability_rule_version,
            o.file_path AS attribute_file
        FROM transaction_attribute_writability w
        JOIN objects o_tx ON o_tx.object_id = w.transaction_object_id
        LEFT JOIN objects o ON o.type = 'Attribute' AND LOWER(o.name) = LOWER(w.attribute_name)
        WHERE LOWER(o_tx.name) = LOWER(?)
        ORDER BY w.level_name, w.attribute_name
        """,
        (transaction_name,),
    )
    rows: list[dict[str, object]] = []
    for row in materialized:
        attr_name = str(row["attribute_name"])
        attr_payload = attribute_info(conn, attr_name)
        is_formula = bool(attr_payload.get("isFormula")) if attr_payload.get("found") else None
        writable = nullable_bool_from_sqlite(row.get("writable"))
        rows.append(
            {
                "transaction": row["transaction_name"],
                "levelName": row["level_name"],
                "attribute": attr_name,
                "key": bool(row["key_in_level"]),
                "isRedundant": bool(row["is_redundant"]),
                "isFormula": is_formula,
                "formulaExpression": attr_payload.get("formulaExpression"),
                "classification": row["classification"],
                "writable": writable,
                "canAssignInNew": nullable_bool_from_sqlite(row.get("can_assign_in_new")),
                "reason": row["reason"],
                "evidence": row["evidence"],
                "writabilityRuleVersion": row["writability_rule_version"],
                "attributeFile": row.get("attribute_file"),
            }
        )
    return rows


def transaction_attribute_rows(conn: sqlite3.Connection, transaction_name: str) -> tuple[dict[str, object] | None, list[dict[str, object]]]:
    obj = fetch_object(conn, "Transaction", transaction_name)
    if obj is None:
        return None, []
    rows = fetch_materialized_writability_rows(conn, transaction_name)
    if rows:
        return obj, rows
    return obj, []


def transaction_attributes(conn: sqlite3.Connection, transaction_name: str) -> dict[str, object]:
    obj, rows = transaction_attribute_rows(conn, transaction_name)
    if obj is None:
        return {
            "query": "transaction-attributes",
            "transaction": transaction_name,
            "found": False,
        }
    return {
        "query": "transaction-attributes",
        "transaction": obj,
        "found": True,
        "total": len(rows),
        "results": rows,
    }


def transaction_writable_attributes(conn: sqlite3.Connection, transaction_name: str) -> dict[str, object]:
    obj, rows = transaction_attribute_rows(conn, transaction_name)
    if obj is None:
        return {
            "query": "transaction-writable-attributes",
            "transaction": transaction_name,
            "found": False,
        }
    return {
        "query": "transaction-writable-attributes",
        "transaction": obj,
        "found": True,
        "total": len(rows),
        "results": rows,
        "notice": (
            "Classificacao materializada no indice (paridade com Test-GeneXusTransactionWritability.ps1). "
            "Atributos unclassified-* exigem leitura adicional do XML antes de gerar New ou atribuicoes."
        ),
    }


def search_objects(conn: sqlite3.Connection, object_name: str | None, object_type: str | None, limit: int | None, generated_filter: str | None = None, instance_filter: dict[str, str] | None = None) -> dict[str, object]:
    # WHERE dinamico: object_name pode ser None quando so -InstanceKey e usado.
    where: list[str] = []
    params: list[object] = []
    if object_name:
        pattern = object_name.replace("*", "%")
        if "%" not in pattern:
            pattern = f"%{pattern}%"
        where.append("name LIKE ?")
        params.append(pattern)
    if object_type:
        where.append("type = ?")
        params.append(object_type)
    if instance_filter and instance_filter["mode"] == "full-key":
        # chave completa: comparacao exata ignorando caixa (LOWER SQLite, ASCII).
        where.append("LOWER(instance_key) = LOWER(?)")
        params.append(instance_filter["value"])
    if generated_filter == "generated":
        where.append("is_generated_object = 1")
    elif generated_filter == "authored":
        where.append("is_generated_object = 0")
    where_sql = ("WHERE " + " AND ".join(where)) if where else ""

    rows = fetch_all(
        conn,
        f"""
        SELECT type, name, guid, file_path, last_update, is_generated_object, pattern_object_id, instance_key
        FROM objects
        {where_sql}
        ORDER BY type, name
        """,
        tuple(params),
    )
    if instance_filter and instance_filter["mode"] == "instance-name":
        # nome plano: correspondencia exata ignorando caixa contra o nome derivado.
        target = instance_filter["value"].casefold()
        rows = [
            r for r in rows
            if (dn := derive_instance_name(r.get("instance_key"))) is not None and dn.casefold() == target
        ]
    for r in rows:
        r["instance_name"] = derive_instance_name(r.get("instance_key"))
    total = len(rows)
    return {
        "query": "search-objects",
        "pattern": object_name,
        "object_type": object_type,
        "generated_filter": generated_filter,
        "instance_filter": instance_filter,
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
        WHERE r.target_type = ? AND LOWER(r.target_name) = LOWER(?)
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
        WHERE o.type = ? AND LOWER(o.name) = LOWER(?)
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

    def custom_type_payload(target_name: object) -> str | None:
        value = str(target_name)
        if ":" not in value:
            return None
        return value.split(":", 1)[1].split(",", 1)[0].strip().lower()

    resolved_keys: set[tuple[object, object, object, str]] = set()
    for row in trace_rows:
        if row.get("target_type") == "CustomType":
            continue
        if "resolved" not in str(row.get("extractor_rule")):
            continue
        key = (row.get("direction"), row.get("source_file"), row.get("line"), str(row.get("target_name")).lower())
        resolved_keys.add(key)

    filtered_trace_rows: list[dict[str, object]] = []
    suppressed_custom_type_count = 0
    for row in trace_rows:
        if row.get("target_type") == "CustomType":
            payload = custom_type_payload(row.get("target_name"))
            key = (row.get("direction"), row.get("source_file"), row.get("line"), payload or "")
            if payload and key in resolved_keys:
                suppressed_custom_type_count += 1
                continue
        filtered_trace_rows.append(row)
    trace_rows = filtered_trace_rows

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
        "suppressed_redundant_custom_type_relations": suppressed_custom_type_count,
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


def list_by_type(conn: sqlite3.Connection, object_type: str, limit: int | None, generated_filter: str | None = None) -> dict[str, object]:
    generated_clause = generated_filter_clause(generated_filter)
    rows = fetch_all(
        conn,
        f"""
        SELECT type, name, guid, file_path, last_update, is_generated_object, pattern_object_id, instance_key
        FROM objects
        WHERE type = ? {generated_clause}
        ORDER BY name
        """,
        (object_type,),
    )
    for r in rows:
        r["instance_name"] = derive_instance_name(r.get("instance_key"))
    total = len(rows)
    return {
        "query": "list-by-type",
        "object_type": object_type,
        "generated_filter": generated_filter,
        "total": total,
        "shown": len(limit_rows(rows, limit)),
        "results": limit_rows(rows, limit),
    }


def css_classes(
    conn: sqlite3.Connection,
    class_name: str | None,
    model: str | None,
    origin: str | None,
    include_imported: bool,
    limit: int | None,
) -> dict[str, object]:
    where: list[str] = []
    params: list[object] = []
    if class_name:
        if "*" in class_name:
            where.append("class_name LIKE ?")
            params.append(class_name.replace("*", "%"))
        else:
            # Casamento exato e case-sensitive: classes CSS sao case-sensitive.
            where.append("class_name = ?")
            params.append(class_name)
    if model:
        where.append("model = ?")
        params.append(model)
    if origin:
        where.append("origin = ?")
        params.append(origin)
    elif not include_imported and not class_name:
        # Visao padrao (sem lookup nominal e sem origin explicito): so classes autorais da KB.
        # Um lookup por nome NUNCA filtra origem, para nao produzir falso "nao existe" de classe importada.
        where.append("origin = 'kb-authored'")
    clause = ("WHERE " + " AND ".join(where)) if where else ""
    rows = fetch_all(
        conn,
        f"""
        SELECT class_name, model, origin, defining_object_type,
               defining_object_name, defining_file, parent_class, extractor_rule
        FROM css_class
        {clause}
        ORDER BY model, class_name, defining_object_name
        """,
        tuple(params),
    )
    for row in rows:
        row["deprecated"] = row.get("model") == "legacy-theme"
    total = len(rows)
    return {
        "query": "css-classes",
        "filters": {
            "class_name": class_name,
            "model": model,
            "origin": origin,
            "include_imported": include_imported,
        },
        "total": total,
        "shown": len(limit_rows(rows, limit)),
        "results": limit_rows(rows, limit),
        "notice": (
            "model='legacy-theme' marcado deprecated=true (modelo antigo, candidato a migracao para DesignSystem). "
            "Sem lookup nominal e sem --origin, a visao lista so origin='kb-authored'; use --include-imported "
            "ou --origin packaged-module para classes de libs importadas."
        ),
    }


def css_class_usage(
    conn: sqlite3.Connection,
    class_name: str | None,
    limit: int | None,
) -> dict[str, object]:
    dynamic_row = fetch_one(
        conn,
        "SELECT COUNT(*) AS count FROM relations WHERE relation_kind = 'uses_css_class_dynamic'",
        (),
    )
    dynamic_total = dynamic_row["count"] if dynamic_row else 0
    honest_notice = (
        "Cobertura honesta: resolvable_uses sao usos com nome literal da classe (layout + codigo). "
        "dynamic_uses_total e o total de atribuicoes .Class= dinamicas (variavel/Format) no acervo, "
        "NAO atribuiveis a uma classe especifica por nome. found_in_catalog=false indica classe usada "
        "mas nao catalogada (ex.: importada nao varrida), nao inexistente. Operacao destrutiva exige "
        "conferencia por busca literal no XML."
    )

    if not class_name:
        resolvable_row = fetch_one(
            conn,
            "SELECT COUNT(*) AS count FROM relations WHERE relation_kind = 'uses_css_class'",
            (),
        )
        uncatalogued_rows = fetch_all(
            conn,
            """
            SELECT DISTINCT r.target_name AS class_name
            FROM relations r
            WHERE r.relation_kind = 'uses_css_class'
              AND r.target_name NOT IN (SELECT class_name FROM css_class)
            ORDER BY r.target_name
            """,
            (),
        )
        uncatalogued = [str(row["class_name"]) for row in uncatalogued_rows]
        return {
            "query": "css-class-usage",
            "scope": "overview",
            "resolvable_uses_total": resolvable_row["count"] if resolvable_row else 0,
            "dynamic_uses_total": dynamic_total,
            "used_but_uncatalogued_total": len(uncatalogued),
            "used_but_uncatalogued": uncatalogued if limit is None or limit <= 0 else uncatalogued[:limit],
            "notice": honest_notice,
        }

    catalog = fetch_all(
        conn,
        """
        SELECT class_name, model, origin, defining_object_type, defining_object_name, defining_file, parent_class
        FROM css_class
        WHERE class_name = ?
        ORDER BY model, defining_object_name
        """,
        (class_name,),
    )
    uses = fetch_all(
        conn,
        """
        SELECT
            o.type AS source_type,
            o.name AS source_name,
            o.file_path AS source_file,
            r.relation_kind,
            e.evidence_role,
            e.line,
            e.snippet
        FROM relations r
        JOIN objects o ON o.object_id = r.source_object_id
        JOIN evidence e ON e.evidence_id = r.evidence_id
        WHERE r.target_type = 'CssClass' AND r.target_name = ? AND r.relation_kind = 'uses_css_class'
        ORDER BY o.type, o.name, e.evidence_role
        """,
        (class_name,),
    )
    return {
        "query": "css-class-usage",
        "scope": "class",
        "class_name": class_name,
        "found_in_catalog": len(catalog) > 0,
        "catalog": catalog,
        "resolvable_uses_total": len(uses),
        "resolvable_uses_shown": len(limit_rows(uses, limit)),
        "resolvable_uses": limit_rows(uses, limit),
        "dynamic_uses_total": dynamic_total,
        "notice": honest_notice,
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
            WHERE o.type = ? AND LOWER(o.name) = LOWER(?) AND r.target_type = ? AND LOWER(r.target_name) = LOWER(?)
            ORDER BY e.line
            """,
            (source_type, source_name, target_type, target_name),
        )
    total = len(rows)
    return {"query": "show-evidence", "total": total, "shown": len(limit_rows(rows, limit)), "results": limit_rows(rows, limit)}


def format_text(result: dict[str, object]) -> str:
    if result.get("blocked") is True:
        return format_semantic_blocked_text(result)

    lines: list[str] = []
    query = result.get("query")
    if query == "index-metadata":
        metadata = result.get("metadata")
        lines.append("index-metadata")
        lines.append(f"last_index_build_run_at: {result.get('last_index_build_run_at')}")
        if isinstance(metadata, dict):
            for key in sorted(metadata):
                if key == "last_index_build_run_at":
                    continue
                lines.append(f"{key}: {metadata[key]}")
        return "\n".join(lines)

    if query == "css-classes":
        lines.append(f"css-classes: {result.get('shown', 0)}/{result.get('total', 0)}")
        if result.get("notice"):
            lines.append(str(result.get("notice")))
        rows = result.get("results", [])
        if isinstance(rows, list):
            for row in rows:
                if not isinstance(row, dict):
                    continue
                deprecated = " [deprecated]" if row.get("deprecated") else ""
                lines.append(
                    f"- {row.get('class_name')} [{row.get('model')}/{row.get('origin')}]{deprecated}"
                )
                lines.append(
                    f"  def: {row.get('defining_object_type')}:{row.get('defining_object_name')} "
                    f"({row.get('defining_file')})"
                    + (f" parent={row.get('parent_class')}" if row.get("parent_class") else "")
                )
        return "\n".join(lines)

    if query == "css-class-usage":
        if result.get("scope") == "overview":
            lines.append("css-class-usage: overview")
            lines.append(f"resolvable_uses_total: {result.get('resolvable_uses_total', 0)}")
            lines.append(f"dynamic_uses_total: {result.get('dynamic_uses_total', 0)}")
            lines.append(f"used_but_uncatalogued_total: {result.get('used_but_uncatalogued_total', 0)}")
            uncat = result.get("used_but_uncatalogued", [])
            if isinstance(uncat, list):
                for name in uncat:
                    lines.append(f"  - {name}")
            if result.get("notice"):
                lines.append(str(result.get("notice")))
            return "\n".join(lines)
        lines.append(f"css-class-usage: {result.get('class_name')}")
        lines.append(f"found_in_catalog: {result.get('found_in_catalog')}")
        catalog = result.get("catalog", [])
        if isinstance(catalog, list):
            for entry in catalog:
                if not isinstance(entry, dict):
                    continue
                lines.append(
                    f"  catalog: [{entry.get('model')}/{entry.get('origin')}] "
                    f"{entry.get('defining_object_type')}:{entry.get('defining_object_name')}"
                )
        lines.append(
            f"resolvable_uses: {result.get('resolvable_uses_shown', 0)}/{result.get('resolvable_uses_total', 0)}"
        )
        uses = result.get("resolvable_uses", [])
        if isinstance(uses, list):
            for row in uses:
                if not isinstance(row, dict):
                    continue
                lines.append(
                    f"  - {row.get('source_type')}:{row.get('source_name')} "
                    f"[{row.get('evidence_role')}] {row.get('source_file')}"
                )
                lines.append(f"    {row.get('snippet')}")
        lines.append(f"dynamic_uses_total: {result.get('dynamic_uses_total', 0)}")
        if result.get("notice"):
            lines.append(str(result.get("notice")))
        return "\n".join(lines)

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
            inst = result.get("instance_filter")
            inst_val = inst.get("value") if isinstance(inst, dict) else None
            pat = result.get("pattern")
            if pat and inst_val:
                lines.append(f"{query}: {pat} (instance: {inst_val})")
            elif inst_val:
                lines.append(f"{query}: (instance: {inst_val})")
            else:
                lines.append(f"{query}: {pat}")
        elif query == "list-by-type":
            lines.append(f"{query}: {result.get('object_type')}")
        else:
            lines.append(str(query))

    if query == "object-info" and isinstance(obj, dict):
        lines.append(f"guid: {obj.get('guid')}")
        lines.append(f"file: {obj.get('file_path')}")
        lines.append(f"last_update: {obj.get('last_update')}")
        lines.append(f"generated: {obj.get('is_generated_object')}")
        lines.append(f"pattern_object_id: {obj.get('pattern_object_id')}")
        lines.append(f"instance_key: {obj.get('instance_key')}")
        lines.append(f"instance_name: {obj.get('instance_name')}")
        lines.append(f"incoming_relations: {result.get('incoming_relations', 0)}")
        lines.append(f"outgoing_relations: {result.get('outgoing_relations', 0)}")
        return "\n".join(lines)

    if query == "attribute-info":
        if result.get("found") is False:
            lines.append(f"attribute-info: {result.get('attribute')} not found")
            return "\n".join(lines)
        lines.append(f"attribute-info: {result.get('attribute')}")
        obj_payload = result.get("object")
        if isinstance(obj_payload, dict):
            lines.append(f"file: {obj_payload.get('file_path')}")
        lines.append(f"isFormula: {result.get('isFormula')}")
        if result.get("formulaExpression") is not None:
            lines.append(f"formulaExpression: {result.get('formulaExpression')}")
        if result.get("basedOn") is not None:
            lines.append(f"basedOn: {result.get('basedOn')}")
        return "\n".join(lines)

    if query in ("transaction-attributes", "transaction-writable-attributes"):
        tx = result.get("transaction")
        if result.get("found") is False:
            lines.append(f"{query}: {tx} not found")
            return "\n".join(lines)
        if isinstance(tx, dict):
            lines.append(f"{query}: {tx.get('name')}")
            lines.append(f"file: {tx.get('file_path')}")
        notice = result.get("notice")
        if notice:
            lines.append(str(notice))
        rows = result.get("results", [])
        lines.append(f"results: {len(rows) if isinstance(rows, list) else 0}/{result.get('total', 0)}")
        if isinstance(rows, list):
            for row in rows:
                if not isinstance(row, dict):
                    continue
                lines.append(
                    f"- [{row.get('levelName')}] {row.get('attribute')} "
                    f"classification={row.get('classification')} writable={row.get('writable')} reason={row.get('reason')}"
                )
        return "\n".join(lines)

    if query == "impact-basic" and isinstance(obj, dict):
        lines.append(f"guid: {obj.get('guid')}")
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
        lines.append(f"guid: {obj.get('guid')}")
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
        if query in ("search-objects", "list-by-type"):
            lines.append(f"- {row.get('type')}:{row.get('name')}")
            line2 = f"  guid={row.get('guid')} {row.get('file_path')} last_update={row.get('last_update')} generated={row.get('is_generated_object')}"
            if row.get("instance_name"):
                line2 += f" instance_name={row.get('instance_name')}"
            lines.append(line2)
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
            "attribute-info",
            "search-objects",
            "list-by-type",
            "transaction-attributes",
            "transaction-writable-attributes",
            "who-uses",
            "what-uses",
            "show-evidence",
            "impact-basic",
            "functional-trace-basic",
            "index-metadata",
            "css-classes",
            "css-class-usage",
        ],
    )
    parser.add_argument("--object-type")
    parser.add_argument("--object-name")
    parser.add_argument("--model", help="Filtro de modelo para css-classes: legacy-theme | design-system.")
    parser.add_argument("--origin", help="Filtro de origem para css-classes: kb-authored | packaged-module.")
    parser.add_argument(
        "--include-imported",
        action="store_true",
        help="css-classes: inclui classes de PackagedModule (libs importadas) na visao sem lookup nominal.",
    )
    generated_group = parser.add_mutually_exclusive_group()
    generated_group.add_argument(
        "--generated",
        action="store_true",
        help="search-objects/list-by-type: apenas objetos gerados por Pattern (is_generated_object=1).",
    )
    generated_group.add_argument(
        "--authored",
        action="store_true",
        help="search-objects/list-by-type: apenas objetos autorais (is_generated_object=0).",
    )
    parser.add_argument(
        "--instance-key",
        help="search-objects: filtra pela instancia WorkWithForWeb (nome plano ou chave completa <GUID>-<nome>).",
    )
    parser.add_argument("--relation-id", type=int)
    parser.add_argument("--source-type")
    parser.add_argument("--source-name")
    parser.add_argument("--target-type")
    parser.add_argument("--target-name")
    parser.add_argument("--limit", type=int)
    parser.add_argument("--format", choices=["json", "text"], default="json")
    parser.add_argument(
        "--parallel-kb-root",
        type=Path,
        help="Raiz da pasta paralela da KB; resolve scripts/gx-object-type-catalog.override.json.",
    )
    parser.add_argument(
        "--catalog-override-path",
        type=Path,
        help="Caminho explicito do override de catalogo (prevalece sobre deteccao por parallel-kb-root).",
    )
    return parser.parse_args()


def main() -> int:
    args = parse_args()

    if args.instance_key is not None and args.query != "search-objects":
        raise SystemExit("--instance-key is only valid with search-objects.")

    if args.query in SEMANTIC_QUERIES and args.object_type:
        try:
            catalog_types = load_catalog_types_by_name(
                args.index_path,
                parallel_kb_root=args.parallel_kb_root,
                catalog_override_path=args.catalog_override_path,
            )
        except CatalogOverrideDiagnosticError as exc:
            blocked_override = build_catalog_override_blocked_result(exc)
            if args.format == "text":
                print(format_catalog_override_blocked_text(blocked_override))
            else:
                print(json.dumps(blocked_override, indent=2, ensure_ascii=False))
            return EXIT_CATALOG_OVERRIDE_BLOCKED
        allowed, entry = semantic_query_allowed(args.object_type, catalog_types)
        if not allowed:
            blocked = build_semantic_blocked_result(
                args.query,
                args.object_type,
                args.object_name or "",
                entry,
            )
            if args.format == "text":
                print(format_semantic_blocked_text(blocked))
            else:
                print(json.dumps(blocked, indent=2, ensure_ascii=False))
            return EXIT_QUERY_NOT_SEMANTIC_FOR_TYPE

    if not args.index_path.exists():
        raise SystemExit(f"IndexPath not found: {args.index_path}")

    conn = sqlite3.connect(args.index_path)
    try:
        validate_schema_version(conn)
        if args.query == "index-metadata":
            result = index_metadata(conn)
        elif args.query == "object-info":
            if not args.object_type or not args.object_name:
                raise SystemExit("object-info requires --object-type and --object-name.")
            result = object_info(conn, args.object_type, args.object_name)
        elif args.query == "attribute-info":
            if not args.object_name:
                raise SystemExit("attribute-info requires --object-name.")
            result = attribute_info(conn, args.object_name)
        elif args.query == "search-objects":
            if not args.object_name and not args.instance_key:
                raise SystemExit("search-objects requires --object-name or --instance-key.")
            instance_filter = classify_instance_filter(args.instance_key) if args.instance_key else None
            result = search_objects(conn, args.object_name, args.object_type, args.limit, generated_filter_from_args(args), instance_filter)
        elif args.query == "list-by-type":
            if not args.object_type:
                raise SystemExit("list-by-type requires --object-type.")
            result = list_by_type(conn, args.object_type, args.limit, generated_filter_from_args(args))
        elif args.query == "transaction-attributes":
            if not args.object_name:
                raise SystemExit("transaction-attributes requires --object-name.")
            result = transaction_attributes(conn, args.object_name)
        elif args.query == "transaction-writable-attributes":
            if not args.object_name:
                raise SystemExit("transaction-writable-attributes requires --object-name.")
            result = transaction_writable_attributes(conn, args.object_name)
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
        elif args.query == "css-classes":
            result = css_classes(
                conn,
                args.object_name,
                args.model,
                args.origin,
                args.include_imported,
                args.limit,
            )
        elif args.query == "css-class-usage":
            result = css_class_usage(conn, args.object_name, args.limit)
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
