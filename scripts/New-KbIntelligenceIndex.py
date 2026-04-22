#!/usr/bin/env python3
"""
Build a minimal GeneXus KB intelligence SQLite index.

Current scope:
- object inventory for every immediate SourceRoot type folder with XML files
- Source relations among Procedure, WebPanel and DataProvider
- WorkWithForWeb action gxobject links to Procedure and WebPanel
- WorkWithForWeb condition expressions to Procedure
- WorkWithForWeb condition attributes to Procedure
- WorkWithForWeb explicit link tags to WebPanel
- WorkWithForWeb explicit prompt attributes to WebPanel
- WorkWithForWeb explicit transaction binding
- literal ATTCUSTOMTYPE CustomType values
- explicit Source for each table references in Procedure and WebPanel
- qualified Source for each table-prefix references in Procedure and WebPanel
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
PROCEDURE_DIRECT_RE = re.compile(r"\b(?P<name>proc[A-Za-z_][A-Za-z0-9_]*)\s*\(", re.IGNORECASE)
PROCEDURE_DOT_CALL_RE = re.compile(r"\b(?P<name>[A-Za-z_][A-Za-z0-9_]*)\s*\.\s*Call\s*\(", re.IGNORECASE)
WEBPANEL_DOT_LINK_RE = re.compile(r"\b(?P<name>[A-Za-z_][A-Za-z0-9_]*)\s*\.\s*Link\s*\(", re.IGNORECASE)
FOR_EACH_EXPLICIT_TABLE_RE = re.compile(
    r"\bfor\s+each\s+(?P<name>[A-Za-z_][A-Za-z0-9_]*)\b(?!\s*\.)",
    re.IGNORECASE,
)
FOR_EACH_QUALIFIED_TABLE_RE = re.compile(
    r"\bfor\s+each\s+(?P<prefix>[A-Za-z_][A-Za-z0-9_]*)\s*\.\s*(?P<member>[A-Za-z_][A-Za-z0-9_]*)\b",
    re.IGNORECASE,
)
INDEXED_SOURCE_TYPES = ("Procedure", "WebPanel", "DataProvider")
FOR_EACH_SOURCE_TYPES = ("Procedure", "WebPanel")
ACTION_RE = re.compile(r"<action\b(?P<attrs>[^>]*)>", re.IGNORECASE | re.DOTALL)
CONDITION_RE = re.compile(r"<condition\b(?P<attrs>[^>]*)>", re.IGNORECASE | re.DOTALL)
TAG_RE = re.compile(r"<(?P<tag>[A-Za-z][A-Za-z0-9]*)\b(?P<attrs>[^>]*)>", re.IGNORECASE | re.DOTALL)
ATTR_RE = re.compile(r'(?P<name>[A-Za-z_][A-Za-z0-9_]*)="(?P<value>[^"]*)"')
GXOBJECT_RE = re.compile(r"^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}-(?P<name>.+)$")
ATTCUSTOMTYPE_PROPERTY_RE = re.compile(
    r"<Property>\s*<Name>ATTCUSTOMTYPE</Name>\s*<Value>(?P<value>.*?)</Value>\s*</Property>",
    re.IGNORECASE | re.DOTALL,
)
IDBASEDON_PROPERTY_RE = re.compile(
    r"<Property>\s*<Name>idBasedOn</Name>\s*<Value>(?P<value>.*?)</Value>\s*</Property>",
    re.IGNORECASE | re.DOTALL,
)
LEVEL_RE = re.compile(r"<Level\b(?P<attrs>[^>]*)>(?P<body>.*?)</Level>", re.IGNORECASE | re.DOTALL)
LEVEL_ATTRIBUTE_RE = re.compile(
    r"<Attribute\b(?P<attrs>[^>]*)>(?P<name>.*?)</Attribute>",
    re.IGNORECASE | re.DOTALL,
)
KEY_RE = re.compile(r"<Key\b[^>]*>(?P<body>.*?)</Key>", re.IGNORECASE | re.DOTALL)
KEY_ITEM_RE = re.compile(
    r"<Item\b(?P<attrs>[^>]*)>(?P<name>.*?)</Item>",
    re.IGNORECASE | re.DOTALL,
)
INDEX_MEMBER_RE = re.compile(
    r"<Member\b(?P<attrs>[^>]*)>(?P<name>.*?)</Member>",
    re.IGNORECASE | re.DOTALL,
)
SDT_ITEM_RE = re.compile(r"<Item\b(?P<attrs>[^>]*)>(?P<body>.*?)</Item>", re.IGNORECASE | re.DOTALL)
WORKWITH_TRANSACTION_RE = re.compile(r"<transaction\b[^>]*\btransaction=\"(?P<value>[^\"]+)\"", re.IGNORECASE)
WORKWITH_WEBPANEL_LINK_RE = re.compile(r"<link\b[^>]*\bwebpanel=\"(?P<name>[^\"]+)\"", re.IGNORECASE)
WORKWITH_PROMPT_RE = re.compile(r"\bprompt=\"(?P<value>[^\"]+)\"", re.IGNORECASE)


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


def collect_all_objects(source_root: Path) -> dict[str, dict[str, ObjectInfo]]:
    objects_by_type: dict[str, dict[str, ObjectInfo]] = {}
    for folder in sorted(source_root.iterdir(), key=lambda item: item.name.lower()):
        if not folder.is_dir():
            continue
        object_type = folder.name
        objects = collect_objects(source_root, object_type)
        if objects:
            objects_by_type[object_type] = objects
    return objects_by_type


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
    evidence_role: str = "Source efetivo",
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
            evidence_role=evidence_role,
            extractor_rule=extractor_rule,
            confidence="direct",
        )
    )


def compact_snippet(text: str, limit: int = 220) -> str:
    snippet = " ".join(text.strip().split())
    if len(snippet) <= limit:
        return snippet
    return snippet[: limit - 3].rstrip() + "..."


def case_insensitive_lookup(names: set[str], object_type: str) -> dict[str, str]:
    grouped: dict[str, list[str]] = {}
    for name in names:
        grouped.setdefault(name.lower(), []).append(name)
    collisions = {key: sorted(values) for key, values in grouped.items() if len(values) > 1}
    if collisions:
        details = "; ".join(f"{key}: {', '.join(values)}" for key, values in sorted(collisions.items()))
        raise ValueError(f"Ambiguous {object_type} names differing only by case: {details}")
    return {key: values[0] for key, values in grouped.items()}


def direct_call_pattern(names: set[str]) -> re.Pattern[str] | None:
    if not names:
        return None
    alternatives = "|".join(re.escape(name) for name in sorted(names, key=len, reverse=True))
    return re.compile(rf"\b(?P<name>{alternatives})\s*\(", re.IGNORECASE)


def extract_evidence(
    source_root: Path,
    source_objects: Iterable[ObjectInfo],
    procedure_names: set[str],
    webpanel_names: set[str],
    data_provider_names: set[str],
) -> list[Evidence]:
    evidences: list[Evidence] = []
    procedure_lookup = case_insensitive_lookup(procedure_names, "Procedure")
    webpanel_lookup = case_insensitive_lookup(webpanel_names, "WebPanel")
    data_provider_lookup = case_insensitive_lookup(data_provider_names, "DataProvider")
    data_provider_direct_re = direct_call_pattern(data_provider_names)

    for source in source_objects:
        xml_text = read_text(source.path)
        for block in source_blocks(xml_text):
            for offset, line in enumerate(block.text.splitlines()):
                cleaned = active_line(line)
                if not cleaned.strip():
                    continue
                line_no = block.start_line + offset

                for match in PROCEDURE_DOT_CALL_RE.finditer(cleaned):
                    matched_name = match.group("name")
                    target_name = procedure_lookup.get(matched_name.lower())
                    if target_name:
                        add_evidence(
                            evidences,
                            source=source,
                            target_type="Procedure",
                            target_name=target_name,
                            relation_kind="calls_procedure",
                            line=line_no,
                            column=match.start("name") + 1,
                            snippet=cleaned,
                            extractor_rule="procedure_dot_call",
                        )

                for match in PROCEDURE_DIRECT_RE.finditer(cleaned):
                    matched_name = match.group("name")
                    target_name = procedure_lookup.get(matched_name.lower())
                    if target_name:
                        add_evidence(
                            evidences,
                            source=source,
                            target_type="Procedure",
                            target_name=target_name,
                            relation_kind="calls_procedure",
                            line=line_no,
                            column=match.start("name") + 1,
                            snippet=cleaned,
                            extractor_rule="procedure_direct_call",
                        )

                for match in WEBPANEL_DOT_LINK_RE.finditer(cleaned):
                    matched_name = match.group("name")
                    target_name = webpanel_lookup.get(matched_name.lower())
                    if target_name:
                        add_evidence(
                            evidences,
                            source=source,
                            target_type="WebPanel",
                            target_name=target_name,
                            relation_kind="calls_webpanel",
                            line=line_no,
                            column=match.start("name") + 1,
                            snippet=cleaned,
                            extractor_rule="webpanel_dot_link",
                        )

                if data_provider_direct_re:
                    for match in data_provider_direct_re.finditer(cleaned):
                        matched_name = match.group("name")
                        target_name = data_provider_lookup.get(matched_name.lower())
                        if target_name:
                            add_evidence(
                                evidences,
                                source=source,
                                target_type="DataProvider",
                                target_name=target_name,
                                relation_kind="calls_dataprovider",
                                line=line_no,
                                column=match.start("name") + 1,
                                snippet=cleaned,
                                extractor_rule="dataprovider_direct_call",
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


def extract_source_for_each_explicit_table_evidence(
    source_objects: Iterable[ObjectInfo],
    table_names: set[str],
) -> list[Evidence]:
    evidences: list[Evidence] = []
    table_lookup = case_insensitive_lookup(table_names, "Table")

    for source in source_objects:
        xml_text = read_text(source.path)
        for block in source_blocks(xml_text):
            for offset, line in enumerate(block.text.splitlines()):
                cleaned = active_line(line)
                if not cleaned.strip():
                    continue
                line_no = block.start_line + offset

                for match in FOR_EACH_EXPLICIT_TABLE_RE.finditer(cleaned):
                    matched_name = match.group("name")
                    target_name = table_lookup.get(matched_name.lower())
                    if not target_name:
                        continue
                    add_evidence(
                        evidences,
                        source=source,
                        target_type="Table",
                        target_name=target_name,
                        relation_kind="navigates_explicit_table",
                        line=line_no,
                        column=match.start("name") + 1,
                        snippet=cleaned,
                        extractor_rule="source_for_each_explicit_table",
                        evidence_role="Source explicit for each table",
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


def extract_source_for_each_qualified_table_prefix_evidence(
    source_objects: Iterable[ObjectInfo],
    table_names: set[str],
) -> list[Evidence]:
    evidences: list[Evidence] = []
    table_lookup = case_insensitive_lookup(table_names, "Table")

    for source in source_objects:
        xml_text = read_text(source.path)
        for block in source_blocks(xml_text):
            for offset, line in enumerate(block.text.splitlines()):
                cleaned = active_line(line)
                if not cleaned.strip():
                    continue
                line_no = block.start_line + offset

                for match in FOR_EACH_QUALIFIED_TABLE_RE.finditer(cleaned):
                    matched_prefix = match.group("prefix")
                    target_name = table_lookup.get(matched_prefix.lower())
                    if not target_name:
                        continue
                    add_evidence(
                        evidences,
                        source=source,
                        target_type="Table",
                        target_name=target_name,
                        relation_kind="navigates_qualified_table_prefix",
                        line=line_no,
                        column=match.start("prefix") + 1,
                        snippet=cleaned,
                        extractor_rule="source_for_each_qualified_table_prefix",
                        evidence_role="Source qualified for each table prefix",
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


def parse_attributes(raw_attrs: str) -> dict[str, str]:
    return {match.group("name"): html.unescape(match.group("value")) for match in ATTR_RE.finditer(raw_attrs)}


def gxobject_name(value: str) -> str | None:
    match = GXOBJECT_RE.match(value)
    if not match:
        return None
    return match.group("name")


def effective_condition_expression(value: str) -> str:
    return value.split("//", 1)[0]


def extract_workwith_action_evidence(
    workwith_objects: Iterable[ObjectInfo],
    procedure_names: set[str],
    webpanel_names: set[str],
) -> list[Evidence]:
    evidences: list[Evidence] = []
    procedure_lookup = case_insensitive_lookup(procedure_names, "Procedure")
    webpanel_lookup = case_insensitive_lookup(webpanel_names, "WebPanel")

    for source in workwith_objects:
        xml_text = read_text(source.path)
        for match in ACTION_RE.finditer(xml_text):
            attrs = parse_attributes(match.group("attrs"))
            raw_gxobject = attrs.get("gxobject")
            if not raw_gxobject:
                continue
            raw_target_name = gxobject_name(raw_gxobject)
            if not raw_target_name:
                continue

            target_type = None
            target_name = procedure_lookup.get(raw_target_name.lower())
            relation_kind = "workwith_action_calls_procedure"
            if target_name:
                target_type = "Procedure"
            else:
                target_name = webpanel_lookup.get(raw_target_name.lower())
                relation_kind = "workwith_action_calls_webpanel"
                if target_name:
                    target_type = "WebPanel"

            if not target_type or not target_name:
                continue

            add_evidence(
                evidences,
                source=source,
                target_type=target_type,
                target_name=target_name,
                relation_kind=relation_kind,
                line=line_number_at(xml_text, match.start()),
                column=1,
                snippet=match.group(0),
                extractor_rule="workwith_action_gxobject",
                evidence_role="WorkWith action",
            )

    return evidences


def extract_workwith_condition_evidence(
    workwith_objects: Iterable[ObjectInfo],
    procedure_names: set[str],
) -> list[Evidence]:
    evidences: list[Evidence] = []
    procedure_lookup = case_insensitive_lookup(procedure_names, "Procedure")

    for source in workwith_objects:
        xml_text = read_text(source.path)
        for condition_match in CONDITION_RE.finditer(xml_text):
            attrs = parse_attributes(condition_match.group("attrs"))
            condition_value = attrs.get("value")
            if not condition_value:
                continue

            expression = effective_condition_expression(condition_value)
            for procedure_match in PROCEDURE_DIRECT_RE.finditer(expression):
                target_name = procedure_lookup.get(procedure_match.group("name").lower())
                if not target_name:
                    continue
                add_evidence(
                    evidences,
                    source=source,
                    target_type="Procedure",
                    target_name=target_name,
                    relation_kind="workwith_condition_calls_procedure",
                    line=line_number_at(xml_text, condition_match.start()),
                    column=1,
                    snippet=condition_match.group(0),
                    extractor_rule="workwith_condition_procedure",
                    evidence_role="WorkWith condition",
                )

    unique: dict[tuple[str, str, str, int], Evidence] = {}
    for evidence in evidences:
        unique[(evidence.source_name, evidence.target_name, evidence.extractor_rule, evidence.line)] = evidence
    return list(unique.values())


def extract_workwith_condition_attribute_evidence(
    workwith_objects: Iterable[ObjectInfo],
    procedure_names: set[str],
) -> list[Evidence]:
    evidences: list[Evidence] = []
    procedure_lookup = case_insensitive_lookup(procedure_names, "Procedure")

    for source in workwith_objects:
        xml_text = read_text(source.path)
        for tag_match in TAG_RE.finditer(xml_text):
            attrs = parse_attributes(tag_match.group("attrs"))
            for attr_name, attr_value in attrs.items():
                if not attr_name.lower().endswith("condition"):
                    continue

                expression = effective_condition_expression(attr_value)
                for procedure_match in PROCEDURE_DIRECT_RE.finditer(expression):
                    target_name = procedure_lookup.get(procedure_match.group("name").lower())
                    if not target_name:
                        continue
                    add_evidence(
                        evidences,
                        source=source,
                        target_type="Procedure",
                        target_name=target_name,
                        relation_kind="workwith_condition_attribute_calls_procedure",
                        line=line_number_at(xml_text, tag_match.start()),
                        column=1,
                        snippet=tag_match.group(0),
                        extractor_rule="workwith_condition_attribute_procedure",
                        evidence_role="WorkWith condition attribute",
                    )

    unique: dict[tuple[str, str, str, int], Evidence] = {}
    for evidence in evidences:
        unique[(evidence.source_name, evidence.target_name, evidence.extractor_rule, evidence.line)] = evidence
    return list(unique.values())


def extract_workwith_transaction_evidence(
    workwith_objects: Iterable[ObjectInfo],
    transaction_names: set[str],
) -> list[Evidence]:
    evidences: list[Evidence] = []
    transaction_lookup = case_insensitive_lookup(transaction_names, "Transaction")

    for source in workwith_objects:
        xml_text = read_text(source.path)
        for match in WORKWITH_TRANSACTION_RE.finditer(xml_text):
            raw_target_name = gxobject_name(html.unescape(match.group("value")))
            if not raw_target_name:
                continue
            target_name = transaction_lookup.get(raw_target_name.lower())
            if not target_name:
                continue
            add_evidence(
                evidences,
                source=source,
                target_type="Transaction",
                target_name=target_name,
                relation_kind="workwith_references_transaction",
                line=line_number_at(xml_text, match.start()),
                column=1,
                snippet=match.group(0),
                extractor_rule="workwith_transaction_binding",
                evidence_role="WorkWith transaction",
            )

    unique: dict[tuple[str, str, str, int], Evidence] = {}
    for evidence in evidences:
        unique[(evidence.source_name, evidence.target_name, evidence.extractor_rule, evidence.line)] = evidence
    return list(unique.values())


def extract_workwith_webpanel_link_evidence(
    workwith_objects: Iterable[ObjectInfo],
    webpanel_names: set[str],
) -> list[Evidence]:
    evidences: list[Evidence] = []
    webpanel_lookup = case_insensitive_lookup(webpanel_names, "WebPanel")

    for source in workwith_objects:
        xml_text = read_text(source.path)
        for match in WORKWITH_WEBPANEL_LINK_RE.finditer(xml_text):
            raw_target_name = html.unescape(match.group("name"))
            target_name = webpanel_lookup.get(raw_target_name.lower())
            if not target_name:
                continue
            add_evidence(
                evidences,
                source=source,
                target_type="WebPanel",
                target_name=target_name,
                relation_kind="workwith_links_webpanel",
                line=line_number_at(xml_text, match.start()),
                column=1,
                snippet=match.group(0),
                extractor_rule="workwith_link_webpanel",
                evidence_role="WorkWith link",
            )

    unique: dict[tuple[str, str, str, int], Evidence] = {}
    for evidence in evidences:
        unique[(evidence.source_name, evidence.target_name, evidence.extractor_rule, evidence.line)] = evidence
    return list(unique.values())


def extract_workwith_prompt_evidence(
    workwith_objects: Iterable[ObjectInfo],
    webpanel_names: set[str],
) -> list[Evidence]:
    evidences: list[Evidence] = []
    webpanel_lookup = case_insensitive_lookup(webpanel_names, "WebPanel")

    for source in workwith_objects:
        xml_text = read_text(source.path)
        for match in WORKWITH_PROMPT_RE.finditer(xml_text):
            raw_target_name = gxobject_name(html.unescape(match.group("value")))
            if not raw_target_name:
                continue
            target_name = webpanel_lookup.get(raw_target_name.lower())
            if not target_name:
                continue
            add_evidence(
                evidences,
                source=source,
                target_type="WebPanel",
                target_name=target_name,
                relation_kind="workwith_prompts_webpanel",
                line=line_number_at(xml_text, match.start()),
                column=1,
                snippet=match.group(0),
                extractor_rule="workwith_prompt_webpanel",
                evidence_role="WorkWith prompt",
            )

    unique: dict[tuple[str, str, str, int], Evidence] = {}
    for evidence in evidences:
        unique[(evidence.source_name, evidence.target_name, evidence.extractor_rule, evidence.line)] = evidence
    return list(unique.values())


def normalize_custom_type(value: str) -> str:
    return " ".join(html.unescape(value).strip().split())


def extract_attcustomtype_evidence(source_objects: Iterable[ObjectInfo]) -> list[Evidence]:
    evidences: list[Evidence] = []
    for source in source_objects:
        xml_text = read_text(source.path)
        for match in ATTCUSTOMTYPE_PROPERTY_RE.finditer(xml_text):
            target_name = normalize_custom_type(match.group("value"))
            if not target_name:
                continue
            add_evidence(
                evidences,
                source=source,
                target_type="CustomType",
                target_name=target_name,
                relation_kind="uses_custom_type",
                line=line_number_at(xml_text, match.start("value")),
                column=1,
                snippet=match.group(0),
                extractor_rule="attcustomtype_property",
                evidence_role="Property ATTCUSTOMTYPE",
            )
    return evidences


def resolve_custom_type_target(
    custom_type: str,
    sdt_lookup: dict[str, str],
    domain_lookup: dict[str, str],
) -> tuple[str, str] | None:
    if ":" not in custom_type:
        return None
    prefix, raw_name = custom_type.split(":", 1)
    if prefix.lower() == "sdt":
        target_name = sdt_lookup.get(raw_name.lower())
        if target_name:
            return "SDT", target_name
    if prefix.lower() in {"dom", "domain"}:
        target_name = domain_lookup.get(raw_name.lower())
        if target_name:
            return "Domain", target_name
    return None


def extract_attcustomtype_resolved_evidence(
    source_objects: Iterable[ObjectInfo],
    sdt_names: set[str],
    domain_names: set[str],
) -> list[Evidence]:
    evidences: list[Evidence] = []
    sdt_lookup = case_insensitive_lookup(sdt_names, "SDT")
    domain_lookup = case_insensitive_lookup(domain_names, "Domain")
    for source in source_objects:
        xml_text = read_text(source.path)
        for match in ATTCUSTOMTYPE_PROPERTY_RE.finditer(xml_text):
            custom_type = normalize_custom_type(match.group("value"))
            if not custom_type:
                continue
            resolved = resolve_custom_type_target(custom_type, sdt_lookup, domain_lookup)
            if not resolved:
                continue
            target_type, target_name = resolved
            add_evidence(
                evidences,
                source=source,
                target_type=target_type,
                target_name=target_name,
                relation_kind="uses_resolved_custom_type",
                line=line_number_at(xml_text, match.start("value")),
                column=1,
                snippet=match.group(0),
                extractor_rule="attcustomtype_resolved_object",
                evidence_role="Property ATTCUSTOMTYPE",
            )
    return evidences


def extract_sdt_item_attcustomtype_resolved_sdt_evidence(
    source_objects: Iterable[ObjectInfo],
    sdt_names: set[str],
) -> list[Evidence]:
    evidences: list[Evidence] = []
    seen: set[tuple[str, str]] = set()
    sdt_lookup = case_insensitive_lookup(sdt_names, "SDT")
    for source in source_objects:
        xml_text = read_text(source.path)
        for item_match in SDT_ITEM_RE.finditer(xml_text):
            item_body = item_match.group("body")
            match = ATTCUSTOMTYPE_PROPERTY_RE.search(item_body)
            if not match:
                continue
            custom_type = normalize_custom_type(match.group("value"))
            if not custom_type.lower().startswith("sdt:"):
                continue
            raw_sdt_name = custom_type.split(":", 1)[1].strip()
            target_name = sdt_lookup.get(raw_sdt_name.lower())
            if not target_name:
                continue
            pair_key = (source.name.lower(), target_name.lower())
            if pair_key in seen:
                continue
            seen.add(pair_key)
            match_start = item_match.start("body") + match.start()
            add_evidence(
                evidences,
                source=source,
                target_type="SDT",
                target_name=target_name,
                relation_kind="has_sdt_item_type",
                line=line_number_at(xml_text, match_start),
                column=1,
                snippet=match.group(0),
                extractor_rule="sdt_item_attcustomtype_resolved_sdt",
                evidence_role="SDT Item ATTCUSTOMTYPE",
            )
    return evidences


def extract_attribute_idbasedon_domain_evidence(
    source_objects: Iterable[ObjectInfo],
    domain_names: set[str],
) -> list[Evidence]:
    evidences: list[Evidence] = []
    domain_lookup = case_insensitive_lookup(domain_names, "Domain")
    for source in source_objects:
        xml_text = read_text(source.path)
        for match in IDBASEDON_PROPERTY_RE.finditer(xml_text):
            value = normalize_custom_type(match.group("value"))
            if not value.lower().startswith("domain:"):
                continue
            raw_domain_name = value.split(":", 1)[1].strip()
            target_name = domain_lookup.get(raw_domain_name.lower())
            if not target_name:
                continue
            add_evidence(
                evidences,
                source=source,
                target_type="Domain",
                target_name=target_name,
                relation_kind="based_on_domain",
                line=line_number_at(xml_text, match.start("value")),
                column=1,
                snippet=match.group(0),
                extractor_rule="attribute_idbasedon_domain",
                evidence_role="Property idBasedOn",
            )
    return evidences


def extract_transaction_level_attribute_evidence(
    source_objects: Iterable[ObjectInfo],
    attribute_names: set[str],
) -> list[Evidence]:
    evidences: list[Evidence] = []
    attribute_lookup = case_insensitive_lookup(attribute_names, "Attribute")
    for source in source_objects:
        xml_text = read_text(source.path)
        for level_match in LEVEL_RE.finditer(xml_text):
            level_body = level_match.group("body")
            for match in LEVEL_ATTRIBUTE_RE.finditer(level_body):
                raw_attribute_name = html.unescape(match.group("name")).strip()
                if not raw_attribute_name:
                    continue
                target_name = attribute_lookup.get(raw_attribute_name.lower())
                if not target_name:
                    continue
                match_start = level_match.start("body") + match.start()
                add_evidence(
                    evidences,
                    source=source,
                    target_type="Attribute",
                    target_name=target_name,
                    relation_kind="has_level_attribute",
                    line=line_number_at(xml_text, match_start),
                    column=1,
                    snippet=match.group(0),
                    extractor_rule="transaction_level_attribute",
                    evidence_role="Level Attribute",
                )
    return evidences


def extract_transaction_level_table_evidence(
    source_objects: Iterable[ObjectInfo],
    table_names: set[str],
) -> list[Evidence]:
    evidences: list[Evidence] = []
    table_lookup = case_insensitive_lookup(table_names, "Table")
    for source in source_objects:
        xml_text = read_text(source.path)
        for match in LEVEL_RE.finditer(xml_text):
            attrs = parse_attributes(match.group("attrs"))
            raw_table_name = attrs.get("Type", "").strip()
            if not raw_table_name:
                continue
            target_name = table_lookup.get(raw_table_name.lower())
            if not target_name:
                continue
            add_evidence(
                evidences,
                source=source,
                target_type="Table",
                target_name=target_name,
                relation_kind="has_level_table",
                line=line_number_at(xml_text, match.start()),
                column=1,
                snippet=match.group(0).split(">", 1)[0] + ">",
                extractor_rule="transaction_level_table",
                evidence_role="Level Type",
            )
    return evidences


def extract_table_key_attribute_evidence(
    source_objects: Iterable[ObjectInfo],
    attribute_names: set[str],
) -> list[Evidence]:
    evidences: list[Evidence] = []
    attribute_lookup = case_insensitive_lookup(attribute_names, "Attribute")
    for source in source_objects:
        xml_text = read_text(source.path)
        for key_match in KEY_RE.finditer(xml_text):
            key_body = key_match.group("body")
            for match in KEY_ITEM_RE.finditer(key_body):
                raw_attribute_name = html.unescape(match.group("name")).strip()
                if not raw_attribute_name:
                    continue
                target_name = attribute_lookup.get(raw_attribute_name.lower())
                if not target_name:
                    continue
                match_start = key_match.start("body") + match.start()
                add_evidence(
                    evidences,
                    source=source,
                    target_type="Attribute",
                    target_name=target_name,
                    relation_kind="has_key_attribute",
                    line=line_number_at(xml_text, match_start),
                    column=1,
                    snippet=match.group(0),
                    extractor_rule="table_key_attribute",
                    evidence_role="Key Item",
                )
    return evidences


def extract_table_index_member_attribute_evidence(
    source_objects: Iterable[ObjectInfo],
    attribute_names: set[str],
) -> list[Evidence]:
    evidences: list[Evidence] = []
    seen: set[tuple[str, str]] = set()
    attribute_lookup = case_insensitive_lookup(attribute_names, "Attribute")
    for source in source_objects:
        xml_text = read_text(source.path)
        for match in INDEX_MEMBER_RE.finditer(xml_text):
            raw_attribute_name = html.unescape(match.group("name")).strip()
            if not raw_attribute_name:
                continue
            target_name = attribute_lookup.get(raw_attribute_name.lower())
            if not target_name:
                continue
            pair_key = (source.name.lower(), target_name.lower())
            if pair_key in seen:
                continue
            seen.add(pair_key)
            add_evidence(
                evidences,
                source=source,
                target_type="Attribute",
                target_name=target_name,
                relation_kind="has_index_member_attribute",
                line=line_number_at(xml_text, match.start()),
                column=1,
                snippet=match.group(0),
                extractor_rule="table_index_member_attribute",
                evidence_role="Index Member",
            )
    return evidences


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
                ("phase", "2"),
                ("scope", "Procedure,WebPanel,DataProvider,WorkWithForWeb,Transaction"),
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
    validation_cases_path: Path | None,
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

    cases: list[dict[str, object]] = []
    if validation_cases_path:
        raw_cases = json.loads(validation_cases_path.read_text(encoding="utf-8"))
        for raw_case in raw_cases.get("cases", []):
            source_type, source_name = split_typed_name(raw_case["source"])
            target_type, target_name = split_typed_name(raw_case["target"])
            expected_rule = raw_case["expected_rule"]
            should_exist = bool(raw_case.get("should_exist", True))
            relation_exists = has_relation(source_type, source_name, target_type, target_name, expected_rule)
            passed = relation_exists if should_exist else not relation_exists
            case_result = dict(raw_case)
            case_result["status"] = "passed" if passed else "failed"
            cases.append(case_result)

    return {
        "generated_at": datetime.now(timezone.utc).isoformat(),
        "source_root": str(source_root),
        "objects_read_by_type": {key: len(value) for key, value in objects_by_type.items()},
        "objects_written": sum(len(value) for value in objects_by_type.values()),
        "relations_written": len(evidences),
        "validation_cases_path": str(validation_cases_path) if validation_cases_path else None,
        "cases": cases,
    }


def split_typed_name(value: str) -> tuple[str, str]:
    if ":" not in value:
        raise ValueError(f"Expected typed name in Type:Name format: {value}")
    object_type, name = value.split(":", 1)
    return object_type, name


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Build a minimal KB intelligence SQLite index.")
    parser.add_argument("--source-root", required=True, type=Path)
    parser.add_argument("--output-path", required=True, type=Path)
    parser.add_argument("--validation-report-path", type=Path)
    parser.add_argument("--validation-cases-path", type=Path)
    parser.add_argument("--fail-on-validation-failure", action="store_true")
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    source_root = args.source_root.resolve()
    if not source_root.exists():
        raise SystemExit(f"SourceRoot not found: {source_root}")

    objects_by_type = collect_all_objects(source_root)
    procedures = objects_by_type.get("Procedure", {})
    webpanels = objects_by_type.get("WebPanel", {})
    data_providers = objects_by_type.get("DataProvider", {})
    workwiths = objects_by_type.get("WorkWithForWeb", {})
    transactions = objects_by_type.get("Transaction", {})
    attributes = objects_by_type.get("Attribute", {})
    tables = objects_by_type.get("Table", {})
    objects = [obj for by_name in objects_by_type.values() for obj in by_name.values()]

    source_evidences = extract_evidence(
        source_root,
        [obj for obj in objects if obj.object_type in INDEXED_SOURCE_TYPES],
        procedure_names=set(procedures),
        webpanel_names=set(webpanels),
        data_provider_names=set(data_providers),
    )
    source_for_each_explicit_table_evidences = extract_source_for_each_explicit_table_evidence(
        [obj for obj in objects if obj.object_type in FOR_EACH_SOURCE_TYPES],
        table_names=set(tables),
    )
    source_for_each_qualified_table_prefix_evidences = extract_source_for_each_qualified_table_prefix_evidence(
        [obj for obj in objects if obj.object_type in FOR_EACH_SOURCE_TYPES],
        table_names=set(tables),
    )
    workwith_evidences = extract_workwith_action_evidence(
        workwiths.values(),
        procedure_names=set(procedures),
        webpanel_names=set(webpanels),
    )
    workwith_condition_evidences = extract_workwith_condition_evidence(
        workwiths.values(),
        procedure_names=set(procedures),
    )
    workwith_condition_attribute_evidences = extract_workwith_condition_attribute_evidence(
        workwiths.values(),
        procedure_names=set(procedures),
    )
    workwith_transaction_evidences = extract_workwith_transaction_evidence(
        workwiths.values(),
        transaction_names=set(transactions),
    )
    workwith_webpanel_link_evidences = extract_workwith_webpanel_link_evidence(
        workwiths.values(),
        webpanel_names=set(webpanels),
    )
    workwith_prompt_evidences = extract_workwith_prompt_evidence(
        workwiths.values(),
        webpanel_names=set(webpanels),
    )
    relation_scope_objects = [
        *procedures.values(),
        *webpanels.values(),
        *data_providers.values(),
        *workwiths.values(),
        *transactions.values(),
    ]
    custom_type_evidences = extract_attcustomtype_evidence(relation_scope_objects)
    resolved_custom_type_evidences = extract_attcustomtype_resolved_evidence(
        relation_scope_objects,
        sdt_names=set(objects_by_type.get("SDT", {})),
        domain_names=set(objects_by_type.get("Domain", {})),
    )
    sdt_item_attcustomtype_resolved_sdt_evidences = extract_sdt_item_attcustomtype_resolved_sdt_evidence(
        objects_by_type.get("SDT", {}).values(),
        sdt_names=set(objects_by_type.get("SDT", {})),
    )
    attribute_idbasedon_domain_evidences = extract_attribute_idbasedon_domain_evidence(
        attributes.values(),
        domain_names=set(objects_by_type.get("Domain", {})),
    )
    transaction_level_attribute_evidences = extract_transaction_level_attribute_evidence(
        transactions.values(),
        attribute_names=set(attributes),
    )
    transaction_level_table_evidences = extract_transaction_level_table_evidence(
        transactions.values(),
        table_names=set(tables),
    )
    table_key_attribute_evidences = extract_table_key_attribute_evidence(
        tables.values(),
        attribute_names=set(attributes),
    )
    table_index_member_attribute_evidences = extract_table_index_member_attribute_evidence(
        tables.values(),
        attribute_names=set(attributes),
    )
    evidences = [
        *source_evidences,
        *source_for_each_explicit_table_evidences,
        *source_for_each_qualified_table_prefix_evidences,
        *workwith_evidences,
        *workwith_condition_evidences,
        *workwith_condition_attribute_evidences,
        *workwith_transaction_evidences,
        *workwith_webpanel_link_evidences,
        *workwith_prompt_evidences,
        *custom_type_evidences,
        *resolved_custom_type_evidences,
        *sdt_item_attcustomtype_resolved_sdt_evidences,
        *attribute_idbasedon_domain_evidences,
        *transaction_level_attribute_evidences,
        *transaction_level_table_evidences,
        *table_key_attribute_evidences,
        *table_index_member_attribute_evidences,
    ]
    write_index(args.output_path.resolve(), source_root, objects, evidences)

    validation_cases_path = args.validation_cases_path.resolve() if args.validation_cases_path else None
    if validation_cases_path and not validation_cases_path.exists():
        raise SystemExit(f"ValidationCasesPath not found: {validation_cases_path}")

    report = validation_report(source_root, objects_by_type, evidences, validation_cases_path)
    if args.validation_report_path:
        report_path = args.validation_report_path.resolve()
        report_path.parent.mkdir(parents=True, exist_ok=True)
        report_path.write_text(json.dumps(report, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")

    print(json.dumps(report, indent=2, ensure_ascii=False))
    if args.fail_on_validation_failure:
        failed_cases = [case for case in report["cases"] if case.get("status") == "failed"]
        if failed_cases:
            return 2
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
