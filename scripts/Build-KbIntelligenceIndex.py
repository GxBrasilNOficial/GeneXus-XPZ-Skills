#!/usr/bin/env python3
"""
Build a minimal GeneXus KB intelligence SQLite index.

Current scope:
- object inventory for every immediate SourceRoot type folder with XML files
- object identity via guid extracted from XML
- Source relations among Procedure, WebPanel, DataProvider, Transaction, API and DataSelector
  (including static calls resolved from the local inventory and legacy call/udp forms)
- WorkWith and WorkWithForWeb action gxobject links to Procedure and WebPanel
- WorkWith and WorkWithForWeb action parameters with Procedure .Link() references
- WorkWith and WorkWithForWeb condition expressions to Procedure
- WorkWith and WorkWithForWeb condition attributes to Procedure
- WorkWith and WorkWithForWeb explicit link tags to WebPanel
- WorkWith and WorkWithForWeb explicit prompt attributes to WebPanel
- WorkWith and WorkWithForWeb explicit transaction binding
- Source WebComponent Create calls to WebPanel
- literal ATTCUSTOMTYPE CustomType values
- explicit Source for each table references in Procedure and WebPanel
- qualified Source for each table-prefix references in Procedure and WebPanel
- Source Business Component Load calls with receiver resolved by variable ATTCUSTOMTYPE
- Source Business Component Save calls with receiver resolved by variable ATTCUSTOMTYPE
- Source Business Component Delete calls with receiver resolved by variable ATTCUSTOMTYPE
- Source Business Component Check calls with receiver resolved by variable ATTCUSTOMTYPE
- Source simple Business Component Insert and Update calls with receiver resolved by variable ATTCUSTOMTYPE
- Source ExternalObject method calls with receiver resolved by variable ATTCUSTOMTYPE
- Procedure .Link() references in effective Source and Attribute Formula
- Attribute Formula property references to Procedure, WebPanel and DataProvider when resolvable in the local inventory
"""

from __future__ import annotations

import argparse
import hashlib
import html
import json
import re
import sqlite3
import xml.etree.ElementTree as ElementTree
from dataclasses import dataclass
from datetime import datetime, timezone
from pathlib import Path
from typing import Iterable

# Incrementar quando a cobertura ou regras do indexador mudarem de forma material (nao em refator inerte).
EXTRACTOR_SIGNATURE_VERSION = "11"


def compute_extractor_signature_hash() -> str:
    script_path = Path(__file__).resolve()
    return hashlib.sha256(script_path.read_bytes()).hexdigest()


SOURCE_RE = re.compile(r"<Source(?:\s[^>]*)?>(?P<body>.*?)</Source>", re.IGNORECASE | re.DOTALL)
CDATA_RE = re.compile(r"^\s*<!\[CDATA\[(?P<body>.*)\]\]>\s*$", re.DOTALL)
LAST_UPDATE_RE = re.compile(r'\blastUpdate="([^"]+)"')
GUID_RE = re.compile(r'\bguid="([^"]+)"')
PROCEDURE_DOT_CALL_RE = re.compile(r"\b(?P<name>[A-Za-z_][A-Za-z0-9_]*)\s*\.\s*Call\s*\(", re.IGNORECASE)
PROCEDURE_CALL_COMMAND_RE = re.compile(r"(?<![&.\w])call\s*\(\s*(?P<name>[A-Za-z_][A-Za-z0-9_]*)(?!\s*:)", re.IGNORECASE)
PROCEDURE_UDP_FUNC_RE = re.compile(r"(?<![&.\w])udp\s*\(\s*(?P<name>[A-Za-z_][A-Za-z0-9_]*)(?!\s*:)", re.IGNORECASE)
PROCEDURE_DOT_UDP_RE = re.compile(r"(?<![&.])\b(?P<name>[A-Za-z_][A-Za-z0-9_]*)\s*\.\s*udp\s*\(", re.IGNORECASE)
PROCEDURE_DOT_LINK_RE = re.compile(r"(?<![&.])\b(?P<name>[A-Za-z_][A-Za-z0-9_]*)\s*\.\s*Link\s*\(", re.IGNORECASE)
WEBPANEL_DOT_LINK_RE = re.compile(r"\b(?P<name>[A-Za-z_][A-Za-z0-9_]*)\s*\.\s*Link\s*\(", re.IGNORECASE)
WEBPANEL_DOT_CREATE_RE = re.compile(r"(?<![&.])\b(?P<name>[A-Za-z_][A-Za-z0-9_]*)\s*\.\s*Create\s*\(", re.IGNORECASE)
FOR_EACH_EXPLICIT_TABLE_RE = re.compile(
    r"\bfor\s+each\s+(?P<name>[A-Za-z_][A-Za-z0-9_]*)\b(?!\s*\.)",
    re.IGNORECASE,
)
FOR_EACH_QUALIFIED_TABLE_RE = re.compile(
    r"\bfor\s+each\s+(?P<prefix>[A-Za-z_][A-Za-z0-9_]*)\s*\.\s*(?P<member>[A-Za-z_][A-Za-z0-9_]*)\b",
    re.IGNORECASE,
)
BC_LOAD_RE = re.compile(r"(?P<receiver>&[A-Za-z_][A-Za-z0-9_]*)\s*\.\s*Load\s*\(", re.IGNORECASE)
BC_SAVE_RE = re.compile(r"(?P<receiver>&[A-Za-z_][A-Za-z0-9_]*)\s*\.\s*Save\s*\(", re.IGNORECASE)
BC_DELETE_RE = re.compile(r"(?P<receiver>&[A-Za-z_][A-Za-z0-9_]*)\s*\.\s*Delete\s*\(", re.IGNORECASE)
BC_CHECK_RE = re.compile(r"(?P<receiver>&[A-Za-z_][A-Za-z0-9_]*)\s*\.\s*Check\s*\(", re.IGNORECASE)
BC_SIMPLE_INSERT_UPDATE_RE = re.compile(
    r"(?P<receiver>&[A-Za-z_][A-Za-z0-9_]*)\s*\.\s*(?P<method>Insert|Update)\s*\(",
    re.IGNORECASE,
)
EXTERNAL_OBJECT_METHOD_RE = re.compile(
    r"(?P<receiver>&[A-Za-z_][A-Za-z0-9_]*)\s*\.\s*(?P<method>[A-Za-z_][A-Za-z0-9_]*)\s*\(",
    re.IGNORECASE,
)
INDEXED_SOURCE_TYPES = ("Procedure", "WebPanel", "DataProvider", "Transaction", "API", "DataSelector")
FOR_EACH_SOURCE_TYPES = ("Procedure", "WebPanel")
BC_LOAD_SOURCE_TYPES = ("Procedure", "WebPanel", "DataProvider")
ACTION_RE = re.compile(r"<action\b(?P<attrs>[^>]*)>", re.IGNORECASE | re.DOTALL)
ACTION_BLOCK_RE = re.compile(r"<action\b(?P<attrs>[^>]*)>(?P<body>.*?)</action>", re.IGNORECASE | re.DOTALL)
CONDITION_RE = re.compile(r"<condition\b(?P<attrs>[^>]*)>", re.IGNORECASE | re.DOTALL)
TAG_RE = re.compile(r"<(?P<tag>[A-Za-z][A-Za-z0-9]*)\b(?P<attrs>[^>]*)>", re.IGNORECASE | re.DOTALL)
PARAMETER_RE = re.compile(r"<parameter\b(?P<attrs>[^>]*)/?>", re.IGNORECASE | re.DOTALL)
VARIABLE_RE = re.compile(r"<Variable\b(?P<attrs>[^>]*)>(?P<body>.*?)</Variable>", re.IGNORECASE | re.DOTALL)
ATTR_RE = re.compile(r'(?P<name>[A-Za-z_][A-Za-z0-9_]*)="(?P<value>[^"]*)"')
GXOBJECT_RE = re.compile(r"^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}-(?P<name>.+)$")
ATTCUSTOMTYPE_PROPERTY_RE = re.compile(
    r"<Property>\s*<Name>ATTCUSTOMTYPE</Name>\s*<Value>(?P<value>.*?)</Value>\s*</Property>",
    re.IGNORECASE | re.DOTALL,
)
ATTCOLLECTION_PROPERTY_RE = re.compile(
    r"<Property>\s*<Name>AttCollection</Name>\s*<Value>(?P<value>.*?)</Value>\s*</Property>",
    re.IGNORECASE | re.DOTALL,
)
IDBASEDON_PROPERTY_RE = re.compile(
    r"<Property>\s*<Name>idBasedOn</Name>\s*<Value>(?P<value>.*?)</Value>\s*</Property>",
    re.IGNORECASE | re.DOTALL,
)
FORMULA_PROPERTY_RE = re.compile(
    r"<Property>\s*<Name>Formula</Name>\s*<Value>(?P<value>.*?)</Value>\s*</Property>",
    re.IGNORECASE | re.DOTALL,
)
OBJECT_TYPE_GUID_RE = re.compile(r'<Object\b[^>]*\btype="([^"]+)"')
ATTRIBUTE_ROOT_RE = re.compile(r"^\s*(?:<\?xml[^>]*\?>\s*)?<Attribute\b", re.IGNORECASE)

# Catalogo e rastreabilidade de classes CSS (camada 1: catalogo css_class; camada 2: uso via relations/evidence).
# O SCSS de classes do modelo design-system vive no Part "Styles" deste type GUID, tanto em objetos
# DesignSystem autorais quanto em DesignSystem aninhados dentro de PackagedModule (libs importadas).
DESIGN_SYSTEM_STYLES_PART_GUID = "c6b14574-4f5f-4e35-aaa7-e322e88a9a10"
CSS_USAGE_SOURCE_TYPES = ("WebPanel", "Panel", "Transaction")
# Identificador de classe CSS aceita hifen e digito (ex.: Card-Basico) — distinto do identificador GeneXus.
CSS_SELECTOR_RE = re.compile(r"^\s*\.(?P<name>[A-Za-z][A-Za-z0-9_-]*)\s*\{", re.MULTILINE)
CSS_CLASS_NAME_RE = re.compile(r"^[A-Za-z][A-Za-z0-9_-]*$")
PART_RE = re.compile(r"<Part\b[^>]*\btype=\"(?P<type>[^\"]+)\"[^>]*>(?P<body>.*?)</Part>", re.IGNORECASE | re.DOTALL)
NAME_PROPERTY_RE = re.compile(
    r"<Property>\s*<Name>Name</Name>\s*<Value>(?P<value>.*?)</Value>\s*</Property>",
    re.IGNORECASE | re.DOTALL,
)
OBJECT_PARENT_ATTR_RE = re.compile(r"<Object\b[^>]*?\bparent=\"(?P<value>[^\"]*)\"", re.IGNORECASE)
SCSS_BLOCK_COMMENT_RE = re.compile(r"/\*.*?\*/", re.DOTALL)
SCSS_LINE_COMMENT_RE = re.compile(r"//[^\n]*")
DOT_CLASS_ASSIGN_RE = re.compile(r"\.Class\s*=\s*(?P<rhs>\S.*)$", re.IGNORECASE)
CSS_QUOTED_LITERAL_RE = re.compile(r"(?P<q>['\"])(?P<value>.*?)(?P=q)", re.DOTALL)
CSS_PREFIX_CLASS_RE = re.compile(r"\b(?:style|theme)class\s*:\s*(?P<name>[A-Za-z][A-Za-z0-9_-]*)", re.IGNORECASE)
CSS_DYNAMIC_HINT_RE = re.compile(r"&[A-Za-z_]|\bFormat\s*\(", re.IGNORECASE)
# Vetores reais de classe de tema no layout GeneXus: class (controle), cellClass (celula),
# rowClass (linha), formClass (form). gxObjClass NAO entra (valor numerico, nao e classe CSS).
LAYOUT_CLASS_ATTR_RE = re.compile(
    r"\b(?:class|cellClass|rowClass|formClass)\s*=\s*\"(?P<value>[^\"]*)\"",
    re.IGNORECASE,
)

from GeneXusObjectTypeCatalogCore import (  # noqa: E402
    CatalogOverrideDiagnosticError,
    build_type_guid_index,
    load_gx_object_type_catalog,
    resolve_effective_object_type_catalog,
)
from GeneXusTransactionWritabilityCore import (  # noqa: E402
    WRITABILITY_RULE_VERSION,
    build_corpus_writability,
    get_transaction_type_guid,
)


def build_catalog_override_blocked_result(exc: CatalogOverrideDiagnosticError) -> dict[str, object]:
    diagnostic = dict(exc.diagnostic)
    return {
        "status": diagnostic.get("status", "OVERRIDE_RESOLUTION_BLOCKED"),
        "blocked": True,
        "reason": diagnostic.get("reason"),
        "diagnosticReason": diagnostic.get("diagnosticReason"),
        "fieldPath": diagnostic.get("fieldPath"),
        "overridePath": diagnostic.get("overridePath"),
        "message": diagnostic.get("message", str(exc)),
        "catalogOverrideDiagnostic": diagnostic,
    }


def activate_object_type_catalog(
    source_root: Path,
    parallel_kb_root: Path | None = None,
    catalog_override_path: Path | None = None,
    base_catalog_path: Path | None = None,
) -> Path | None:
    """Set module-level catalog maps used during index build (base + override)."""
    global GX_OBJECT_TYPE_CATALOG, GX_TYPE_CATALOG_BY_NAME, GX_TYPE_BY_GUID
    merged, override_path = resolve_effective_object_type_catalog(
        source_root,
        parallel_kb_root=parallel_kb_root,
        catalog_override_path=catalog_override_path,
        base_catalog_path=base_catalog_path,
    )
    GX_OBJECT_TYPE_CATALOG = merged
    GX_TYPE_CATALOG_BY_NAME = merged["types"]
    GX_TYPE_BY_GUID = build_type_guid_index(GX_TYPE_CATALOG_BY_NAME)
    return override_path


GX_OBJECT_TYPE_CATALOG = load_gx_object_type_catalog()
GX_TYPE_CATALOG_BY_NAME: dict[str, dict[str, object]] = GX_OBJECT_TYPE_CATALOG["types"]
GX_TYPE_BY_GUID: dict[str, str] = build_type_guid_index(GX_TYPE_CATALOG_BY_NAME)


def load_legacy_export_registry() -> dict:
    """Carrega gx-legacy-export-element-registry.json (camada de governanca de export legado GX9).

    Dinamico: le o registro ao lado do script. Ausente -> registro vazio (comportamento inalterado).
    """
    registry_path = Path(__file__).resolve().parent / "gx-legacy-export-element-registry.json"
    if not registry_path.exists():
        return {"elements": {}}
    return json.loads(registry_path.read_text(encoding="utf-8"))


def build_legacy_orphan_folders(registry: dict) -> set[str]:
    """Conjunto de materializedFolderName dos elementos legados de classe 'orphan' (ex.: Report, Menubar)."""
    folders: set[str] = set()
    elements = registry.get("elements", {})
    if not isinstance(elements, dict):
        return folders
    for element in elements.values():
        if isinstance(element, dict) and element.get("class") == "orphan":
            folder = element.get("materializedFolderName")
            if folder:
                folders.add(str(folder))
    return folders


def build_legacy_orphan_folder_to_token(registry: dict) -> dict[str, str]:
    """Mapa materializedFolderName -> typeToken (lower) dos elementos legados de classe 'orphan'."""
    mapping: dict[str, str] = {}
    elements = registry.get("elements", {})
    if not isinstance(elements, dict):
        return mapping
    for element in elements.values():
        if isinstance(element, dict) and element.get("class") == "orphan":
            folder = element.get("materializedFolderName")
            token = element.get("typeToken")
            if folder and token:
                mapping[str(folder)] = str(token).lower()
    return mapping


GX_LEGACY_EXPORT_REGISTRY: dict = load_legacy_export_registry()
LEGACY_ORPHAN_FOLDERS: set[str] = build_legacy_orphan_folders(GX_LEGACY_EXPORT_REGISTRY)
LEGACY_ORPHAN_FOLDER_TO_TOKEN: dict[str, str] = build_legacy_orphan_folder_to_token(GX_LEGACY_EXPORT_REGISTRY)
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
    guid: str | None
    path: Path
    rel_path: str
    last_update: str | None
    file_hash: str
    is_generated_object: int
    pattern_object_id: str | None
    instance_key: str | None


@dataclass(frozen=True)
class InventorySemanticIssue:
    issue_kind: str
    expected_type: str
    actual_type: str
    file_path: str


@dataclass(frozen=True)
class InventoryScanSummary:
    snapshot_objects_by_directory: dict[str, int]
    folder_type_mismatches: list[InventorySemanticIssue]
    unknown_type_folders: list[str]
    legacy_orphan_directories_skipped: list[dict[str, object]]


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


@dataclass(frozen=True)
class CssClass:
    class_name: str
    model: str  # legacy-theme | design-system
    origin: str  # kb-authored | packaged-module
    defining_object_type: str
    defining_object_name: str
    defining_file: str
    parent_class: str | None
    extractor_rule: str


def read_text(path: Path) -> str:
    return path.read_text(encoding="utf-8-sig", errors="replace")


def sha256_text(text: str) -> str:
    return hashlib.sha256(text.encode("utf-8", errors="replace")).hexdigest()


# Marcadores de objeto gerado por Pattern (WorkWith For Web): extraidos APENAS do bloco
# <Properties> de nivel-objeto (filho direto do <Object> raiz), NUNCA de <Object> aninhado
# em <Part>/<ExportFile> (ex.: PackagedModule que empacota uma lib importada e materializa
# seus objetos internos, cada um com o proprio IsGeneratedObject). Ver design convergido.
OBJECT_MARKER_PROPERTY_RE = re.compile(
    r"<Property>\s*<Name>(?P<name>.*?)</Name>\s*<Value>(?P<value>.*?)</Value>\s*</Property>",
    re.IGNORECASE | re.DOTALL,
)
PROPERTIES_BLOCK_RE = re.compile(r"<Properties\b[^>]*>(?P<body>.*?)</Properties>", re.IGNORECASE | re.DOTALL)
XML_COMMENT_RE = re.compile(r"<!--.*?-->", re.DOTALL)
XML_CDATA_RE = re.compile(r"<!\[CDATA\[.*?\]\]>", re.DOTALL)


def markers_from_property_dict(props: dict[str, str]) -> tuple[int, str | None, str | None]:
    is_generated = 1 if props.get("IsGeneratedObject", "").strip().lower() == "true" else 0
    pattern_object_id = props.get("PatternObjectId")
    pattern_object_id = pattern_object_id.strip() if pattern_object_id else None
    instance_key = props.get("InstanceKey")
    instance_key = instance_key.strip() if instance_key else None
    return is_generated, pattern_object_id, instance_key


def object_level_property_dict_via_parse(text: str) -> dict[str, str]:
    """Filhos <Property> do <Properties> filho DIRETO do <Object> raiz (ignora aninhados)."""
    root = ElementTree.fromstring(text.encode("utf-8"))
    props: dict[str, str] = {}
    properties_el = root.find("Properties")
    if properties_el is not None:
        for prop in properties_el.findall("Property"):
            name_el = prop.find("Name")
            value_el = prop.find("Value")
            if name_el is not None and name_el.text:
                value = value_el.text if (value_el is not None and value_el.text is not None) else ""
                props[name_el.text.strip()] = value
    return props


def object_level_property_dict_via_regex(text: str) -> dict[str, str]:
    """Fallback best-effort para XML malformado (o parse primario cobre 100% do XML bem-formado).

    Usa o ULTIMO bloco <Properties> (o de nivel-objeto vem depois dos <Part>), ignorando
    comentarios/CDATA. Limitacao documentada: shape malformado patologico pode divergir.
    """
    stripped = XML_CDATA_RE.sub("", XML_COMMENT_RE.sub("", text))
    blocks = PROPERTIES_BLOCK_RE.findall(stripped)
    props: dict[str, str] = {}
    if blocks:
        for match in OBJECT_MARKER_PROPERTY_RE.finditer(blocks[-1]):
            props[html.unescape(match.group("name")).strip()] = html.unescape(match.group("value"))
    return props


def extract_object_level_markers(text: str) -> tuple[int, str | None, str | None]:
    """(is_generated_object, pattern_object_id, instance_key) do <Properties> do OBJETO RAIZ.

    Primario: parse XML por bytes (portavel entre versoes; str com declaracao de encoding
    quebra em versoes antigas). Fallback: regex do ultimo bloco, so em XML malformado.
    """
    try:
        props = object_level_property_dict_via_parse(text)
    except (ElementTree.ParseError, ValueError):
        props = object_level_property_dict_via_regex(text)
    return markers_from_property_dict(props)


def line_number_at(text: str, index: int) -> int:
    return text.count("\n", 0, index) + 1


def resolve_canonical_type(text: str) -> tuple[str | None, str | None]:
    """Return (canonical_type, guid). canonical_type is None when the GUID is unknown."""
    if ATTRIBUTE_ROOT_RE.match(text[:1024]):
        return "Attribute", None
    m = OBJECT_TYPE_GUID_RE.search(text)
    if not m:
        return None, None
    guid = m.group(1)
    return GX_TYPE_BY_GUID.get(guid.lower()), guid


def collect_objects(
    folder: Path,
    source_root: Path,
    unknown_guids: list[tuple[str, str]],
    folder_type_mismatches: list[InventorySemanticIssue],
) -> dict[str, dict[str, ObjectInfo]]:
    objects_by_type: dict[str, dict[str, ObjectInfo]] = {}
    folder_name = folder.name
    for path in sorted(folder.glob("*.xml")):
        text = read_text(path)
        canonical_type, guid = resolve_canonical_type(text)
        if canonical_type is None:
            unknown_guids.append((guid or "(no type attribute)", path.relative_to(source_root).as_posix()))
            continue
        if canonical_type != folder_name:
            folder_type_mismatches.append(
                InventorySemanticIssue(
                    issue_kind="folder_type_mismatch",
                    expected_type=folder_name,
                    actual_type=canonical_type,
                    file_path=path.relative_to(source_root).as_posix(),
                )
            )
        last_update_match = LAST_UPDATE_RE.search(text)
        guid_match = GUID_RE.search(text)
        rel_path = path.relative_to(source_root).as_posix()
        name = path.stem
        if canonical_type not in objects_by_type:
            objects_by_type[canonical_type] = {}
        is_generated_object, pattern_object_id, instance_key = extract_object_level_markers(text)
        objects_by_type[canonical_type][name] = ObjectInfo(
            object_type=canonical_type,
            name=name,
            guid=guid_match.group(1) if guid_match else None,
            path=path,
            rel_path=rel_path,
            last_update=last_update_match.group(1) if last_update_match else None,
            file_hash=sha256_text(text),
            is_generated_object=is_generated_object,
            pattern_object_id=pattern_object_id,
            instance_key=instance_key,
        )
    return objects_by_type


def folder_is_all_legacy_orphan(folder: Path) -> bool:
    """True sse a pasta tem XML(s) e TODO XML tem Object/@type == o typeToken REGISTRADO para esta
    pasta orfa (materializedFolderName -> typeToken no registro).

    Skip content-aware GOVERNADO PELO REGISTRO: a pasta 'Report' so e pulada se TODO XML for
    exatamente o token registrado (gxlegacy/Report). Conteudo moderno (GUID real) OU token gxlegacy
    errado/nao-registrado para a pasta (ex.: gxlegacy/Foo numa pasta Report) NAO e pulado — segue ao
    caminho normal, que o flagra (folder_type_mismatch / unknown_guids). Evita mascarar diretorio
    mal-nomeado ou orfao com token divergente em silencio.
    """
    expected_token = LEGACY_ORPHAN_FOLDER_TO_TOKEN.get(folder.name)
    if expected_token is None:
        return False
    xmls = sorted(folder.glob("*.xml"))
    if not xmls:
        return False
    for path in xmls:
        text = read_text(path)
        match = OBJECT_TYPE_GUID_RE.search(text)
        if match is None or match.group(1).lower() != expected_token:
            return False
    return True


def collect_all_objects(source_root: Path) -> tuple[dict[str, dict[str, ObjectInfo]], InventoryScanSummary]:
    objects_by_type: dict[str, dict[str, ObjectInfo]] = {}
    unknown_guids: list[tuple[str, str]] = []
    folder_type_mismatches: list[InventorySemanticIssue] = []
    snapshot_objects_by_directory: dict[str, int] = {}
    unknown_type_folders: list[str] = []
    legacy_orphan_directories_skipped: list[dict[str, object]] = []
    for folder in sorted(source_root.iterdir(), key=lambda item: item.name.lower()):
        if not folder.is_dir():
            continue
        xml_count = sum(1 for _ in folder.glob("*.xml"))
        if xml_count == 0:
            continue
        # Pastas de elementos legados orfaos (registro gx-legacy-export-element-registry.json):
        # reconhecidas como known-legacy e puladas na MESMA passada — ficam fora do snapshot, de
        # unknown_type_folders e da coleta. Evita o raise SystemExit por unknown_guids (type=gxlegacy/*
        # nao casa GUID) e o BLOCK por directory_inventory_mismatch (pasta fora do snapshot nao diverge).
        # O skip e CONTENT-AWARE (folder_is_all_legacy_orphan): so pula se TODO XML for orfao gxlegacy/*;
        # pasta mal-nomeada com conteudo moderno NAO e pulada — segue ao caminho normal, que a flagra.
        # O skip fica auditavel em legacy_orphan_directories_skipped (nao silenciar XML orfaos presentes).
        if folder.name in LEGACY_ORPHAN_FOLDERS and folder_is_all_legacy_orphan(folder):
            legacy_orphan_directories_skipped.append({"directory": folder.name, "xml_count": xml_count})
            continue
        snapshot_objects_by_directory[folder.name] = xml_count
        if folder.name not in GX_TYPE_CATALOG_BY_NAME:
            unknown_type_folders.append(folder.name)
        folder_objects = collect_objects(folder, source_root, unknown_guids, folder_type_mismatches)
        for type_name, objs in folder_objects.items():
            if type_name not in objects_by_type:
                objects_by_type[type_name] = {}
            objects_by_type[type_name].update(objs)
    if unknown_guids:
        lines = [
            "",
            "ERRO: GUIDs de tipo desconhecidos encontrados no acervo.",
            "O índice não pode ser construído enquanto todos os tipos não forem identificados.",
            "Informe o agente ou o administrador do acervo para atualizar scripts/gx-object-type-catalog.json",
            "(ou scripts/gx-object-type-catalog.override.json na pasta paralela, paliativo) e refletir",
            "o novo tipo em 01a-catalogo-e-padroes-empiricos.md quando for entrada upstream.",
            "GUIDs encontrados:",
            "",
        ]
        for guid, rel in sorted(set(unknown_guids)):
            lines.append(f"  GUID: {guid}")
            lines.append(f"  Arquivo: {rel}")
            lines.append("")
        raise SystemExit("\n".join(lines))
    return objects_by_type, InventoryScanSummary(
        snapshot_objects_by_directory=snapshot_objects_by_directory,
        folder_type_mismatches=folder_type_mismatches,
        unknown_type_folders=sorted(set(unknown_type_folders)),
        legacy_orphan_directories_skipped=sorted(
            legacy_orphan_directories_skipped, key=lambda item: str(item["directory"])
        ),
    )


def validate_inventory_semantics(
    objects_by_type: dict[str, dict[str, ObjectInfo]],
    scan_summary: InventoryScanSummary,
) -> dict[str, object]:
    indexed_objects_by_type = {key: len(value) for key, value in objects_by_type.items()}
    mismatches: list[dict[str, object]] = []

    for folder_name, snapshot_count in sorted(scan_summary.snapshot_objects_by_directory.items()):
        indexed_count = indexed_objects_by_type.get(folder_name, 0)
        if indexed_count != snapshot_count:
            mismatches.append(
                {
                    "issue_kind": "directory_inventory_mismatch",
                    "directory": folder_name,
                    "snapshot_count": snapshot_count,
                    "indexed_count": indexed_count,
                }
            )

    for issue in scan_summary.folder_type_mismatches:
        mismatches.append(
            {
                "issue_kind": issue.issue_kind,
                "expected_type": issue.expected_type,
                "actual_type": issue.actual_type,
                "file_path": issue.file_path,
            }
        )

    for folder_name in scan_summary.unknown_type_folders:
        mismatches.append(
            {
                "issue_kind": "unknown_type_folder",
                "directory": folder_name,
                "snapshot_count": scan_summary.snapshot_objects_by_directory.get(folder_name, 0),
            }
        )

    indexed_only_types = sorted(
        type_name
        for type_name in indexed_objects_by_type
        if type_name not in scan_summary.snapshot_objects_by_directory
    )
    for type_name in indexed_only_types:
        mismatches.append(
            {
                "issue_kind": "indexed_type_without_snapshot_directory",
                "type": type_name,
                "indexed_count": indexed_objects_by_type[type_name],
            }
        )

    return {
        "status": "OK" if not mismatches else "BLOCK",
        "catalog_version": GX_OBJECT_TYPE_CATALOG["version"],
        "snapshot_objects_by_directory": dict(sorted(scan_summary.snapshot_objects_by_directory.items())),
        "indexed_objects_by_type": dict(sorted(indexed_objects_by_type.items())),
        "legacy_orphan_directories_skipped": scan_summary.legacy_orphan_directories_skipped,
        "mismatch_count": len(mismatches),
        "mismatches": mismatches,
    }


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
    return re.compile(rf"(?<![&.])\b(?P<name>{alternatives})\s*\(", re.IGNORECASE)


def append_call_evidences_from_expression(
    evidences: list[Evidence],
    *,
    source: ObjectInfo,
    xml_text: str,
    expression: str,
    expression_start: int,
    evidence_role: str,
    procedure_lookup: dict[str, str],
    webpanel_lookup: dict[str, str],
    data_provider_lookup: dict[str, str],
    data_provider_direct_re: re.Pattern[str] | None,
    procedure_direct_re: re.Pattern[str] | None,
    relation_kind_procedure: str,
    relation_kind_webpanel_link: str,
    relation_kind_webpanel_create: str,
    relation_kind_dataprovider: str,
    extractor_rule_procedure_direct: str,
    extractor_rule_procedure_dot: str,
    extractor_rule_procedure_dot_link: str,
    extractor_rule_webpanel_link: str,
    extractor_rule_procedure_call_command: str | None,
    extractor_rule_webpanel_create: str,
    extractor_rule_dataprovider_direct: str,
    extractor_rule_procedure_udp_func: str | None = None,
    extractor_rule_procedure_dot_udp: str | None = None,
) -> None:
    line_no = line_number_at(xml_text, expression_start)
    for match in PROCEDURE_DOT_CALL_RE.finditer(expression):
        matched_name = match.group("name")
        target_name = procedure_lookup.get(matched_name.lower())
        if target_name:
            add_evidence(
                evidences,
                source=source,
                target_type="Procedure",
                target_name=target_name,
                relation_kind=relation_kind_procedure,
                line=line_no,
                column=match.start("name") + 1,
                snippet=expression,
                extractor_rule=extractor_rule_procedure_dot,
                evidence_role=evidence_role,
            )

    direct_matches = procedure_direct_re.finditer(expression) if procedure_direct_re else ()
    for match in direct_matches:
        matched_name = match.group("name")
        target_name = procedure_lookup.get(matched_name.lower())
        if target_name:
            add_evidence(
                evidences,
                source=source,
                target_type="Procedure",
                target_name=target_name,
                relation_kind=relation_kind_procedure,
                line=line_no,
                column=match.start("name") + 1,
                snippet=expression,
                extractor_rule=extractor_rule_procedure_direct,
                evidence_role=evidence_role,
            )

    if extractor_rule_procedure_call_command:
        for match in PROCEDURE_CALL_COMMAND_RE.finditer(expression):
            matched_name = match.group("name")
            target_name = procedure_lookup.get(matched_name.lower())
            if target_name:
                add_evidence(
                    evidences,
                    source=source,
                    target_type="Procedure",
                    target_name=target_name,
                    relation_kind=relation_kind_procedure,
                    line=line_no,
                    column=match.start("name") + 1,
                    snippet=expression,
                    extractor_rule=extractor_rule_procedure_call_command,
                    evidence_role=evidence_role,
                )

    if extractor_rule_procedure_udp_func:
        for match in PROCEDURE_UDP_FUNC_RE.finditer(expression):
            matched_name = match.group("name")
            target_name = procedure_lookup.get(matched_name.lower())
            if target_name:
                add_evidence(
                    evidences,
                    source=source,
                    target_type="Procedure",
                    target_name=target_name,
                    relation_kind=relation_kind_procedure,
                    line=line_no,
                    column=match.start("name") + 1,
                    snippet=expression,
                    extractor_rule=extractor_rule_procedure_udp_func,
                    evidence_role=evidence_role,
                )

    if extractor_rule_procedure_dot_udp:
        for match in PROCEDURE_DOT_UDP_RE.finditer(expression):
            matched_name = match.group("name")
            target_name = procedure_lookup.get(matched_name.lower())
            if target_name:
                add_evidence(
                    evidences,
                    source=source,
                    target_type="Procedure",
                    target_name=target_name,
                    relation_kind=relation_kind_procedure,
                    line=line_no,
                    column=match.start("name") + 1,
                    snippet=expression,
                    extractor_rule=extractor_rule_procedure_dot_udp,
                    evidence_role=evidence_role,
                )

    for match in PROCEDURE_DOT_LINK_RE.finditer(expression):
        matched_name = match.group("name")
        target_name = procedure_lookup.get(matched_name.lower())
        if target_name:
            add_evidence(
                evidences,
                source=source,
                target_type="Procedure",
                target_name=target_name,
                relation_kind=relation_kind_procedure,
                line=line_no,
                column=match.start("name") + 1,
                snippet=expression,
                extractor_rule=extractor_rule_procedure_dot_link,
                evidence_role=evidence_role,
            )

    for match in WEBPANEL_DOT_LINK_RE.finditer(expression):
        matched_name = match.group("name")
        target_name = webpanel_lookup.get(matched_name.lower())
        if target_name:
            add_evidence(
                evidences,
                source=source,
                target_type="WebPanel",
                target_name=target_name,
                relation_kind=relation_kind_webpanel_link,
                line=line_no,
                column=match.start("name") + 1,
                snippet=expression,
                extractor_rule=extractor_rule_webpanel_link,
                evidence_role=evidence_role,
            )

    for match in WEBPANEL_DOT_CREATE_RE.finditer(expression):
        matched_name = match.group("name")
        target_name = webpanel_lookup.get(matched_name.lower())
        if target_name:
            add_evidence(
                evidences,
                source=source,
                target_type="WebPanel",
                target_name=target_name,
                relation_kind=relation_kind_webpanel_create,
                line=line_no,
                column=match.start("name") + 1,
                snippet=expression,
                extractor_rule=extractor_rule_webpanel_create,
                evidence_role=evidence_role,
            )

    if data_provider_direct_re:
        for match in data_provider_direct_re.finditer(expression):
            matched_name = match.group("name")
            target_name = data_provider_lookup.get(matched_name.lower())
            if target_name:
                add_evidence(
                    evidences,
                    source=source,
                    target_type="DataProvider",
                    target_name=target_name,
                    relation_kind=relation_kind_dataprovider,
                    line=line_no,
                    column=match.start("name") + 1,
                    snippet=expression,
                    extractor_rule=extractor_rule_dataprovider_direct,
                    evidence_role=evidence_role,
                )


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
    procedure_direct_re = direct_call_pattern(procedure_names)
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

                direct_matches = procedure_direct_re.finditer(cleaned) if procedure_direct_re else ()
                for match in direct_matches:
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

                for match in PROCEDURE_CALL_COMMAND_RE.finditer(cleaned):
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
                            extractor_rule="procedure_call_command",
                        )

                for match in PROCEDURE_UDP_FUNC_RE.finditer(cleaned):
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
                            extractor_rule="procedure_udp_func",
                        )

                for match in PROCEDURE_DOT_UDP_RE.finditer(cleaned):
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
                            extractor_rule="procedure_dot_udp",
                        )

                for match in PROCEDURE_DOT_LINK_RE.finditer(cleaned):
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
                            extractor_rule="procedure_dot_link",
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

                for match in WEBPANEL_DOT_CREATE_RE.finditer(cleaned):
                    matched_name = match.group("name")
                    target_name = webpanel_lookup.get(matched_name.lower())
                    if target_name:
                        add_evidence(
                            evidences,
                            source=source,
                            target_type="WebPanel",
                            target_name=target_name,
                            relation_kind="creates_webcomponent",
                            line=line_no,
                            column=match.start("name") + 1,
                            snippet=cleaned,
                            extractor_rule="webpanel_dot_create",
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


def bc_variable_targets(xml_text: str, transaction_lookup: dict[str, str]) -> dict[str, str]:
    targets: dict[str, str] = {}
    for match in VARIABLE_RE.finditer(xml_text):
        attrs = parse_attributes(match.group("attrs"))
        variable_name = attrs.get("Name")
        if not variable_name:
            continue
        custom_type_match = ATTCUSTOMTYPE_PROPERTY_RE.search(match.group("body"))
        if not custom_type_match:
            continue
        custom_type = normalize_custom_type(custom_type_match.group("value"))
        if not custom_type.lower().startswith("bc:"):
            continue
        raw_transaction_name = custom_type.split(":", 1)[1].strip()
        target_name = transaction_lookup.get(raw_transaction_name.lower())
        if not target_name:
            continue
        targets[variable_name.lower()] = target_name
    return targets


def simple_bc_variable_targets(xml_text: str, transaction_lookup: dict[str, str]) -> dict[str, str]:
    targets: dict[str, str] = {}
    for match in VARIABLE_RE.finditer(xml_text):
        attrs = parse_attributes(match.group("attrs"))
        variable_name = attrs.get("Name")
        if not variable_name:
            continue
        body = match.group("body")
        collection_match = ATTCOLLECTION_PROPERTY_RE.search(body)
        if collection_match and collection_match.group("value").strip().lower() == "true":
            continue
        custom_type_match = ATTCUSTOMTYPE_PROPERTY_RE.search(body)
        if not custom_type_match:
            continue
        custom_type = normalize_custom_type(custom_type_match.group("value"))
        if not custom_type.lower().startswith("bc:"):
            continue
        raw_transaction_name = custom_type.split(":", 1)[1].strip()
        target_name = transaction_lookup.get(raw_transaction_name.lower())
        if not target_name:
            continue
        targets[variable_name.lower()] = target_name
    return targets


def external_object_variable_targets(xml_text: str, external_object_lookup: dict[str, str]) -> dict[str, str]:
    targets: dict[str, str] = {}
    for match in VARIABLE_RE.finditer(xml_text):
        attrs = parse_attributes(match.group("attrs"))
        variable_name = attrs.get("Name")
        if not variable_name:
            continue
        custom_type_match = ATTCUSTOMTYPE_PROPERTY_RE.search(match.group("body"))
        if not custom_type_match:
            continue
        custom_type = normalize_custom_type(custom_type_match.group("value"))
        if not custom_type.lower().startswith("exo:"):
            continue
        raw_external_object_name = custom_type.split(":", 1)[1].split(",", 1)[0].strip()
        target_name = external_object_lookup.get(raw_external_object_name.lower())
        if not target_name:
            continue
        targets[variable_name.lower()] = target_name
    return targets


def extract_source_bc_load_transaction_evidence(
    source_objects: Iterable[ObjectInfo],
    transaction_names: set[str],
) -> list[Evidence]:
    evidences: list[Evidence] = []
    transaction_lookup = case_insensitive_lookup(transaction_names, "Transaction")

    for source in source_objects:
        xml_text = read_text(source.path)
        variable_targets = bc_variable_targets(xml_text, transaction_lookup)
        if not variable_targets:
            continue
        for block in source_blocks(xml_text):
            for offset, line in enumerate(block.text.splitlines()):
                cleaned = active_line(line)
                if not cleaned.strip():
                    continue
                line_no = block.start_line + offset

                for match in BC_LOAD_RE.finditer(cleaned):
                    receiver_name = match.group("receiver")[1:]
                    target_name = variable_targets.get(receiver_name.lower())
                    if not target_name:
                        continue
                    add_evidence(
                        evidences,
                        source=source,
                        target_type="Transaction",
                        target_name=target_name,
                        relation_kind="loads_business_component",
                        line=line_no,
                        column=match.start("receiver") + 1,
                        snippet=cleaned,
                        extractor_rule="source_bc_load_transaction",
                        evidence_role="Source BC Load",
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


def extract_source_bc_save_transaction_evidence(
    source_objects: Iterable[ObjectInfo],
    transaction_names: set[str],
) -> list[Evidence]:
    evidences: list[Evidence] = []
    transaction_lookup = case_insensitive_lookup(transaction_names, "Transaction")

    for source in source_objects:
        xml_text = read_text(source.path)
        variable_targets = bc_variable_targets(xml_text, transaction_lookup)
        if not variable_targets:
            continue
        for block in source_blocks(xml_text):
            for offset, line in enumerate(block.text.splitlines()):
                cleaned = active_line(line)
                if not cleaned.strip():
                    continue
                line_no = block.start_line + offset

                for match in BC_SAVE_RE.finditer(cleaned):
                    receiver_name = match.group("receiver")[1:]
                    target_name = variable_targets.get(receiver_name.lower())
                    if not target_name:
                        continue
                    add_evidence(
                        evidences,
                        source=source,
                        target_type="Transaction",
                        target_name=target_name,
                        relation_kind="saves_business_component",
                        line=line_no,
                        column=match.start("receiver") + 1,
                        snippet=cleaned,
                        extractor_rule="source_bc_save_transaction",
                        evidence_role="Source BC Save",
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


def extract_source_bc_delete_transaction_evidence(
    source_objects: Iterable[ObjectInfo],
    transaction_names: set[str],
) -> list[Evidence]:
    evidences: list[Evidence] = []
    transaction_lookup = case_insensitive_lookup(transaction_names, "Transaction")

    for source in source_objects:
        xml_text = read_text(source.path)
        variable_targets = bc_variable_targets(xml_text, transaction_lookup)
        if not variable_targets:
            continue
        for block in source_blocks(xml_text):
            for offset, line in enumerate(block.text.splitlines()):
                cleaned = active_line(line)
                if not cleaned.strip():
                    continue
                line_no = block.start_line + offset

                for match in BC_DELETE_RE.finditer(cleaned):
                    receiver_name = match.group("receiver")[1:]
                    target_name = variable_targets.get(receiver_name.lower())
                    if not target_name:
                        continue
                    add_evidence(
                        evidences,
                        source=source,
                        target_type="Transaction",
                        target_name=target_name,
                        relation_kind="deletes_business_component",
                        line=line_no,
                        column=match.start("receiver") + 1,
                        snippet=cleaned,
                        extractor_rule="source_bc_delete_transaction",
                        evidence_role="Source BC Delete",
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


def extract_source_bc_check_transaction_evidence(
    source_objects: Iterable[ObjectInfo],
    transaction_names: set[str],
) -> list[Evidence]:
    evidences: list[Evidence] = []
    transaction_lookup = case_insensitive_lookup(transaction_names, "Transaction")

    for source in source_objects:
        xml_text = read_text(source.path)
        variable_targets = bc_variable_targets(xml_text, transaction_lookup)
        if not variable_targets:
            continue
        for block in source_blocks(xml_text):
            for offset, line in enumerate(block.text.splitlines()):
                cleaned = active_line(line)
                if not cleaned.strip():
                    continue
                line_no = block.start_line + offset

                for match in BC_CHECK_RE.finditer(cleaned):
                    receiver_name = match.group("receiver")[1:]
                    target_name = variable_targets.get(receiver_name.lower())
                    if not target_name:
                        continue
                    add_evidence(
                        evidences,
                        source=source,
                        target_type="Transaction",
                        target_name=target_name,
                        relation_kind="checks_business_component",
                        line=line_no,
                        column=match.start("receiver") + 1,
                        snippet=cleaned,
                        extractor_rule="source_bc_check_transaction",
                        evidence_role="Source BC Check",
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


def extract_source_simple_bc_insert_update_transaction_evidence(
    source_objects: Iterable[ObjectInfo],
    transaction_names: set[str],
) -> list[Evidence]:
    evidences: list[Evidence] = []
    transaction_lookup = case_insensitive_lookup(transaction_names, "Transaction")

    for source in source_objects:
        xml_text = read_text(source.path)
        variable_targets = simple_bc_variable_targets(xml_text, transaction_lookup)
        if not variable_targets:
            continue
        for block in source_blocks(xml_text):
            for offset, line in enumerate(block.text.splitlines()):
                cleaned = active_line(line)
                if not cleaned.strip():
                    continue
                line_no = block.start_line + offset

                for match in BC_SIMPLE_INSERT_UPDATE_RE.finditer(cleaned):
                    receiver_name = match.group("receiver")[1:]
                    target_name = variable_targets.get(receiver_name.lower())
                    if not target_name:
                        continue
                    method = match.group("method").lower()
                    add_evidence(
                        evidences,
                        source=source,
                        target_type="Transaction",
                        target_name=target_name,
                        relation_kind=f"{method}s_business_component",
                        line=line_no,
                        column=match.start("receiver") + 1,
                        snippet=cleaned,
                        extractor_rule=f"source_simple_bc_{method}_transaction",
                        evidence_role=f"Source Simple BC {method.capitalize()}",
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


def extract_source_external_object_method_evidence(
    source_objects: Iterable[ObjectInfo],
    external_object_names: set[str],
) -> list[Evidence]:
    evidences: list[Evidence] = []
    external_object_lookup = case_insensitive_lookup(external_object_names, "ExternalObject")

    for source in source_objects:
        xml_text = read_text(source.path)
        variable_targets = external_object_variable_targets(xml_text, external_object_lookup)
        if not variable_targets:
            continue
        for block in source_blocks(xml_text):
            for offset, line in enumerate(block.text.splitlines()):
                cleaned = active_line(line)
                if not cleaned.strip():
                    continue
                line_no = block.start_line + offset

                for match in EXTERNAL_OBJECT_METHOD_RE.finditer(cleaned):
                    receiver_name = match.group("receiver")[1:]
                    target_name = variable_targets.get(receiver_name.lower())
                    if not target_name:
                        continue
                    add_evidence(
                        evidences,
                        source=source,
                        target_type="ExternalObject",
                        target_name=target_name,
                        relation_kind="calls_external_object_method",
                        line=line_no,
                        column=match.start("receiver") + 1,
                        snippet=cleaned,
                        extractor_rule="source_external_object_method",
                        evidence_role="Source ExternalObject method",
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

        for action_match in ACTION_BLOCK_RE.finditer(xml_text):
            action_body = action_match.group("body")
            for parameter_match in PARAMETER_RE.finditer(action_body):
                attrs = parse_attributes(parameter_match.group("attrs"))
                expression = attrs.get("name")
                if not expression:
                    continue
                parameter_start = action_match.start("body") + parameter_match.start()
                for link_match in PROCEDURE_DOT_LINK_RE.finditer(expression):
                    target_name = procedure_lookup.get(link_match.group("name").lower())
                    if not target_name:
                        continue
                    add_evidence(
                        evidences,
                        source=source,
                        target_type="Procedure",
                        target_name=target_name,
                        relation_kind="workwith_action_parameter_calls_procedure",
                        line=line_number_at(xml_text, parameter_start),
                        column=link_match.start("name") + 1,
                        snippet=parameter_match.group(0),
                        extractor_rule="workwith_action_parameter_procedure_dot_link",
                        evidence_role="WorkWith action parameter",
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


def append_workwith_condition_extra_procedure_calls(
    evidences: list[Evidence],
    *,
    source: ObjectInfo,
    expression: str,
    procedure_lookup: dict[str, str],
    relation_kind: str,
    extractor_rule_prefix: str,
    snippet: str,
    line: int,
    evidence_role: str,
) -> None:
    for regex, suffix in (
        (PROCEDURE_DOT_CALL_RE, "dot_call"),
        (PROCEDURE_CALL_COMMAND_RE, "call_command"),
        (PROCEDURE_UDP_FUNC_RE, "udp_func"),
        (PROCEDURE_DOT_UDP_RE, "dot_udp"),
    ):
        for match in regex.finditer(expression):
            target_name = procedure_lookup.get(match.group("name").lower())
            if not target_name:
                continue
            add_evidence(
                evidences,
                source=source,
                target_type="Procedure",
                target_name=target_name,
                relation_kind=relation_kind,
                line=line,
                column=1,
                snippet=snippet,
                extractor_rule=f"{extractor_rule_prefix}_{suffix}",
                evidence_role=evidence_role,
            )


def extract_workwith_condition_evidence(
    workwith_objects: Iterable[ObjectInfo],
    procedure_names: set[str],
) -> list[Evidence]:
    evidences: list[Evidence] = []
    procedure_lookup = case_insensitive_lookup(procedure_names, "Procedure")
    procedure_direct_re = direct_call_pattern(procedure_names)

    for source in workwith_objects:
        xml_text = read_text(source.path)
        for condition_match in CONDITION_RE.finditer(xml_text):
            attrs = parse_attributes(condition_match.group("attrs"))
            condition_value = attrs.get("value")
            if not condition_value:
                continue

            expression = effective_condition_expression(condition_value)
            direct_matches = procedure_direct_re.finditer(expression) if procedure_direct_re else ()
            for procedure_match in direct_matches:
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

            append_workwith_condition_extra_procedure_calls(
                evidences,
                source=source,
                expression=expression,
                procedure_lookup=procedure_lookup,
                relation_kind="workwith_condition_calls_procedure",
                extractor_rule_prefix="workwith_condition_procedure",
                snippet=condition_match.group(0),
                line=line_number_at(xml_text, condition_match.start()),
                evidence_role="WorkWith condition",
            )

    unique: dict[tuple[str, str, str, str, int], Evidence] = {}
    for evidence in evidences:
        unique[(evidence.source_type, evidence.source_name, evidence.target_name, evidence.extractor_rule, evidence.line)] = evidence
    return list(unique.values())


def extract_workwith_condition_attribute_evidence(
    workwith_objects: Iterable[ObjectInfo],
    procedure_names: set[str],
) -> list[Evidence]:
    evidences: list[Evidence] = []
    procedure_lookup = case_insensitive_lookup(procedure_names, "Procedure")
    procedure_direct_re = direct_call_pattern(procedure_names)

    for source in workwith_objects:
        xml_text = read_text(source.path)
        for tag_match in TAG_RE.finditer(xml_text):
            attrs = parse_attributes(tag_match.group("attrs"))
            for attr_name, attr_value in attrs.items():
                if not attr_name.lower().endswith("condition"):
                    continue

                expression = effective_condition_expression(attr_value)
                direct_matches = procedure_direct_re.finditer(expression) if procedure_direct_re else ()
                for procedure_match in direct_matches:
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

                append_workwith_condition_extra_procedure_calls(
                    evidences,
                    source=source,
                    expression=expression,
                    procedure_lookup=procedure_lookup,
                    relation_kind="workwith_condition_attribute_calls_procedure",
                    extractor_rule_prefix="workwith_condition_attribute_procedure",
                    snippet=tag_match.group(0),
                    line=line_number_at(xml_text, tag_match.start()),
                    evidence_role="WorkWith condition attribute",
                )

    unique: dict[tuple[str, str, str, str, int], Evidence] = {}
    for evidence in evidences:
        unique[(evidence.source_type, evidence.source_name, evidence.target_name, evidence.extractor_rule, evidence.line)] = evidence
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

    unique: dict[tuple[str, str, str, str, int], Evidence] = {}
    for evidence in evidences:
        unique[(evidence.source_type, evidence.source_name, evidence.target_name, evidence.extractor_rule, evidence.line)] = evidence
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

    unique: dict[tuple[str, str, str, str, int], Evidence] = {}
    for evidence in evidences:
        unique[(evidence.source_type, evidence.source_name, evidence.target_name, evidence.extractor_rule, evidence.line)] = evidence
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

    unique: dict[tuple[str, str, str, str, int], Evidence] = {}
    for evidence in evidences:
        unique[(evidence.source_type, evidence.source_name, evidence.target_name, evidence.extractor_rule, evidence.line)] = evidence
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
    external_object_lookup: dict[str, str],
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
    if prefix.lower() == "exo":
        normalized_name = raw_name.split(",", 1)[0].strip()
        target_name = external_object_lookup.get(normalized_name.lower())
        if target_name:
            return "ExternalObject", target_name
    return None


def extract_attcustomtype_resolved_evidence(
    source_objects: Iterable[ObjectInfo],
    sdt_names: set[str],
    domain_names: set[str],
    external_object_names: set[str],
) -> list[Evidence]:
    evidences: list[Evidence] = []
    sdt_lookup = case_insensitive_lookup(sdt_names, "SDT")
    domain_lookup = case_insensitive_lookup(domain_names, "Domain")
    external_object_lookup = case_insensitive_lookup(external_object_names, "ExternalObject")
    for source in source_objects:
        xml_text = read_text(source.path)
        for match in ATTCUSTOMTYPE_PROPERTY_RE.finditer(xml_text):
            custom_type = normalize_custom_type(match.group("value"))
            if not custom_type:
                continue
            resolved = resolve_custom_type_target(
                custom_type,
                sdt_lookup,
                domain_lookup,
                external_object_lookup,
            )
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


def extract_attribute_formula_call_evidence(
    source_objects: Iterable[ObjectInfo],
    procedure_names: set[str],
    webpanel_names: set[str],
    data_provider_names: set[str],
) -> list[Evidence]:
    evidences: list[Evidence] = []
    procedure_lookup = case_insensitive_lookup(procedure_names, "Procedure")
    webpanel_lookup = case_insensitive_lookup(webpanel_names, "WebPanel")
    data_provider_lookup = case_insensitive_lookup(data_provider_names, "DataProvider")
    procedure_direct_re = direct_call_pattern(procedure_names)
    data_provider_direct_re = direct_call_pattern(data_provider_names)
    for source in source_objects:
        xml_text = read_text(source.path)
        for match in FORMULA_PROPERTY_RE.finditer(xml_text):
            raw_value = match.group("value")
            expression = html.unescape(raw_value).strip()
            if not expression:
                continue
            append_call_evidences_from_expression(
                evidences,
                source=source,
                xml_text=xml_text,
                expression=expression,
                expression_start=match.start("value"),
                evidence_role="Property Formula",
                procedure_lookup=procedure_lookup,
                webpanel_lookup=webpanel_lookup,
                data_provider_lookup=data_provider_lookup,
                data_provider_direct_re=data_provider_direct_re,
                procedure_direct_re=procedure_direct_re,
                relation_kind_procedure="formula_calls_procedure",
                relation_kind_webpanel_link="formula_calls_webpanel",
                relation_kind_webpanel_create="formula_creates_webcomponent",
                relation_kind_dataprovider="formula_calls_dataprovider",
                extractor_rule_procedure_direct="attribute_formula_procedure_direct_call",
                extractor_rule_procedure_dot="attribute_formula_procedure_dot_call",
                extractor_rule_procedure_dot_link="attribute_formula_procedure_dot_link",
                extractor_rule_webpanel_link="attribute_formula_webpanel_dot_link",
                extractor_rule_procedure_call_command="attribute_formula_procedure_call_command",
                extractor_rule_webpanel_create="attribute_formula_webpanel_dot_create",
                extractor_rule_dataprovider_direct="attribute_formula_dataprovider_direct_call",
                extractor_rule_procedure_udp_func="attribute_formula_procedure_udp_func",
                extractor_rule_procedure_dot_udp="attribute_formula_procedure_dot_udp",
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


def strip_scss_comments(text: str) -> str:
    """Remove comentarios SCSS/GeneXus (/* */ e //) preservando a contagem de linhas."""
    text = SCSS_BLOCK_COMMENT_RE.sub(lambda m: "\n" * m.group(0).count("\n"), text)
    text = SCSS_LINE_COMMENT_RE.sub("", text)
    return text


def design_system_styles_scss(xml_text: str) -> Iterable[str]:
    """SCSS dos Parts 'Styles' (mesmo type GUID em DesignSystem autoral e aninhado em PackagedModule)."""
    for part_match in PART_RE.finditer(xml_text):
        if part_match.group("type").lower() != DESIGN_SYSTEM_STYLES_PART_GUID:
            continue
        for source_match in SOURCE_RE.finditer(part_match.group("body")):
            scss = unwrap_source_body(source_match.group("body"))
            if scss.strip():
                yield strip_scss_comments(scss)


def collect_legacy_theme_css_classes(theme_class_objects: Iterable[ObjectInfo]) -> list[CssClass]:
    rows: list[CssClass] = []
    seen: set[tuple[str, str]] = set()
    for source in theme_class_objects:
        xml_text = read_text(source.path)
        name_match = NAME_PROPERTY_RE.search(xml_text)
        class_name = html.unescape(name_match.group("value")).strip() if name_match else ""
        if not class_name:
            class_name = source.name
        parent_match = OBJECT_PARENT_ATTR_RE.search(xml_text)
        parent_class = None
        if parent_match:
            candidate = html.unescape(parent_match.group("value")).strip()
            parent_class = candidate or None
        key = (class_name, source.name)
        if key in seen:
            continue
        seen.add(key)
        rows.append(
            CssClass(
                class_name=class_name,
                model="legacy-theme",
                origin="kb-authored",
                defining_object_type="ThemeClass",
                defining_object_name=source.name,
                defining_file=source.rel_path,
                parent_class=parent_class,
                extractor_rule="theme_class_name_property",
            )
        )
    return rows


def collect_design_system_css_classes(
    objects: Iterable[ObjectInfo],
    *,
    defining_object_type: str,
    origin: str,
    extractor_rule: str,
) -> list[CssClass]:
    rows: list[CssClass] = []
    seen: set[tuple[str, str]] = set()
    for source in objects:
        xml_text = read_text(source.path)
        for scss in design_system_styles_scss(xml_text):
            for selector in CSS_SELECTOR_RE.finditer(scss):
                class_name = selector.group("name")
                key = (class_name, source.name)
                if key in seen:
                    continue
                seen.add(key)
                rows.append(
                    CssClass(
                        class_name=class_name,
                        model="design-system",
                        origin=origin,
                        defining_object_type=defining_object_type,
                        defining_object_name=source.name,
                        defining_file=source.rel_path,
                        parent_class=None,
                        extractor_rule=extractor_rule,
                    )
                )
    return rows


def dedup_evidences(evidences: list[Evidence]) -> list[Evidence]:
    unique: dict[tuple[str, str, str, str, int, str, str], Evidence] = {}
    for evidence in evidences:
        key = (
            evidence.source_type,
            evidence.source_name,
            evidence.target_type,
            evidence.target_name,
            evidence.line,
            evidence.extractor_rule,
            evidence.evidence_role,
        )
        unique[key] = evidence
    return list(unique.values())


def extract_css_layout_usage_evidence(usage_objects: Iterable[ObjectInfo]) -> list[Evidence]:
    """Uso estatico de classe no layout: atributo class="..." (uma ou varias classes por espaco)."""
    evidences: list[Evidence] = []
    for source in usage_objects:
        xml_text = read_text(source.path)
        for match in LAYOUT_CLASS_ATTR_RE.finditer(xml_text):
            value = html.unescape(match.group("value"))
            if not value.strip():
                continue
            line_no = line_number_at(xml_text, match.start())
            for token in value.split():
                if not CSS_CLASS_NAME_RE.match(token):
                    continue
                add_evidence(
                    evidences,
                    source=source,
                    target_type="CssClass",
                    target_name=token,
                    relation_kind="uses_css_class",
                    line=line_no,
                    column=1,
                    snippet=match.group(0),
                    extractor_rule="css_layout_class_attribute",
                    evidence_role="css_layout",
                )
    return dedup_evidences(evidences)


def extract_css_event_usage_evidence(usage_objects: Iterable[ObjectInfo]) -> list[Evidence]:
    """Uso por codigo: atribuicao Controle.Class = <expr> em eventos (Source). Cobre as 7 formas da matriz."""
    evidences: list[Evidence] = []
    for source in usage_objects:
        xml_text = read_text(source.path)
        for block in source_blocks(xml_text):
            block_text = strip_scss_comments(block.text)
            for offset, line in enumerate(block_text.splitlines()):
                if not line.strip():
                    continue
                line_no = block.start_line + offset
                for match in DOT_CLASS_ASSIGN_RE.finditer(line):
                    rhs = match.group("rhs").strip()
                    resolvable: set[str] = set()
                    for literal in CSS_QUOTED_LITERAL_RE.finditer(rhs):
                        for token in literal.group("value").split():
                            if CSS_CLASS_NAME_RE.match(token):
                                resolvable.add(token)
                    for prefix_match in CSS_PREFIX_CLASS_RE.finditer(rhs):
                        resolvable.add(prefix_match.group("name"))
                    for class_name in sorted(resolvable):
                        add_evidence(
                            evidences,
                            source=source,
                            target_type="CssClass",
                            target_name=class_name,
                            relation_kind="uses_css_class",
                            line=line_no,
                            column=match.start("rhs") + 1,
                            snippet=line,
                            extractor_rule="css_event_class_assignment",
                            evidence_role="css_event",
                        )
                    is_dynamic = bool(CSS_DYNAMIC_HINT_RE.search(rhs)) or not resolvable
                    if is_dynamic:
                        add_evidence(
                            evidences,
                            source=source,
                            target_type="CssClass",
                            target_name=compact_snippet(rhs, 120),
                            relation_kind="uses_css_class_dynamic",
                            line=line_no,
                            column=match.start("rhs") + 1,
                            snippet=line,
                            extractor_rule="css_event_class_dynamic",
                            evidence_role="css_dynamic",
                        )
    return dedup_evidences(evidences)


def create_schema(conn: sqlite3.Connection) -> None:
    conn.executescript(
        """
        DROP TABLE IF EXISTS css_class;
        DROP TABLE IF EXISTS transaction_attribute_writability;
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
            guid TEXT,
            file_path TEXT NOT NULL,
            last_update TEXT,
            file_hash TEXT NOT NULL,
            is_generated_object INTEGER NOT NULL DEFAULT 0,
            pattern_object_id TEXT,
            instance_key TEXT,
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
        CREATE INDEX idx_objects_is_generated ON objects(is_generated_object);
        CREATE INDEX idx_relations_target ON relations(target_type, target_name);
        CREATE INDEX idx_relations_source ON relations(source_object_id);

        CREATE TABLE transaction_attribute_writability (
            writability_id INTEGER PRIMARY KEY AUTOINCREMENT,
            transaction_object_id INTEGER NOT NULL,
            transaction_name TEXT NOT NULL,
            level_name TEXT NOT NULL,
            attribute_name TEXT NOT NULL,
            key_in_level INTEGER NOT NULL,
            is_redundant INTEGER NOT NULL,
            classification TEXT NOT NULL,
            writable INTEGER,
            can_assign_in_new INTEGER,
            reason TEXT NOT NULL,
            evidence TEXT NOT NULL,
            writability_rule_version TEXT NOT NULL,
            FOREIGN KEY(transaction_object_id) REFERENCES objects(object_id)
        );

        CREATE INDEX idx_writability_transaction ON transaction_attribute_writability(transaction_name);
        CREATE INDEX idx_writability_transaction_object ON transaction_attribute_writability(transaction_object_id);
        CREATE INDEX idx_writability_attribute ON transaction_attribute_writability(attribute_name);

        CREATE TABLE css_class (
            css_class_id INTEGER PRIMARY KEY AUTOINCREMENT,
            class_name TEXT NOT NULL,
            model TEXT NOT NULL,
            origin TEXT NOT NULL,
            defining_object_type TEXT,
            defining_object_name TEXT,
            defining_file TEXT,
            parent_class TEXT,
            extractor_rule TEXT NOT NULL,
            UNIQUE(model, class_name, defining_object_name)
        );

        CREATE INDEX idx_css_class_name ON css_class(class_name);
        CREATE INDEX idx_css_class_model ON css_class(model);
        CREATE INDEX idx_css_class_origin ON css_class(origin);
        """
    )


def resolve_transaction_object_id(
    object_ids: dict[tuple[str, str], int],
    transaction_objects: dict[str, ObjectInfo],
    transaction_name: str,
) -> int | None:
    direct = object_ids.get(("Transaction", transaction_name))
    if direct is not None:
        return direct
    for obj in transaction_objects.values():
        if obj.name.lower() == transaction_name.lower():
            return object_ids.get(("Transaction", obj.name))
    return None


def insert_corpus_writability(
    conn: sqlite3.Connection,
    source_root: Path,
    object_ids: dict[tuple[str, str], int],
    transaction_objects: dict[str, ObjectInfo],
) -> int:
    transaction_type_guid = get_transaction_type_guid(GX_TYPE_CATALOG_BY_NAME)
    writability_rows = build_corpus_writability(source_root, transaction_type_guid)
    inserted = 0
    for row in writability_rows:
        transaction_object_id = resolve_transaction_object_id(
            object_ids,
            transaction_objects,
            row.transaction_name,
        )
        if transaction_object_id is None:
            continue
        writable_value: int | None
        if row.writable is None:
            writable_value = None
        else:
            writable_value = 1 if row.writable else 0
        can_assign_value: int | None
        if row.can_assign_in_new is None:
            can_assign_value = None
        else:
            can_assign_value = 1 if row.can_assign_in_new else 0
        conn.execute(
            """
            INSERT INTO transaction_attribute_writability(
                transaction_object_id,
                transaction_name,
                level_name,
                attribute_name,
                key_in_level,
                is_redundant,
                classification,
                writable,
                can_assign_in_new,
                reason,
                evidence,
                writability_rule_version
            )
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            """,
            (
                transaction_object_id,
                row.transaction_name,
                row.level_name,
                row.attribute_name,
                1 if row.key else 0,
                1 if row.is_redundant else 0,
                row.classification,
                writable_value,
                can_assign_value,
                row.reason,
                row.evidence,
                WRITABILITY_RULE_VERSION,
            ),
        )
        inserted += 1
    return inserted


def write_index(
    output_path: Path,
    source_root: Path,
    objects: list[ObjectInfo],
    evidences: list[Evidence],
    css_classes: list[CssClass],
    index_build_run_at: str,
    inventory_semantics: dict[str, object],
) -> None:
    output_path.parent.mkdir(parents=True, exist_ok=True)
    if output_path.exists():
        output_path.unlink()

    extractor_signature_hash = compute_extractor_signature_hash()

    conn = sqlite3.connect(output_path)
    try:
        create_schema(conn)
        conn.executemany(
            "INSERT INTO metadata(key, value) VALUES (?, ?)",
            [
                ("last_index_build_run_at", index_build_run_at),
                ("source_root", str(source_root)),
                ("schema_version", "4"),
                ("writability_rule_version", WRITABILITY_RULE_VERSION),
                ("extractor_signature_version", EXTRACTOR_SIGNATURE_VERSION),
                ("extractor_signature_hash", extractor_signature_hash),
                ("scope", ",".join(sorted(set(obj.object_type for obj in objects)))),
                ("inventory_catalog_version", str(inventory_semantics["catalog_version"])),
                ("inventory_validation_status", str(inventory_semantics["status"])),
                ("inventory_mismatch_count", str(inventory_semantics["mismatch_count"])),
                ("generated_objects_count", str(sum(1 for obj in objects if obj.is_generated_object))),
            ],
        )

        for obj in objects:
            conn.execute(
                """
                INSERT INTO objects(type, name, guid, file_path, last_update, file_hash, is_generated_object, pattern_object_id, instance_key)
                VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
                """,
                (
                    obj.object_type,
                    obj.name,
                    obj.guid,
                    obj.rel_path,
                    obj.last_update,
                    obj.file_hash,
                    obj.is_generated_object,
                    obj.pattern_object_id,
                    obj.instance_key,
                ),
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

        transaction_objects = {
            obj.name: obj for obj in objects if obj.object_type == "Transaction"
        }
        writability_written = insert_corpus_writability(
            conn,
            source_root.resolve(),
            object_ids,
            transaction_objects,
        )
        conn.execute(
            "INSERT INTO metadata(key, value) VALUES (?, ?)",
            ("writability_rows_written", str(writability_written)),
        )

        css_classes_written = 0
        for css in css_classes:
            cursor = conn.execute(
                """
                INSERT OR IGNORE INTO css_class(
                    class_name, model, origin, defining_object_type,
                    defining_object_name, defining_file, parent_class, extractor_rule
                )
                VALUES (?, ?, ?, ?, ?, ?, ?, ?)
                """,
                (
                    css.class_name,
                    css.model,
                    css.origin,
                    css.defining_object_type,
                    css.defining_object_name,
                    css.defining_file,
                    css.parent_class,
                    css.extractor_rule,
                ),
            )
            css_classes_written += cursor.rowcount if cursor.rowcount and cursor.rowcount > 0 else 0
        conn.execute(
            "INSERT INTO metadata(key, value) VALUES (?, ?)",
            ("css_class_rows_written", str(css_classes_written)),
        )

        conn.commit()
    finally:
        conn.close()


def validation_report(
    source_root: Path,
    objects_by_type: dict[str, dict[str, ObjectInfo]],
    evidences: list[Evidence],
    css_classes: list[CssClass],
    validation_cases_path: Path | None,
    index_build_run_at: str,
    inventory_semantics: dict[str, object],
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

    def object_info_exists(object_type: str, object_name: str) -> ObjectInfo | None:
        return objects_by_type.get(object_type, {}).get(object_name)

    def count_impact_relations(object_type: str, object_name: str) -> tuple[int, int]:
        incoming = 0
        outgoing = 0
        for evidence in evidences:
            if evidence.source_type == object_type and evidence.source_name == object_name:
                outgoing += 1
            if evidence.target_type == object_type and evidence.target_name == object_name:
                incoming += 1
        return incoming, outgoing

    cases: list[dict[str, object]] = []
    if validation_cases_path:
        raw_cases = json.loads(validation_cases_path.read_text(encoding="utf-8"))
        for raw_case in raw_cases.get("cases", []):
            case_result = dict(raw_case)
            query = str(raw_case.get("query", ""))
            failures: list[str] = []
            if query == "object-info":
                object_type, object_name = split_typed_name(raw_case["object"])
                should_exist = bool(raw_case.get("should_exist", True))
                info = object_info_exists(object_type, object_name)
                if bool(info is not None) != should_exist:
                    failures.append(f"found={info is not None} expected {should_exist}")
                if should_exist and info is not None:
                    expected_file_contains = raw_case.get("expected_file_contains")
                    if expected_file_contains and expected_file_contains not in str(info.file_path):
                        failures.append(f"file_path={info.file_path} does not contain {expected_file_contains}")
            elif query == "impact-basic":
                object_type, object_name = split_typed_name(raw_case["object"])
                should_exist = bool(raw_case.get("should_exist", True))
                info = object_info_exists(object_type, object_name)
                if bool(info is not None) != should_exist:
                    failures.append(f"found={info is not None} expected {should_exist}")
                if should_exist and info is not None:
                    incoming, outgoing = count_impact_relations(object_type, object_name)
                    min_incoming = int(raw_case.get("min_incoming_relations", 0))
                    min_outgoing = int(raw_case.get("min_outgoing_relations", 0))
                    if incoming < min_incoming:
                        failures.append(f"incoming_relations={incoming} below minimum {min_incoming}")
                    if outgoing < min_outgoing:
                        failures.append(f"outgoing_relations={outgoing} below minimum {min_outgoing}")
            elif {"source", "target", "expected_rule"} <= set(raw_case):
                source_type, source_name = split_typed_name(raw_case["source"])
                target_type, target_name = split_typed_name(raw_case["target"])
                expected_rule = raw_case["expected_rule"]
                should_exist = bool(raw_case.get("should_exist", True))
                relation_exists = has_relation(source_type, source_name, target_type, target_name, expected_rule)
                if (relation_exists if should_exist else not relation_exists) is False:
                    failures.append(
                        f"relation {source_type}:{source_name} -> {target_type}:{target_name} via {expected_rule} "
                        f"expected {should_exist} but got {relation_exists}"
                    )
            else:
                failures.append(f"Unsupported validation case format: {query or 'relation'}")

            case_result["status"] = "failed" if failures else "passed"
            if failures:
                case_result["failures"] = failures
            cases.append(case_result)

    css_classes_by_model: dict[str, int] = {}
    for css in css_classes:
        bucket = f"{css.model}/{css.origin}"
        css_classes_by_model[bucket] = css_classes_by_model.get(bucket, 0) + 1

    return {
        "last_index_build_run_at": index_build_run_at,
        "source_root": str(source_root),
        "objects_read_by_type": {key: len(value) for key, value in objects_by_type.items()},
        "objects_written": sum(len(value) for value in objects_by_type.values()),
        "relations_written": len(evidences),
        "css_classes_written": len(css_classes),
        "css_classes_by_model": dict(sorted(css_classes_by_model.items())),
        "inventory_semantics": inventory_semantics,
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
    parser.add_argument(
        "--parallel-kb-root",
        type=Path,
        help="Raiz da pasta paralela da KB; usada para resolver scripts/gx-object-type-catalog.override.json.",
    )
    parser.add_argument(
        "--catalog-override-path",
        type=Path,
        help="Caminho explicito do override local; prevalece sobre a deteccao automatica pela pasta paralela.",
    )
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    source_root = args.source_root.resolve()
    if not source_root.exists():
        raise SystemExit(f"SourceRoot not found: {source_root}")

    try:
        activate_object_type_catalog(
            source_root,
            parallel_kb_root=args.parallel_kb_root.resolve() if args.parallel_kb_root else None,
            catalog_override_path=args.catalog_override_path.resolve() if args.catalog_override_path else None,
        )
    except CatalogOverrideDiagnosticError as exc:
        print(json.dumps(build_catalog_override_blocked_result(exc), indent=2, ensure_ascii=False))
        return 2

    objects_by_type, scan_summary = collect_all_objects(source_root)
    inventory_semantics = validate_inventory_semantics(objects_by_type, scan_summary)
    procedures = objects_by_type.get("Procedure", {})
    webpanels = objects_by_type.get("WebPanel", {})
    data_providers = objects_by_type.get("DataProvider", {})
    apis = objects_by_type.get("API", {})
    data_selectors = objects_by_type.get("DataSelector", {})
    domains = objects_by_type.get("Domain", {})
    sdts = objects_by_type.get("SDT", {})
    workwith_objects = [
        *objects_by_type.get("WorkWith", {}).values(),
        *objects_by_type.get("WorkWithForWeb", {}).values(),
    ]
    transactions = objects_by_type.get("Transaction", {})
    attributes = objects_by_type.get("Attribute", {})
    tables = objects_by_type.get("Table", {})
    external_objects = objects_by_type.get("ExternalObject", {})
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
    source_bc_load_transaction_evidences = extract_source_bc_load_transaction_evidence(
        [obj for obj in objects if obj.object_type in BC_LOAD_SOURCE_TYPES],
        transaction_names=set(transactions),
    )
    source_bc_save_transaction_evidences = extract_source_bc_save_transaction_evidence(
        [obj for obj in objects if obj.object_type in BC_LOAD_SOURCE_TYPES],
        transaction_names=set(transactions),
    )
    source_bc_delete_transaction_evidences = extract_source_bc_delete_transaction_evidence(
        [obj for obj in objects if obj.object_type in BC_LOAD_SOURCE_TYPES],
        transaction_names=set(transactions),
    )
    source_bc_check_transaction_evidences = extract_source_bc_check_transaction_evidence(
        [obj for obj in objects if obj.object_type in BC_LOAD_SOURCE_TYPES],
        transaction_names=set(transactions),
    )
    source_simple_bc_insert_update_transaction_evidences = (
        extract_source_simple_bc_insert_update_transaction_evidence(
            [obj for obj in objects if obj.object_type in BC_LOAD_SOURCE_TYPES],
            transaction_names=set(transactions),
        )
    )
    source_external_object_method_evidences = extract_source_external_object_method_evidence(
        [obj for obj in objects if obj.object_type in INDEXED_SOURCE_TYPES],
        external_object_names=set(external_objects),
    )
    workwith_evidences = extract_workwith_action_evidence(
        workwith_objects,
        procedure_names=set(procedures),
        webpanel_names=set(webpanels),
    )
    workwith_condition_evidences = extract_workwith_condition_evidence(
        workwith_objects,
        procedure_names=set(procedures),
    )
    workwith_condition_attribute_evidences = extract_workwith_condition_attribute_evidence(
        workwith_objects,
        procedure_names=set(procedures),
    )
    workwith_transaction_evidences = extract_workwith_transaction_evidence(
        workwith_objects,
        transaction_names=set(transactions),
    )
    workwith_webpanel_link_evidences = extract_workwith_webpanel_link_evidence(
        workwith_objects,
        webpanel_names=set(webpanels),
    )
    workwith_prompt_evidences = extract_workwith_prompt_evidence(
        workwith_objects,
        webpanel_names=set(webpanels),
    )
    relation_scope_objects = [
        *procedures.values(),
        *webpanels.values(),
        *data_providers.values(),
        *apis.values(),
        *data_selectors.values(),
        *domains.values(),
        *sdts.values(),
        *workwith_objects,
        *transactions.values(),
    ]
    custom_type_evidences = extract_attcustomtype_evidence(relation_scope_objects)
    resolved_custom_type_evidences = extract_attcustomtype_resolved_evidence(
        relation_scope_objects,
        sdt_names=set(objects_by_type.get("SDT", {})),
        domain_names=set(objects_by_type.get("Domain", {})),
        external_object_names=set(external_objects),
    )
    sdt_item_attcustomtype_resolved_sdt_evidences = extract_sdt_item_attcustomtype_resolved_sdt_evidence(
        objects_by_type.get("SDT", {}).values(),
        sdt_names=set(objects_by_type.get("SDT", {})),
    )
    attribute_idbasedon_domain_evidences = extract_attribute_idbasedon_domain_evidence(
        attributes.values(),
        domain_names=set(objects_by_type.get("Domain", {})),
    )
    attribute_formula_call_evidences = extract_attribute_formula_call_evidence(
        attributes.values(),
        procedure_names=set(procedures),
        webpanel_names=set(webpanels),
        data_provider_names=set(data_providers),
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
    css_classes = (
        collect_legacy_theme_css_classes(objects_by_type.get("ThemeClass", {}).values())
        + collect_design_system_css_classes(
            objects_by_type.get("DesignSystem", {}).values(),
            defining_object_type="DesignSystem",
            origin="kb-authored",
            extractor_rule="design_system_scss_selector",
        )
        + collect_design_system_css_classes(
            objects_by_type.get("PackagedModule", {}).values(),
            defining_object_type="PackagedModule",
            origin="packaged-module",
            extractor_rule="packaged_module_scss_selector",
        )
    )
    css_usage_objects = [obj for obj in objects if obj.object_type in CSS_USAGE_SOURCE_TYPES]
    css_layout_usage_evidences = extract_css_layout_usage_evidence(css_usage_objects)
    css_event_usage_evidences = extract_css_event_usage_evidence(css_usage_objects)
    evidences = [
        *source_evidences,
        *source_for_each_explicit_table_evidences,
        *source_for_each_qualified_table_prefix_evidences,
        *source_bc_load_transaction_evidences,
        *source_bc_save_transaction_evidences,
        *source_bc_delete_transaction_evidences,
        *source_bc_check_transaction_evidences,
        *source_simple_bc_insert_update_transaction_evidences,
        *source_external_object_method_evidences,
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
        *attribute_formula_call_evidences,
        *transaction_level_attribute_evidences,
        *transaction_level_table_evidences,
        *table_key_attribute_evidences,
        *table_index_member_attribute_evidences,
        *css_layout_usage_evidences,
        *css_event_usage_evidences,
    ]
    index_build_run_at = datetime.now(timezone.utc).isoformat()
    write_index(
        args.output_path.resolve(),
        source_root,
        objects,
        evidences,
        css_classes,
        index_build_run_at,
        inventory_semantics,
    )

    validation_cases_path = args.validation_cases_path.resolve() if args.validation_cases_path else None
    if validation_cases_path and not validation_cases_path.exists():
        raise SystemExit(f"ValidationCasesPath not found: {validation_cases_path}")

    report = validation_report(
        source_root,
        objects_by_type,
        evidences,
        css_classes,
        validation_cases_path,
        index_build_run_at,
        inventory_semantics,
    )
    if args.validation_report_path:
        report_path = args.validation_report_path.resolve()
        report_path.parent.mkdir(parents=True, exist_ok=True)
        report_path.write_text(json.dumps(report, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")

    print(json.dumps(report, indent=2, ensure_ascii=False))
    if args.fail_on_validation_failure:
        failed_cases = [case for case in report["cases"] if case.get("status") == "failed"]
        if failed_cases or inventory_semantics["status"] != "OK":
            return 2
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
