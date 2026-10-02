#!/usr/bin/env python3
"""Canonical Transaction attribute writability classification for KbIntelligence (parity with Test-GeneXusTransactionWritability.ps1)."""

from __future__ import annotations

import argparse
import hashlib
import json
import re
import sys
import uuid
import io
import xml.sax
import xml.sax.handler
import xml.etree.ElementTree as ElementTree
from dataclasses import dataclass, field
from pathlib import Path

from GeneXusCanonicalJson import canonical_text


WRITABILITY_RULE_VERSION = "3"

LEVEL_OPEN_RE = re.compile(
    r'<Level\s+[^>]*name="(?P<name>[^"]+)"[^>]*>',
    re.IGNORECASE,
)
ATTRIBUTE_RE = re.compile(
    r"<Attribute\s+(?P<attrs>[^>]*?)>(?P<name>[^<]+)</Attribute>",
    re.IGNORECASE,
)
KEY_ATTR_RE = re.compile(r'\bkey\s*=\s*"(?P<v>[^"]*)"', re.IGNORECASE)
IS_REDUNDANT_RE = re.compile(r'\bisRedundant\s*=\s*"(?P<v>[^"]*)"', re.IGNORECASE)
FORMULA_PROPERTY_RE = re.compile(
    r"<Property>\s*<Name>Formula</Name>\s*<Value>(?P<v>.*?)</Value>\s*</Property>",
    re.IGNORECASE | re.DOTALL,
)
SUBTYPE_BLOCK_RE = re.compile(
    r"<Subtype\b[^>]*>\s*<Name>(?P<sub>[^<]+)</Name>\s*<Supertype\b[^>]*>(?P<sup>[^<]+)</Supertype>\s*</Subtype>",
    re.IGNORECASE | re.DOTALL,
)
DUPLICATE_INDEX_RE = re.compile(
    r'<Index\b[^>]*\bType\s*=\s*"Duplicate"[^>]*>(?P<body>.*?)</Index>',
    re.IGNORECASE | re.DOTALL,
)
MEMBER_RE = re.compile(r"<Member\b[^>]*>(?P<n>[^<]+)</Member>", re.IGNORECASE)
OBJECT_TYPE_GUID_RE = re.compile(r'<Object\b[^>]*\btype="([^"]+)"', re.IGNORECASE)
OBJECT_NAME_ATTR_RE = re.compile(r'<Object\b[^>]*\bname="(?P<name>[^"]+)"', re.IGNORECASE)
OBJECT_LEVEL_PROPERTIES_RE = re.compile(
    r"</Part>\s*<Properties>(?P<body>.*?)</Properties>\s*</Object>",
    re.IGNORECASE | re.DOTALL,
)
TRANSACTION_NAME_RE = re.compile(
    r"<Property>\s*<Name>Name</Name>\s*<Value>(?P<value>.*?)</Value>\s*</Property>",
    re.IGNORECASE | re.DOTALL,
)


@dataclass(frozen=True)
class LevelAttributeRef:
    level_name: str
    attribute_name: str
    key: bool
    is_redundant: bool


@dataclass(frozen=True)
class AttributeWritability:
    transaction_name: str
    level_name: str
    attribute_name: str
    key: bool
    is_redundant: bool
    classification: str
    writable: bool | None
    can_assign_in_new: bool | None
    reason: str
    evidence: str


@dataclass
class _TransactionLevelEntry:
    name: str
    pk_attrs: list[str]
    non_key_attrs: set[str]


def read_text(path: Path) -> str:
    return path.read_text(encoding="utf-8-sig", errors="replace")


def get_transaction_type_guid(catalog_types: dict[str, dict[str, object]]) -> str:
    entry = catalog_types.get("Transaction", {})
    guid = entry.get("objectTypeGuid")
    if not isinstance(guid, str) or not guid:
        raise ValueError("Transaction objectTypeGuid missing in catalog")
    return guid


def resolve_transaction_name(text: str, fallback: str) -> str:
    """Match Test-GeneXusTransactionWritability.ps1: Object/Properties/Property Name, not nested Variable names."""
    props_match = OBJECT_LEVEL_PROPERTIES_RE.search(text)
    if props_match:
        name_match = TRANSACTION_NAME_RE.search(props_match.group("body"))
        if name_match:
            value = name_match.group("value").strip()
            if value:
                return value
    object_name_match = OBJECT_NAME_ATTR_RE.search(text)
    if object_name_match:
        value = object_name_match.group("name").strip()
        if value:
            return value
    return fallback


def get_transaction_metadata(path: Path, transaction_type_guid: str) -> tuple[str, str] | None:
    text = read_text(path)
    type_match = OBJECT_TYPE_GUID_RE.search(text)
    if not type_match or type_match.group(1) != transaction_type_guid:
        return None
    name = resolve_transaction_name(text, path.stem)
    return name, text


def get_levels_and_attributes(transaction_xml: str) -> list[LevelAttributeRef]:
    results: list[LevelAttributeRef] = []
    level_matches = list(LEVEL_OPEN_RE.finditer(transaction_xml))
    if not level_matches:
        return results
    for index, level_match in enumerate(level_matches):
        start = level_match.end()
        end = level_matches[index + 1].start() if index + 1 < len(level_matches) else len(transaction_xml)
        chunk = transaction_xml[start:end]
        level_name = level_match.group("name")
        for attr_match in ATTRIBUTE_RE.finditer(chunk):
            attrs_str = attr_match.group("attrs")
            name = attr_match.group("name").strip()
            if not name:
                continue
            key_match = KEY_ATTR_RE.search(attrs_str)
            key = bool(key_match and key_match.group("v") == "True")
            red_match = IS_REDUNDANT_RE.search(attrs_str)
            is_redundant = bool(red_match and red_match.group("v") == "True")
            results.append(
                LevelAttributeRef(
                    level_name=level_name,
                    attribute_name=name,
                    key=key,
                    is_redundant=is_redundant,
                )
            )
    return results


def build_subtype_index(corpus_folder: Path) -> dict[str, str]:
    index: dict[str, str] = {}
    folder = corpus_folder / "SubTypeGroup"
    if not folder.is_dir():
        return index
    for path in folder.glob("*.xml"):
        text = read_text(path)
        for match in SUBTYPE_BLOCK_RE.finditer(text):
            sub_name = match.group("sub").strip()
            sup_name = match.group("sup").strip()
            if sub_name and sup_name:
                index.setdefault(sub_name.lower(), sup_name)
    return index


def first_level_attributes(transaction_xml: str) -> list[LevelAttributeRef]:
    """Paridade com Build-TransactionLevelIndex no Test-GeneXusTransactionWritability.ps1 (somente o primeiro Level)."""
    level_matches = list(LEVEL_OPEN_RE.finditer(transaction_xml))
    if not level_matches:
        return []
    first = level_matches[0]
    start = first.end()
    end = level_matches[1].start() if len(level_matches) > 1 else len(transaction_xml)
    chunk = transaction_xml[start:end]
    results: list[LevelAttributeRef] = []
    level_name = first.group("name")
    for attr_match in ATTRIBUTE_RE.finditer(chunk):
        attrs_str = attr_match.group("attrs")
        name = attr_match.group("name").strip()
        if not name:
            continue
        key_match = KEY_ATTR_RE.search(attrs_str)
        key = bool(key_match and key_match.group("v") == "True")
        red_match = IS_REDUNDANT_RE.search(attrs_str)
        is_redundant = bool(red_match and red_match.group("v") == "True")
        results.append(
            LevelAttributeRef(
                level_name=level_name,
                attribute_name=name,
                key=key,
                is_redundant=is_redundant,
            )
        )
    return results


def build_transaction_level_index(corpus_folder: Path, transaction_type_guid: str) -> dict[str, _TransactionLevelEntry]:
    index: dict[str, _TransactionLevelEntry] = {}
    folder = corpus_folder / "Transaction"
    if not folder.is_dir():
        return index
    for path in folder.glob("*.xml"):
        meta = get_transaction_metadata(path, transaction_type_guid)
        if meta is None:
            continue
        tx_name, text = meta
        level_attrs = first_level_attributes(text)
        pk_attrs: list[str] = []
        non_key_attrs: set[str] = set()
        for la in level_attrs:
            if la.key:
                pk_attrs.append(la.attribute_name)
            else:
                non_key_attrs.add(la.attribute_name)
        index[tx_name.lower()] = _TransactionLevelEntry(name=tx_name, pk_attrs=pk_attrs, non_key_attrs=non_key_attrs)
    return index


def build_primary_key_attribute_set(corpus_folder: Path, transaction_type_guid: str) -> set[str]:
    pk_set: set[str] = set()
    folder = corpus_folder / "Transaction"
    if not folder.is_dir():
        return pk_set
    for path in folder.glob("*.xml"):
        meta = get_transaction_metadata(path, transaction_type_guid)
        if meta is None:
            continue
        _, text = meta
        for la in get_levels_and_attributes(text):
            if la.key:
                pk_set.add(la.attribute_name)
    return pk_set


def find_attribute_xml_path(attribute_name: str, corpus_folder: Path) -> Path | None:
    candidate = corpus_folder / "Attribute" / f"{attribute_name}.xml"
    return candidate if candidate.is_file() else None


def attribute_has_formula(attribute_xml_path: Path) -> bool:
    return bool(FORMULA_PROPERTY_RE.search(read_text(attribute_xml_path)))


def find_table_xml_path(transaction_name: str, corpus_folder: Path) -> Path | None:
    candidate = corpus_folder / "Table" / f"{transaction_name}.xml"
    return candidate if candidate.is_file() else None


def get_duplicate_indexes_from_table(table_xml_path: Path) -> list[list[str]]:
    text = read_text(table_xml_path)
    result: list[list[str]] = []
    for idx_match in DUPLICATE_INDEX_RE.finditer(text):
        members = [member_match.group("n").strip() for member_match in MEMBER_RE.finditer(idx_match.group("body"))]
        members = [member for member in members if member]
        if members:
            result.append(members)
    return result


def find_fk_entity_for_index(
    members: list[str],
    transaction_level_index: dict[str, _TransactionLevelEntry],
) -> _TransactionLevelEntry | None:
    for entry in transaction_level_index.values():
        pk = entry.pk_attrs
        if len(pk) != len(members):
            continue
        if all(pk[i].lower() == members[i].lower() for i in range(len(pk))):
            return entry
    return None


def attribute_in_fk_entity_recursive(
    attribute_name: str,
    table_xml_path: Path,
    transaction_level_index: dict[str, _TransactionLevelEntry],
    corpus_folder: Path,
    max_depth: int,
    visited_tables: set[str],
) -> bool:
    if max_depth <= 0:
        return False
    table_key = str(table_xml_path.resolve()).lower()
    if table_key in visited_tables:
        return False
    visited_tables.add(table_key)
    for members in get_duplicate_indexes_from_table(table_xml_path):
        fk_entity = find_fk_entity_for_index(members, transaction_level_index)
        if fk_entity is None:
            continue
        if attribute_name.lower() in {name.lower() for name in fk_entity.non_key_attrs}:
            return True
        fk_table_path = find_table_xml_path(fk_entity.name, corpus_folder)
        if fk_table_path is None:
            continue
        if attribute_in_fk_entity_recursive(
            attribute_name,
            fk_table_path,
            transaction_level_index,
            corpus_folder,
            max_depth - 1,
            visited_tables,
        ):
            return True
    return False


def classify_transaction_attributes(
    transaction_path: Path,
    corpus_folder: Path,
    transaction_type_guid: str,
    *,
    subtype_index: dict[str, str] | None = None,
    pk_attr_set: set[str] | None = None,
    transaction_level_index: dict[str, _TransactionLevelEntry] | None = None,
) -> list[AttributeWritability]:
    meta = get_transaction_metadata(transaction_path, transaction_type_guid)
    if meta is None:
        raise ValueError(f"Not a Transaction XML: {transaction_path}")
    tx_name, tx_text = meta
    level_attrs = get_levels_and_attributes(tx_text)

    if subtype_index is None:
        subtype_index = build_subtype_index(corpus_folder)
    if pk_attr_set is None:
        pk_attr_set = build_primary_key_attribute_set(corpus_folder, transaction_type_guid)
    if transaction_level_index is None:
        transaction_level_index = build_transaction_level_index(corpus_folder, transaction_type_guid)

    table_xml_path = find_table_xml_path(tx_name, corpus_folder)
    dup_indexes = get_duplicate_indexes_from_table(table_xml_path) if table_xml_path else []

    results: list[AttributeWritability] = []
    for la in level_attrs:
        if la.key:
            results.append(
                AttributeWritability(
                    transaction_name=tx_name,
                    level_name=la.level_name,
                    attribute_name=la.attribute_name,
                    key=True,
                    is_redundant=la.is_redundant,
                    classification="key-attribute",
                    writable=True,
                    can_assign_in_new=True,
                    reason="key-attribute",
                    evidence=f'key="True" no Level \'{la.level_name}\'',
                )
            )
            continue
        if la.is_redundant:
            results.append(
                AttributeWritability(
                    transaction_name=tx_name,
                    level_name=la.level_name,
                    attribute_name=la.attribute_name,
                    key=False,
                    is_redundant=True,
                    classification="extended-parent-fk",
                    writable=False,
                    can_assign_in_new=False,
                    reason="extended-parent-fk",
                    evidence=f'isRedundant="True" no Level \'{la.level_name}\'',
                )
            )
            continue
        attr_path = find_attribute_xml_path(la.attribute_name, corpus_folder)
        if attr_path is None:
            results.append(
                AttributeWritability(
                    transaction_name=tx_name,
                    level_name=la.level_name,
                    attribute_name=la.attribute_name,
                    key=False,
                    is_redundant=False,
                    classification="unclassified-attribute-not-found",
                    writable=None,
                    can_assign_in_new=None,
                    reason="unclassified-attribute-not-found",
                    evidence=f"Attribute XML '{la.attribute_name}.xml' nao encontrado em CorpusFolder/Attribute/",
                )
            )
            continue
        if attribute_has_formula(attr_path):
            results.append(
                AttributeWritability(
                    transaction_name=tx_name,
                    level_name=la.level_name,
                    attribute_name=la.attribute_name,
                    key=False,
                    is_redundant=False,
                    classification="formula",
                    writable=False,
                    can_assign_in_new=False,
                    reason="formula",
                    evidence=f"Property Formula presente em {attr_path}",
                )
            )
            continue
        subtype_key = la.attribute_name.lower()
        if subtype_key in subtype_index:
            supertype_name = subtype_index[subtype_key]
            if supertype_name in pk_attr_set:
                results.append(
                    AttributeWritability(
                        transaction_name=tx_name,
                        level_name=la.level_name,
                        attribute_name=la.attribute_name,
                        key=False,
                        is_redundant=False,
                        classification="extended-subtype-key",
                        writable=True,
                        can_assign_in_new=True,
                        reason="extended-subtype-key",
                        evidence=(
                            f"membro de SubTypeGroup com Supertype '{supertype_name}' "
                            "que e PK em alguma Transaction"
                        ),
                    )
                )
            else:
                results.append(
                    AttributeWritability(
                        transaction_name=tx_name,
                        level_name=la.level_name,
                        attribute_name=la.attribute_name,
                        key=False,
                        is_redundant=False,
                        classification="extended-subtype-descriptive",
                        writable=False,
                        can_assign_in_new=False,
                        reason="extended-subtype-descriptive",
                        evidence=(
                            f"membro de SubTypeGroup com Supertype '{supertype_name}' "
                            "que nao e PK em nenhuma Transaction"
                        ),
                    )
                )
            continue
        if table_xml_path is None:
            results.append(
                AttributeWritability(
                    transaction_name=tx_name,
                    level_name=la.level_name,
                    attribute_name=la.attribute_name,
                    key=False,
                    is_redundant=False,
                    classification="unclassified-table-not-found",
                    writable=None,
                    can_assign_in_new=None,
                    reason="unclassified-table-not-found",
                    evidence=(
                        f"Table XML correspondente ('{tx_name}.xml') nao encontrado em "
                        "CorpusFolder/Table/; sinais 5/6/7 nao podem ser avaliados"
                    ),
                )
            )
            continue
        found_in_duplicate = any(
            la.attribute_name.lower() == member.lower()
            for dup in dup_indexes
            for member in dup
        )
        if found_in_duplicate:
            results.append(
                AttributeWritability(
                    transaction_name=tx_name,
                    level_name=la.level_name,
                    attribute_name=la.attribute_name,
                    key=False,
                    is_redundant=False,
                    classification="extended-fk-key",
                    writable=True,
                    can_assign_in_new=True,
                    reason="extended-fk-key",
                    evidence=(
                        f"atributo aparece como Member em Duplicate index da Table '{tx_name}'; "
                        "FK column armazenada nesta table"
                    ),
                )
            )
            continue
        visited_tables: set[str] = set()
        is_fk_descriptive = attribute_in_fk_entity_recursive(
            la.attribute_name,
            table_xml_path,
            transaction_level_index,
            corpus_folder,
            10,
            visited_tables,
        )
        if is_fk_descriptive:
            results.append(
                AttributeWritability(
                    transaction_name=tx_name,
                    level_name=la.level_name,
                    attribute_name=la.attribute_name,
                    key=False,
                    is_redundant=False,
                    classification="extended-fk-descriptive",
                    writable=False,
                    can_assign_in_new=False,
                    reason="extended-fk-descriptive",
                    evidence=(
                        f"atributo aparece como key=False em alguma FK entity (resolucao recursiva "
                        f"ate profundidade 10 a partir da Table '{tx_name}')"
                    ),
                )
            )
            continue
        results.append(
            AttributeWritability(
                transaction_name=tx_name,
                level_name=la.level_name,
                attribute_name=la.attribute_name,
                key=False,
                is_redundant=False,
                classification="own-physical",
                writable=True,
                can_assign_in_new=True,
                reason="own-physical",
                evidence=(
                    "atributo ausente em FK entities em todas as profundidades exploradas (max 10); "
                    "proprio da tabela fisica desta Transaction"
                ),
            )
        )
    return results


def build_corpus_writability(
    corpus_folder: Path,
    transaction_type_guid: str,
) -> list[AttributeWritability]:
    subtype_index = build_subtype_index(corpus_folder)
    pk_attr_set = build_primary_key_attribute_set(corpus_folder, transaction_type_guid)
    transaction_level_index = build_transaction_level_index(corpus_folder, transaction_type_guid)
    rows: list[AttributeWritability] = []
    tx_folder = corpus_folder / "Transaction"
    if not tx_folder.is_dir():
        return rows
    for path in sorted(tx_folder.glob("*.xml")):
        if get_transaction_metadata(path, transaction_type_guid) is None:
            continue
        rows.extend(
            classify_transaction_attributes(
                path,
                corpus_folder,
                transaction_type_guid,
                subtype_index=subtype_index,
                pk_attr_set=pk_attr_set,
                transaction_level_index=transaction_level_index,
            )
        )
    return rows


def load_transaction_type_guid(catalog_path: Path) -> str:
    catalog = json.loads(catalog_path.read_text(encoding="utf-8-sig"))
    types = catalog.get("types", {})
    if not isinstance(types, dict):
        raise ValueError("Invalid catalog: missing types map")
    return get_transaction_type_guid(types)


def attribute_writability_to_gate_row(row: AttributeWritability) -> dict[str, object]:
    return {
        "levelName": row.level_name,
        "attributeName": row.attribute_name,
        "key": row.key,
        "isRedundant": row.is_redundant,
        "classification": row.classification,
        "writable": row.writable,
        "evidence": row.evidence,
    }


def attribute_writability_to_map_entry(row: AttributeWritability) -> dict[str, object]:
    return {
        "attributeName": row.attribute_name,
        "levelName": row.level_name,
        "key": row.key,
        "isRedundant": row.is_redundant,
        "classification": row.classification,
        "writable": row.writable,
        "evidence": row.evidence,
    }


def classify_transaction_gate_payload(
    transaction_path: Path,
    corpus_folder: Path,
    transaction_type_guid: str,
) -> dict[str, object]:
    transaction_path = transaction_path.resolve()
    corpus_folder = corpus_folder.resolve()
    if not transaction_path.is_file():
        raise ValueError(f"TransactionPath not found: {transaction_path}")
    if not corpus_folder.is_dir():
        raise ValueError(f"CorpusFolder not found: {corpus_folder}")
    meta = get_transaction_metadata(transaction_path, transaction_type_guid)
    if meta is None:
        raise ValueError(f"TransactionPath is not a valid Transaction XML: {transaction_path}")
    tx_name, _ = meta
    rows = classify_transaction_attributes(transaction_path, corpus_folder, transaction_type_guid)
    return {
        "status": "pass",
        "transactionName": tx_name,
        "transactionPath": str(transaction_path),
        "coverage": "complete-1.5.a-1.5.b-1.5.c",
        "writabilityRuleVersion": WRITABILITY_RULE_VERSION,
        "levelAttributes": [attribute_writability_to_gate_row(row) for row in rows],
    }


def classify_transactions_batch_payload(
    transaction_paths: list[Path],
    corpus_folder: Path,
    transaction_type_guid: str,
) -> dict[str, object]:
    corpus_folder = corpus_folder.resolve()
    if not corpus_folder.is_dir():
        raise ValueError(f"CorpusFolder not found: {corpus_folder}")
    subtype_index = build_subtype_index(corpus_folder)
    pk_attr_set = build_primary_key_attribute_set(corpus_folder, transaction_type_guid)
    transaction_level_index = build_transaction_level_index(corpus_folder, transaction_type_guid)
    transactions: dict[str, dict[str, object]] = {}
    for raw_path in transaction_paths:
        transaction_path = Path(raw_path).resolve()
        if not transaction_path.is_file():
            raise ValueError(f"TransactionPath not found: {transaction_path}")
        meta = get_transaction_metadata(transaction_path, transaction_type_guid)
        if meta is None:
            continue
        tx_name, _ = meta
        rows = classify_transaction_attributes(
            transaction_path,
            corpus_folder,
            transaction_type_guid,
            subtype_index=subtype_index,
            pk_attr_set=pk_attr_set,
            transaction_level_index=transaction_level_index,
        )
        attributes: dict[str, dict[str, object]] = {}
        for row in rows:
            attributes[row.attribute_name.lower()] = attribute_writability_to_map_entry(row)
        transactions[tx_name.lower()] = {
            "transactionName": tx_name,
            "transactionPath": str(transaction_path),
            "attributes": attributes,
        }
    return {
        "writabilityRuleVersion": WRITABILITY_RULE_VERSION,
        "transactions": transactions,
    }


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="GeneXus Transaction writability core (canonical classifier).")
    subparsers = parser.add_subparsers(dest="command", required=True)

    single = subparsers.add_parser(
        "classify-transaction",
        help="Classify one Transaction XML (Test-GeneXusTransactionWritability.ps1 contract).",
    )
    single.add_argument("--transaction-path", type=Path, required=True)
    single.add_argument("--corpus-folder", type=Path, required=True)
    single.add_argument(
        "--catalog-path",
        type=Path,
        default=Path(__file__).resolve().parent / "gx-object-type-catalog.json",
    )

    batch = subparsers.add_parser(
        "classify-batch",
        help="Classify multiple Transaction XML files into attribute maps keyed by transaction/attribute.",
    )
    batch.add_argument("--corpus-folder", type=Path, required=True)
    batch.add_argument(
        "--transaction-paths-file",
        type=Path,
        required=True,
        help="JSON array of absolute Transaction XML paths.",
    )
    batch.add_argument(
        "--catalog-path",
        type=Path,
        default=Path(__file__).resolve().parent / "gx-object-type-catalog.json",
    )
    return parser.parse_args()


@dataclass
class _AttributeObject:
    name: str
    guid: str | None
    path: str
    formula: bool


@dataclass
class _AttributeRefV2:
    name: str
    guid: str | None
    key: bool
    is_redundant: bool
    identity_source: str
    issue: str | None = None


@dataclass
class _LevelV2:
    transaction: dict[str, object]
    part_type: str
    name: str
    guid: str | None
    path_ordinals: tuple[int, ...]
    path_names: tuple[str, ...]
    level_type: str
    attributes: list[_AttributeRefV2]
    key_refs: list[_AttributeRefV2]
    table_candidates: list[dict[str, object]] = field(default_factory=list)
    association_status: str = "unresolved"
    association_evidence: list[dict[str, object]] = field(default_factory=list)
    identity_issue: str | None = None


@dataclass
class _TableV2:
    name: str
    guid: str | None
    path: str
    key_refs: list[_AttributeRefV2]
    indexes: list[dict[str, object]]
    errors: list[str] = field(default_factory=list)


@dataclass
class _WritabilityModel:
    root: Path
    attributes: list[_AttributeObject]
    tables: list[_TableV2]
    levels: list[_LevelV2]
    transactions: list[dict[str, object]]
    subtype_map: dict[str, str]
    errors: list[str]


@dataclass
class _WritabilityRowV2:
    transaction_name: str
    level_name: str
    attribute_name: str
    key: bool
    is_redundant: bool
    classification: str
    writable: bool | None
    can_assign_in_new: bool | None
    reason: str
    evidence: str
    transaction_guid: str | None
    part_type: str
    level_guid: str | None
    path_ordinals: list[int]
    attribute_guid: str | None
    identity: dict[str, object]
    basis: str
    coverage: str
    reason_codes: list[str]
    provenance: dict[str, object]

    def evidence_envelope(self) -> dict[str, object]:
        return {
            "kind": "gx-writability-evidence",
            "schemaVersion": 1,
            "ruleVersion": WRITABILITY_RULE_VERSION,
            "identity": self.identity,
            "basis": self.basis,
            "coverage": self.coverage,
            "reasonCodes": self.reason_codes,
            "provenance": self.provenance,
            "evidenceSummary": self.evidence,
        }


def _xml_local_name(tag: str) -> str:
    return tag.rsplit("}", 1)[-1]


def _xml_attr(element: ElementTree.Element, name: str) -> str:
    for key, value in element.attrib.items():
        if key.casefold() == name.casefold():
            return value.strip()
    return ""


def _xml_children(element: ElementTree.Element, name: str) -> list[ElementTree.Element]:
    return [child for child in list(element) if _xml_local_name(child.tag).casefold() == name.casefold()]


def _xml_descendants(element: ElementTree.Element, name: str) -> list[ElementTree.Element]:
    return [node for node in element.iter() if node is not element and _xml_local_name(node.tag).casefold() == name.casefold()]


def _xml_text(element: ElementTree.Element) -> str:
    return "".join(element.itertext()).strip()


def _normalize_guid(value: str) -> str | None:
    if not value:
        return None
    try:
        return str(uuid.UUID(value.strip().strip("{}"))).lower()
    except (ValueError, AttributeError):
        return None


class _RejectXmlDoctype(xml.sax.handler.ContentHandler, xml.sax.handler.ErrorHandler):
    def startDTD(self, name: str, public_id: str | None, system_id: str | None) -> None:
        raise ValueError("DOCTYPE declarations are not supported")

    def endDTD(self) -> None:
        return None

    def comment(self, text: str) -> None:
        return None

    def startCDATA(self) -> None:
        return None

    def endCDATA(self) -> None:
        return None

    def startEntity(self, name: str) -> None:
        return None

    def endEntity(self, name: str) -> None:
        return None

    def fatalError(self, exception: xml.sax.SAXParseException) -> None:
        raise exception

    def error(self, exception: xml.sax.SAXParseException) -> None:
        raise exception

    def warning(self, exception: xml.sax.SAXParseException) -> None:
        raise exception


def _parse_xml_without_doctype(raw: bytes) -> ElementTree.Element:
    handler = _RejectXmlDoctype()
    parser = xml.sax.make_parser()
    parser.setFeature(xml.sax.handler.feature_external_ges, False)
    parser.setFeature(xml.sax.handler.feature_external_pes, False)
    parser.setContentHandler(handler)
    parser.setErrorHandler(handler)
    parser.setProperty(xml.sax.handler.property_lexical_handler, handler)
    source = xml.sax.InputSource()
    source.setByteStream(io.BytesIO(raw))
    parser.parse(source)
    return ElementTree.fromstring(raw)


def _read_xml_root(path: Path, expected_root_name: str = "Object") -> ElementTree.Element:
    try:
        raw = path.read_bytes()
    except OSError as exc:
        raise ValueError(f"XML file cannot be read: {path}: {exc}") from exc
    try:
        root = _parse_xml_without_doctype(raw)
    except (ElementTree.ParseError, xml.sax.SAXException, ValueError) as exc:
        raise ValueError(f"XML is malformed or has invalid encoding: {path}: {exc}") from exc
    allowed_roots = {"object", expected_root_name.casefold()}
    if _xml_local_name(root.tag).casefold() not in allowed_roots:
        raise ValueError(f"XML root is not Object or {expected_root_name}: {path}")
    return root


def _object_name(root: ElementTree.Element, fallback: str) -> str:
    name = _xml_attr(root, "name")
    if name:
        return name
    for prop in _xml_descendants(root, "Property"):
        prop_children = _xml_children(prop, "Name")
        value_children = _xml_children(prop, "Value")
        if prop_children and _xml_text(prop_children[0]).casefold() == "name" and value_children:
            value = _xml_text(value_children[0])
            if value:
                return value
    return fallback


def _catalog_types(catalog_path: Path | None = None) -> dict[str, dict[str, object]]:
    path = catalog_path or Path(__file__).resolve().parent / "gx-object-type-catalog.json"
    try:
        data = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError, UnicodeDecodeError) as exc:
        raise ValueError(f"Object type catalog cannot be read: {path}: {exc}") from exc
    types = data.get("types")
    if not isinstance(types, dict):
        raise ValueError("Object type catalog has no types map")
    return types


def _type_guid(types: dict[str, dict[str, object]], type_name: str) -> str | None:
    item = types.get(type_name)
    value = item.get("objectTypeGuid") if isinstance(item, dict) else None
    return _normalize_guid(value) if isinstance(value, str) else None


def _iter_object_files(root: Path, folder_name: str, errors: list[str]) -> list[Path]:
    folder = root / folder_name
    if not folder.is_dir():
        errors.append(f"inventory-folder-missing:{folder_name}")
        return []
    files: list[Path] = []
    for path in folder.rglob("*.xml"):
        try:
            resolved = path.resolve(strict=True)
            resolved.relative_to(root.resolve(strict=True))
        except (OSError, ValueError):
            errors.append(f"inventory-path-escape:{folder_name}/{path.name}")
            continue
        if path.is_file():
            files.append(path)
    return sorted(files, key=lambda item: item.relative_to(root).as_posix())


def _read_object_inventory(
    root: Path,
    folder: str,
    expected_type_guid: str | None,
    errors: list[str],
) -> list[tuple[ElementTree.Element, Path, dict[str, object]]]:
    result: list[tuple[ElementTree.Element, Path, dict[str, object]]] = []
    for path in _iter_object_files(root, folder, errors):
        try:
            xml_root = _read_xml_root(path, folder)
        except ValueError as exc:
            errors.append(f"inventory-xml-invalid:{folder}/{path.name}:{exc}")
            continue
        type_value = _normalize_guid(_xml_attr(xml_root, "type"))
        if expected_type_guid and type_value != expected_type_guid:
            continue
        object_guid_raw = _xml_attr(xml_root, "guid")
        object_guid = _normalize_guid(object_guid_raw)
        if object_guid_raw and object_guid is None:
            errors.append(f"object-guid-invalid:{folder}/{path.name}")
        name = _object_name(xml_root, path.stem)
        ref: dict[str, object] = {
            "type": folder,
            "guid": object_guid,
            "name": name,
            "path": path.relative_to(root).as_posix(),
            "rootKind": "corpus",
        }
        result.append((xml_root, path, ref))
    return result


def _index_attributes(
    records: list[tuple[ElementTree.Element, Path, dict[str, object]]],
    errors: list[str],
) -> tuple[list[_AttributeObject], dict[str, list[_AttributeObject]], dict[str, list[_AttributeObject]]]:
    attributes: list[_AttributeObject] = []
    by_guid: dict[str, list[_AttributeObject]] = {}
    by_name: dict[str, list[_AttributeObject]] = {}
    for root, path, ref in records:
        guid = ref.get("guid")
        formula = False
        for prop in _xml_descendants(root, "Property"):
            names = _xml_children(prop, "Name")
            if names and _xml_text(names[0]).casefold() == "formula":
                formula = True
                break
        item = _AttributeObject(str(ref["name"]), guid if isinstance(guid, str) else None, str(ref["path"]), formula)
        attributes.append(item)
        by_name.setdefault(item.name.casefold(), []).append(item)
        if item.guid:
            by_guid.setdefault(item.guid, []).append(item)
    for guid, values in by_guid.items():
        if len(values) > 1:
            errors.append(f"attribute-guid-duplicate:{guid}")
    return attributes, by_guid, by_name


def _resolve_attribute_ref(
    raw_guid: str,
    name: str,
    by_guid: dict[str, list[_AttributeObject]],
    by_name: dict[str, list[_AttributeObject]],
) -> _AttributeRefV2:
    normalized_guid = _normalize_guid(raw_guid)
    if raw_guid and normalized_guid is None:
        return _AttributeRefV2(name, None, False, False, "invalid-guid", "attribute-guid-invalid")
    named = by_name.get(name.casefold(), []) if name else []
    if normalized_guid:
        matching = by_guid.get(normalized_guid, [])
        if len(matching) == 1:
            if name and matching[0].name.casefold() != name.casefold():
                return _AttributeRefV2(name, normalized_guid, False, False, "guid-name-conflict", "attribute-guid-name-conflict")
            return _AttributeRefV2(matching[0].name, normalized_guid, False, False, "guid", None)
        if len(matching) > 1:
            return _AttributeRefV2(name, normalized_guid, False, False, "duplicate-guid", "attribute-guid-duplicate")
        if named:
            return _AttributeRefV2(name, normalized_guid, False, False, "unmatched-guid", "attribute-guid-not-in-inventory")
        return _AttributeRefV2(name, normalized_guid, False, False, "guid-not-found", "attribute-not-found")
    if len(named) == 1 and named[0].guid:
        return _AttributeRefV2(named[0].name, named[0].guid, False, False, "reduced-name", "attribute-identity-reduced")
    if len(named) > 1:
        return _AttributeRefV2(name, None, False, False, "ambiguous-name", "attribute-name-ambiguous")
    return _AttributeRefV2(name, None, False, False, "name-not-found", "attribute-not-found")


def _direct_level_children(parent: ElementTree.Element) -> list[ElementTree.Element]:
    found: list[ElementTree.Element] = []
    for child in list(parent):
        if _xml_local_name(child.tag).casefold() == "level":
            found.append(child)
        else:
            found.extend(_direct_level_children(child))
    return found


def _own_level_attributes(level_node: ElementTree.Element) -> list[ElementTree.Element]:
    found: list[ElementTree.Element] = []
    def visit(node: ElementTree.Element) -> None:
        for child in list(node):
            local = _xml_local_name(child.tag).casefold()
            if local == "level":
                continue
            if local == "attribute":
                found.append(child)
            else:
                visit(child)

    visit(level_node)
    return found


def _parse_level_tree(
    transaction: dict[str, object],
    part_type: str,
    roots: list[ElementTree.Element],
    by_guid: dict[str, list[_AttributeObject]],
    by_name: dict[str, list[_AttributeObject]],
) -> list[_LevelV2]:
    result: list[_LevelV2] = []

    def visit(node: ElementTree.Element, ordinal_path: tuple[int, ...], name_path: tuple[str, ...]) -> None:
        name = _xml_attr(node, "name") or f"Level{ordinal_path[-1]}"
        guid_raw = _xml_attr(node, "guid")
        guid = _normalize_guid(guid_raw)
        level_type = _xml_attr(node, "type")
        attrs: list[_AttributeRefV2] = []
        for attr_node in _own_level_attributes(node):
            attr_name = _xml_text(attr_node)
            if not attr_name:
                attr_name = _xml_attr(attr_node, "name")
            ref = _resolve_attribute_ref(_xml_attr(attr_node, "guid"), attr_name, by_guid, by_name)
            ref.key = _xml_attr(attr_node, "key").casefold() == "true"
            ref.is_redundant = _xml_attr(attr_node, "isRedundant").casefold() == "true"
            attrs.append(ref)
        item = _LevelV2(transaction, part_type, name, guid, ordinal_path, name_path + (name,), level_type, attrs,
                        [ref for ref in attrs if ref.key])
        if guid_raw and guid is None:
            item.identity_issue = "level-guid-invalid"
        result.append(item)
        children = _direct_level_children(node)
        for child_ordinal, child in enumerate(children):
            visit(child, ordinal_path + (child_ordinal,), item.path_names)

    for ordinal, root in enumerate(roots):
        visit(root, (ordinal,), ())
    return result


def _parse_table(
    root: ElementTree.Element,
    path: Path,
    object_ref: dict[str, object],
    corpus_root: Path,
    by_guid: dict[str, list[_AttributeObject]],
    by_name: dict[str, list[_AttributeObject]],
) -> _TableV2:
    errors: list[str] = []
    key_nodes = _xml_descendants(root, "Key")
    key_refs: list[_AttributeRefV2] = []
    if len(key_nodes) != 1:
        errors.append("table-key-missing-or-duplicated")
    elif key_nodes:
        key_node = key_nodes[0]
        for item in _xml_descendants(key_node, "Item"):
            raw_name = _xml_text(item) or _xml_attr(item, "name")
            ref = _resolve_attribute_ref(_xml_attr(item, "guid"), raw_name, by_guid, by_name)
            ref.key = True
            key_refs.append(ref)
        if not key_refs:
            errors.append("table-key-empty")
    indexes: list[dict[str, object]] = []
    for ordinal, index_node in enumerate(_xml_descendants(root, "Index")):
        members: list[_AttributeRefV2] = []
        for member in _xml_descendants(index_node, "Member"):
            raw_name = _xml_text(member) or _xml_attr(member, "name")
            ref = _resolve_attribute_ref(_xml_attr(member, "guid"), raw_name, by_guid, by_name)
            members.append(ref)
        index_type = _xml_attr(index_node, "type")
        index_guid_raw = _xml_attr(index_node, "guid")
        index_guid = _normalize_guid(index_guid_raw)
        indexes.append({
            "ordinal": ordinal,
            "guid": index_guid,
            "identity": index_guid or f"{object_ref['path']}#Index[{ordinal}]",
            "type": index_type,
            "role": _xml_attr(index_node, "role"),
            "members": members,
        })
        if index_type.casefold() not in {"duplicate", "unique"}:
            errors.append(f"index-type-unsupported:{index_type or 'missing'}")
        if not members:
            errors.append(f"index-empty:{ordinal}")
    return _TableV2(str(object_ref["name"]), object_ref.get("guid") if isinstance(object_ref.get("guid"), str) else None,
                    str(object_ref["path"]), key_refs, indexes, errors)


def _load_writability_model(corpus_folder: Path, catalog_path: Path | None = None) -> _WritabilityModel:
    root = corpus_folder.resolve(strict=True)
    if not root.is_dir():
        raise ValueError(f"CorpusFolder not found: {root}")
    types = _catalog_types(catalog_path)
    errors: list[str] = []
    attribute_records = _read_object_inventory(root, "Attribute", _type_guid(types, "Attribute"), errors)
    attributes, by_guid, by_name = _index_attributes(attribute_records, errors)
    table_records = _read_object_inventory(root, "Table", _type_guid(types, "Table"), errors)
    tables = [_parse_table(xml_root, path, ref, root, by_guid, by_name) for xml_root, path, ref in table_records]
    tx_records = _read_object_inventory(root, "Transaction", _type_guid(types, "Transaction"), errors)
    transactions: list[dict[str, object]] = []
    levels: list[_LevelV2] = []
    for xml_root, path, ref in tx_records:
        transaction = {**ref, "_absolutePath": str(path)}
        transactions.append(transaction)
        for part in _xml_descendants(xml_root, "Part"):
            roots = _direct_level_children(part)
            if roots:
                levels.extend(_parse_level_tree(transaction, _xml_attr(part, "type"), roots, by_guid, by_name))
    subtype_map: dict[str, str] = {}
    subtype_records = _read_object_inventory(root, "SubTypeGroup", _type_guid(types, "SubTypeGroup"), errors)
    for xml_root, _, _ in subtype_records:
        for subtype in _xml_descendants(xml_root, "Subtype"):
            names = _xml_children(subtype, "Name")
            supertypes = _xml_children(subtype, "Supertype")
            if not names or not supertypes:
                errors.append("subtype-entry-incomplete")
                continue
            subtype_name = _xml_text(names[0])
            supertype_name = _xml_text(supertypes[0])
            key = subtype_name.casefold()
            old = subtype_map.get(key)
            if old is not None and old.casefold() != supertype_name.casefold():
                errors.append(f"subtype-definition-conflict:{subtype_name}")
            else:
                subtype_map[key] = supertype_name
    table_by_name: dict[str, list[_TableV2]] = {}
    for table in tables:
        table_by_name.setdefault(table.name.casefold(), []).append(table)
    for level in levels:
        key_refs = [ref for ancestor in levels if ancestor.transaction.get("path") == level.transaction.get("path")
                    and ancestor.part_type == level.part_type
                    and level.path_ordinals[:len(ancestor.path_ordinals)] == ancestor.path_ordinals
                    and len(ancestor.path_ordinals) <= len(level.path_ordinals)
                    for ref in ancestor.key_refs]
        key_guids = [ref.guid for ref in key_refs]
        valid_key_ids = all(key_guids) and len(set(key_guids)) == len(key_guids)
        candidates = [table for table in tables if valid_key_ids and
                      [ref.guid for ref in table.key_refs] == key_guids and table.guid]
        typed = table_by_name.get(level.level_type.casefold(), []) if level.level_type else []
        typed_exact = [table for table in typed if table in candidates]
        if len(typed_exact) == 1:
            level.table_candidates = typed_exact
            level.association_status = "resolved-level-type-and-table-key"
        elif len(candidates) == 1:
            level.table_candidates = candidates
            level.association_status = "table-binding-proposed"
        elif len(candidates) > 1:
            level.table_candidates = candidates
            level.association_status = "table-binding-ambiguous"
        elif typed:
            level.association_status = "level-type-key-conflict"
            level.association_evidence = [{"guid": table.guid, "name": table.name, "path": table.path,
                                           "keyGuids": [ref.guid for ref in table.key_refs],
                                           "keyMismatch": True} for table in typed]
        else:
            level.association_status = "table-key-unresolved" if valid_key_ids else "key-identity-incomplete"
        level.association_evidence = [{"guid": table.guid, "name": table.name, "path": table.path,
                                      "keyGuids": [ref.guid for ref in table.key_refs]}
                                     for table in level.table_candidates]
        if level.identity_issue:
            errors.append(f"{level.identity_issue}:{level.transaction['path']}:{level.path_ordinals}")
        local_ids = [ref.guid for ref in level.attributes if ref.guid]
        if len(local_ids) != len(set(local_ids)):
            errors.append(f"level-attribute-identity-duplicate:{level.transaction['path']}:{level.path_ordinals}")
    return _WritabilityModel(root, attributes, tables, levels, transactions, subtype_map, errors)


def _table_relation_index(model: _WritabilityModel) -> tuple[dict[str, list[dict[str, object]]], dict[str, list[_LevelV2]]]:
    table_views: dict[str, list[_LevelV2]] = {}
    for level in model.levels:
        for table_ref in level.table_candidates:
            if table_ref.guid:
                table_views.setdefault(table_ref.guid, []).append(level)
    tables_by_key: dict[tuple[str, ...], list[_TableV2]] = {}
    for table in model.tables:
        key = tuple(ref.guid or "" for ref in table.key_refs)
        if table.guid and key and all(key):
            tables_by_key.setdefault(key, []).append(table)
    relations: dict[str, list[dict[str, object]]] = {}
    for table in model.tables:
        if not table.guid:
            continue
        own_key = tuple(ref.guid or "" for ref in table.key_refs)
        edges: list[dict[str, object]] = []
        for index in table.indexes:
            members = index["members"]
            member_guids = tuple(ref.guid or "" for ref in members)
            if not member_guids or not all(member_guids):
                continue
            if len(member_guids) == len(own_key) and set(member_guids) == set(own_key):
                continue
            targets = [target for target in tables_by_key.get(member_guids, []) if target.guid != table.guid]
            if targets:
                edges.append({"index": index, "memberGuids": list(member_guids), "targets": targets,
                              "ambiguous": len(targets) != 1})
        relations[table.guid] = edges
    return relations, table_views


def _row_result(
    level: _LevelV2,
    ref: _AttributeRefV2,
    attribute: _AttributeObject | None,
    classification: str,
    writable: bool | None,
    basis: str,
    coverage: str,
    reason_codes: list[str],
    provenance: dict[str, object],
    evidence: str,
) -> _WritabilityRowV2:
    transaction = level.transaction
    identity = {
        "transaction": {key: transaction.get(key) for key in ("type", "guid", "name", "path", "rootKind")},
        "partType": level.part_type,
        "level": {"guid": level.guid, "pathOrdinals": list(level.path_ordinals)},
        "attribute": {"type": "Attribute", "guid": ref.guid, "name": ref.name,
                       "path": attribute.path if attribute else None, "rootKind": "corpus"},
    }
    ordered_reasons = sorted(set(reason_codes or [classification]))
    direct_primary = {
        "formula": "formula",
        "extended-parent-fk": "extended-parent-fk",
        "extended-subtype-key": "subtype-key",
        "extended-subtype-descriptive": "subtype-descriptive",
        "extended-fk-key": "extended-fk-key",
        "key-attribute": "key-attribute",
        "own-physical": "own-physical",
        "own-physical-indexed": "own-physical-indexed",
        "extended-fk-descriptive": "inferred-fk-descriptive",
    }
    primary_reason = direct_primary.get(classification)
    if primary_reason is None:
        technical_prefixes = ("inventory-", "xml-", "object-guid-", "level-guid-", "table-", "attribute-",
                              "relation-", "subtype-", "key-", "source-", "parse-", "new-")
        primary_reason = next((code for code in ordered_reasons if code.startswith(technical_prefixes)),
                              ordered_reasons[0])
    return _WritabilityRowV2(
        transaction_name=str(transaction["name"]),
        level_name=level.name,
        attribute_name=ref.name,
        key=ref.key,
        is_redundant=ref.is_redundant,
        classification=classification,
        writable=writable,
        can_assign_in_new=writable,
        reason=primary_reason,
        evidence=evidence,
        transaction_guid=transaction.get("guid") if isinstance(transaction.get("guid"), str) else None,
        part_type=level.part_type,
        level_guid=level.guid,
        path_ordinals=list(level.path_ordinals),
        attribute_guid=ref.guid,
        identity=identity,
        basis=basis,
        coverage=coverage,
        reason_codes=ordered_reasons,
        provenance=provenance,
    )


def _subtype_result(model: _WritabilityModel, ref: _AttributeRefV2) -> tuple[str, str, list[str]] | None:
    supertype = model.subtype_map.get(ref.name.casefold())
    if supertype is None:
        return None
    visited = {ref.name.casefold()}
    chain = [ref.name]
    current = supertype
    key_ids = {key_ref.guid for table in model.tables for key_ref in table.key_refs if key_ref.guid}
    for _ in range(64):
        folded = current.casefold()
        if folded in visited:
            return ("unclassified-evidence-incomplete", "subtype-cycle", chain + [current])
        visited.add(folded)
        chain.append(current)
        matches = [item for item in model.attributes if item.name.casefold() == folded]
        if len(matches) != 1:
            return ("unclassified-evidence-incomplete", "subtype-supertype-unresolved", chain)
        parent = matches[0]
        if parent.guid and parent.guid in key_ids:
            return ("extended-subtype-key", "subtype-key", chain)
        next_supertype = model.subtype_map.get(folded)
        if next_supertype is None:
            return ("extended-subtype-descriptive", "subtype-descriptive", chain)
        current = next_supertype
    return ("unclassified-evidence-incomplete", "subtype-depth-exhausted", chain)


def _search_relation_roles(
    model: _WritabilityModel,
    attribute_guid: str,
    starting_tables: list[_TableV2],
    relations: dict[str, list[dict[str, object]]],
    table_views: dict[str, list[_LevelV2]],
    max_depth: int = 10,
    max_edges: int = 4096,
) -> dict[str, object]:
    positives: set[str] = set()
    unknown: set[str] = set()
    indexed_member = False
    visited: set[str] = set()
    scheduled: set[str] = {table.guid for table in starting_tables if table.guid}
    inspected_edges = 0
    queue: list[tuple[_TableV2, int]] = [(table, 0) for table in starting_tables]
    while queue:
        table, depth = queue.pop(0)
        if not table.guid or table.guid in visited:
            continue
        visited.add(table.guid)
        if table.errors:
            unknown.update(table.errors)
        for index in table.indexes:
            member_guids = [ref.guid for ref in index["members"]]
            if attribute_guid in member_guids:
                indexed_member = True
        edges = relations.get(table.guid, [])
        inspected_edges += len(edges)
        if inspected_edges > max_edges:
            unknown.add("relation-search-budget-exhausted")
            break
        if depth >= max_depth:
            if edges:
                unknown.add("relation-depth-exhausted")
            continue
        for edge in edges:
            members = edge["memberGuids"]
            if attribute_guid in members:
                if edge["ambiguous"]:
                    unknown.add("relation-target-ambiguous")
                elif edge.get("confirmedByDecision") is True:
                    positives.add("resolved-fk-key")
                else:
                    positives.add("inferred-fk-key")
            targets = edge["targets"]
            if len(targets) != 1:
                unknown.add("relation-target-ambiguous")
            if not targets:
                continue
            # Ambiguity limits the conclusion but does not erase positive
            # descriptive evidence found in any compatible target view.
            for target in targets:
                views = table_views.get(target.guid or "", [])
                if not views:
                    unknown.add("relation-target-view-missing")
                for view in views:
                    matching = [ref for ref in view.attributes if ref.guid == attribute_guid]
                    if any(not ref.key and not ref.is_redundant for ref in matching):
                        positives.add("inferred-fk-descriptive")
                    if any(ref.issue for ref in view.attributes):
                        unknown.update(ref.issue for ref in view.attributes if ref.issue)
                if target.guid and target.guid not in scheduled:
                    scheduled.add(target.guid)
                    queue.append((target, depth + 1))
    if model.errors:
        unknown.add("inventory-incomplete")
    return {"positives": sorted(positives), "unknown": sorted(unknown), "indexedMember": indexed_member,
            "visitedTableGuids": sorted(visited), "inspectedEdges": inspected_edges,
            "maxDepth": max_depth, "maxEdges": max_edges}


def _classify_level_attribute(
    model: _WritabilityModel,
    level: _LevelV2,
    ref: _AttributeRefV2,
    attributes_by_guid: dict[str, list[_AttributeObject]],
    relations: dict[str, list[dict[str, object]]],
    table_views: dict[str, list[_LevelV2]],
) -> _WritabilityRowV2:
    matches = attributes_by_guid.get(ref.guid or "", [])
    attribute = matches[0] if len(matches) == 1 else None
    direct_issues = [ref.issue] if ref.issue else []
    if level.identity_issue:
        direct_issues.append(level.identity_issue)
    if not level.transaction.get("guid"):
        direct_issues.append("transaction-guid-missing")
    if len(matches) > 1:
        direct_issues.append("attribute-guid-duplicate")
    if ref.key and attribute and (attribute.formula or ref.is_redundant):
        return _row_result(level, ref, attribute, "unclassified-identity-conflict", None, "conflicting-direct-identity",
                           "invalid", direct_issues + ["key-direct-property-conflict"], {},
                           "Key contradiz fórmula ou redundância direta.")
    if direct_issues:
        return _row_result(level, ref, attribute, "unclassified-identity-conflict" if any("conflict" in item or "duplicate" in item or "invalid" in item for item in direct_issues) else "unclassified-evidence-incomplete",
                           None, "attribute-identity", "invalid" if any("conflict" in item or "duplicate" in item or "invalid" in item for item in direct_issues) else "partial",
                           direct_issues, {}, "Identidade do Attribute não pôde ser validada integralmente.")
    if attribute and attribute.formula:
        return _row_result(level, ref, attribute, "formula", False, "attribute-formula", "complete-in-model", ["formula"],
                           {"attributePath": attribute.path}, "Attribute possui propriedade Formula.")
    if ref.is_redundant:
        return _row_result(level, ref, attribute, "extended-parent-fk", False, "level-redundancy", "complete-in-model",
                           ["extended-parent-fk"], {}, "Level marca o Attribute como redundante.")
    subtype = _subtype_result(model, ref)
    if subtype is not None:
        classification, reason, chain = subtype
        writable = True if classification == "extended-subtype-key" else False if classification == "extended-subtype-descriptive" else None
        coverage = "complete-in-model" if writable is not None else "partial"
        return _row_result(level, ref, attribute, classification, writable, "subtype-chain", coverage, [reason],
                           {"subtypeChain": chain}, "Classificação derivada da cadeia SubTypeGroup.")
    if ref.key:
        tables = level.table_candidates
        key_in_all = bool(tables) and all(ref.guid in [key.guid for key in table.key_refs] for table in tables)
        if not tables or not key_in_all:
            return _row_result(level, ref, attribute, "unclassified-identity-conflict", None, "level-key-versus-table-key",
                               "invalid", ["key-table-key-conflict"], {"tableCandidates": level.association_evidence},
                               "Key do Level não coincide com Table.Key validada.")
        return _row_result(level, ref, attribute, "key-attribute", True, "table-key", "complete-in-model",
                           ["key-attribute"], {"tableCandidates": level.association_evidence},
                           "Attribute pertence à chave estrutural do Level e da Table candidata.")
    if not attribute or not ref.guid:
        return _row_result(level, ref, attribute, "unclassified-evidence-incomplete", None, "attribute-identity",
                           "partial", ["attribute-identity-incomplete"], {},
                           "Attribute não possui identidade completa para autorizar uma atribuição.")
    if level.association_status in {"table-key-unresolved", "key-identity-incomplete", "level-type-key-conflict"}:
        code = "table-binding-unresolved" if level.association_status != "level-type-key-conflict" else "level-type-key-conflict"
        classification = "unclassified-relation-pending" if level.table_candidates else "unclassified-evidence-incomplete"
        return _row_result(level, ref, attribute, classification, None, "table-association", "partial", [code],
                           {"levelType": level.level_type, "associationStatus": level.association_status,
                            "tableCandidates": level.association_evidence},
                           "Associação Level/Table não foi resolvida por Type e Table.Key.")
    candidate_guids = {item.guid for item in level.table_candidates if item.guid}
    tables = [table for table in model.tables if table.guid in candidate_guids]
    if not tables:
        return _row_result(level, ref, attribute, "unclassified-evidence-incomplete", None, "table-association", "partial",
                           ["table-binding-unresolved"], {"tableCandidates": level.association_evidence},
                           "Nenhuma Table candidata íntegra foi localizada.")
    role_summary = _search_relation_roles(model, ref.guid, tables, relations, table_views)
    positives = set(role_summary["positives"])
    unknown = set(role_summary["unknown"])
    binding_pending = level.association_status != "resolved-level-type-and-table-key"
    if ("inferred-fk-descriptive" in positives
            and ({"inferred-fk-key", "resolved-fk-key"} & positives)):
        return _row_result(level, ref, attribute, "unclassified-role-conflict", None, "inferred-relation",
                           "partial" if unknown else "complete-in-model", ["heuristic-role-conflict", *unknown],
                           {"relationAnalysis": role_summary, "tableCandidates": level.association_evidence},
                           "A análise encontrou papéis inferidos incompatíveis para o mesmo Attribute.")
    if "inferred-fk-descriptive" in positives:
        coverage = "partial" if unknown else "complete-in-model"
        return _row_result(level, ref, attribute, "extended-fk-descriptive", False, "inferred-relation", coverage,
                           ["inferred-fk-descriptive", *unknown],
                           {"relationAnalysis": role_summary, "tableCandidates": level.association_evidence},
                           "Attribute aparece como descritivo em entidade alcançada por índice compatível.")
    if "resolved-fk-key" in positives:
        if "inferred-fk-key" in positives:
            return _row_result(level, ref, attribute, "unclassified-relation-pending", None, "inferred-relation",
                               "partial", ["inferred-fk-key", *unknown],
                               {"relationAnalysis": role_summary, "tableCandidates": level.association_evidence},
                               "Uma relação FK foi confirmada, mas outra relação inferida ainda afeta o resultado.")
        if binding_pending:
            return _row_result(level, ref, attribute, "unclassified-relation-pending", None, "table-association",
                               "partial", ["table-binding-proposed", *unknown],
                               {"relationAnalysis": role_summary, "tableCandidates": level.association_evidence},
                               "A relação FK foi confirmada, mas a associação Level/Table ainda está pendente.")
        if unknown:
            return _row_result(level, ref, attribute, "unclassified-evidence-incomplete", None, "relation-search",
                               "partial", sorted(unknown),
                               {"relationAnalysis": role_summary, "tableCandidates": level.association_evidence},
                               "A relação FK foi confirmada, mas a busca adicional continua incompleta.")
        return _row_result(level, ref, attribute, "extended-fk-key", True, "inferred-relation",
                           "complete-in-model", ["extended-fk-key"],
                           {"relationAnalysis": role_summary, "tableCandidates": level.association_evidence},
                           "Membro físico de uma relação FK validada por decisão aplicada.")
    if positives or binding_pending:
        code = "inferred-fk-key" if "inferred-fk-key" in positives else "table-binding-proposed"
        return _row_result(level, ref, attribute, "unclassified-relation-pending", None, "inferred-relation",
                           "partial", [code, *unknown],
                           {"relationAnalysis": role_summary, "tableCandidates": level.association_evidence},
                           "A conclusão depende de associação ou relação inferida ainda não resolvida.")
    if unknown:
        return _row_result(level, ref, attribute, "unclassified-evidence-incomplete", None, "relation-search",
                           "partial", sorted(unknown),
                           {"relationAnalysis": role_summary, "tableCandidates": level.association_evidence},
                           "A busca de relações não foi exaustiva ou encontrou evidência incompleta.")
    classification = "own-physical-indexed" if role_summary["indexedMember"] else "own-physical"
    return _row_result(level, ref, attribute, classification, True, "own-table-complete-search", "complete-in-model",
                       [classification], {"relationAnalysis": role_summary, "tableCandidates": level.association_evidence},
                       "Busca completa não encontrou relação FK impeditiva para a Table resolvida.")


def _classify_model_level(level: _LevelV2, model: _WritabilityModel,
                          attributes_by_guid: dict[str, list[_AttributeObject]],
                          relations: dict[str, list[dict[str, object]]],
                          table_views: dict[str, list[_LevelV2]]) -> list[_WritabilityRowV2]:
    return [_classify_level_attribute(model, level, ref, attributes_by_guid, relations, table_views)
            for ref in level.attributes]


def classify_transaction_attributes(
    transaction_path: Path,
    corpus_folder: Path,
    transaction_type_guid: str,
    *,
    subtype_index: dict[str, str] | None = None,
    pk_attr_set: set[str] | None = None,
    transaction_level_index: dict[str, _TransactionLevelEntry] | None = None,
) -> list[_WritabilityRowV2]:
    del subtype_index, pk_attr_set, transaction_level_index
    expected = _normalize_guid(transaction_type_guid)
    catalog_transaction_guid = _type_guid(_catalog_types(), "Transaction")
    if not expected or expected != catalog_transaction_guid:
        raise ValueError("Transaction objectTypeGuid supplied to the classifier does not match the effective catalog")
    model = _load_writability_model(corpus_folder)
    resolved_path = transaction_path.resolve(strict=True)
    selected = [item for item in model.transactions if Path(str(item["_absolutePath"])).resolve() == resolved_path]
    if len(selected) != 1:
        raise ValueError(f"Transaction identity is not unique in corpus inventory: {resolved_path}")
    transaction = selected[0]
    levels = [level for level in model.levels if level.transaction.get("guid") == transaction.get("guid")
              and level.transaction.get("path") == transaction.get("path")]
    relations, table_views = _table_relation_index(model)
    attr_index: dict[str, list[_AttributeObject]] = {}
    for attr in model.attributes:
        if attr.guid:
            attr_index.setdefault(attr.guid, []).append(attr)
    return [row for level in levels for row in _classify_model_level(level, model, attr_index, relations, table_views)]


def build_corpus_writability(corpus_folder: Path, transaction_type_guid: str) -> list[_WritabilityRowV2]:
    del transaction_type_guid
    model = _load_writability_model(corpus_folder)
    relations, table_views = _table_relation_index(model)
    attr_index: dict[str, list[_AttributeObject]] = {}
    for attr in model.attributes:
        if attr.guid:
            attr_index.setdefault(attr.guid, []).append(attr)
    return [row for level in model.levels for row in _classify_model_level(level, model, attr_index, relations, table_views)]


def attribute_writability_to_gate_row(row: _WritabilityRowV2) -> dict[str, object]:
    return {
        "levelName": row.level_name,
        "attributeName": row.attribute_name,
        "key": row.key,
        "isRedundant": row.is_redundant,
        "classification": row.classification,
        "writable": row.writable,
        "canAssignInNew": row.can_assign_in_new,
        "reason": row.reason,
        "reasonCodes": row.reason_codes,
        "identity": row.identity,
        "basis": row.basis,
        "coverage": row.coverage,
        "provenance": row.provenance,
        "evidence": row.evidence,
        "evidenceEnvelope": row.evidence_envelope(),
    }


def attribute_writability_to_map_entry(row: _WritabilityRowV2) -> dict[str, object]:
    return attribute_writability_to_gate_row(row)


def _coverage_from_rows(rows: list[_WritabilityRowV2]) -> str:
    if any(row.coverage == "invalid" for row in rows):
        return "invalid"
    if any(row.coverage != "complete-in-model" for row in rows):
        return "partial"
    return "complete-in-model"


def classify_transaction_gate_payload(transaction_path: Path, corpus_folder: Path,
                                      transaction_type_guid: str) -> dict[str, object]:
    transaction_path = transaction_path.resolve(strict=True)
    corpus_folder = corpus_folder.resolve(strict=True)
    rows = classify_transaction_attributes(transaction_path, corpus_folder, transaction_type_guid)
    meta = _read_xml_root(transaction_path)
    tx_name = _object_name(meta, transaction_path.stem)
    return {
        "status": "pass",
        "transactionName": tx_name,
        "transactionGuid": _normalize_guid(_xml_attr(meta, "guid")),
        "transactionPath": str(transaction_path),
        "coverage": _coverage_from_rows(rows),
        "writabilityRuleVersion": WRITABILITY_RULE_VERSION,
        "operationalStatus": "not-requested",
        "levelAttributes": [attribute_writability_to_gate_row(row) for row in rows],
    }


def classify_transactions_batch_payload(transaction_paths: list[Path], corpus_folder: Path,
                                         transaction_type_guid: str) -> dict[str, object]:
    del transaction_type_guid
    model = _load_writability_model(corpus_folder)
    relations, table_views = _table_relation_index(model)
    attr_index: dict[str, list[_AttributeObject]] = {}
    for attr in model.attributes:
        if attr.guid:
            attr_index.setdefault(attr.guid, []).append(attr)
    items: list[dict[str, object]] = []
    for raw_path in transaction_paths:
        path = Path(raw_path).resolve(strict=True)
        matches = [item for item in model.transactions if Path(str(item["_absolutePath"])).resolve() == path]
        if len(matches) != 1:
            raise ValueError(f"Transaction identity is not unique in corpus inventory: {path}")
        tx = matches[0]
        tx_levels = [level for level in model.levels if level.transaction.get("path") == tx.get("path")
                     and level.transaction.get("guid") == tx.get("guid")]
        rows = [row for level in tx_levels for row in _classify_model_level(level, model, attr_index, relations, table_views)]
        items.append({
            "transactionName": tx["name"],
            "transactionGuid": tx.get("guid"),
            "transactionPath": str(path),
            "coverage": _coverage_from_rows(rows),
            "levelAttributes": [attribute_writability_to_map_entry(row) for row in rows],
        })
    return {"writabilityRuleVersion": WRITABILITY_RULE_VERSION, "transactions": items,
            "inventoryStatus": "partial" if model.errors else "complete-in-model",
            "inventoryErrors": sorted(set(model.errors))}


def main() -> int:
    args = parse_args()
    catalog_path = args.catalog_path.resolve()
    transaction_type_guid = load_transaction_type_guid(catalog_path)
    try:
        if args.command == "classify-transaction":
            payload = classify_transaction_gate_payload(
                args.transaction_path,
                args.corpus_folder,
                transaction_type_guid,
            )
        elif args.command == "classify-batch":
            raw_paths = json.loads(args.transaction_paths_file.read_text(encoding="utf-8-sig"))
            if not isinstance(raw_paths, list):
                raise ValueError("transaction-paths-file must contain a JSON array of paths")
            payload = classify_transactions_batch_payload(
                [Path(str(item)) for item in raw_paths],
                args.corpus_folder,
                transaction_type_guid,
            )
        else:
            raise ValueError(f"Unsupported command: {args.command}")
    except (ValueError, OSError) as exc:
        print(str(exc), file=sys.stderr)
        return 1
    print(json.dumps(payload, ensure_ascii=False, indent=2))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
