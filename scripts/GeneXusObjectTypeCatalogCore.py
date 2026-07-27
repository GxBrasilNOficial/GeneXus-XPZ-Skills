#!/usr/bin/env python3
"""Shared GeneXus object type catalog load/merge (base + optional parallel-KB override)."""

from __future__ import annotations

import json
from collections import Counter
from pathlib import Path
from typing import Any

CATEGORY_PATH = Path(__file__).with_name("gx-object-type-catalog.json")
DEFAULT_OVERRIDE_RELATIVE = Path("scripts") / "gx-object-type-catalog.override.json"
OPERATIONAL_FIELDS = (
    "objectTypeGuid",
    "rootKind",
    "folderName",
    "inventoryEligible",
    "queryableByKbIntelligence",
    "containerType",
    "exportTaskLabel",
)
REQUIRED_WITHOUT_BASE = OPERATIONAL_FIELDS[:-1]
METADATA_FIELDS = {"evidenceSummary", "wikiLinks", "nexaFindings", "notes", "lastObservedAt"}
SUPPORTED_FIELDS = set(OPERATIONAL_FIELDS) | METADATA_FIELDS


class CatalogOverrideDiagnosticError(RuntimeError):
    """Typed catalog override failure with structured diagnostics."""

    def __init__(self, diagnostic: dict[str, Any]):
        super().__init__(diagnostic.get("message") or diagnostic.get("reason") or "catalog override diagnostic")
        self.diagnostic = diagnostic


def _loads_json_with_duplicate_check(path: Path, source_label: str) -> dict[str, Any]:
    def hook(pairs: list[tuple[str, Any]]) -> dict[str, Any]:
        names = [name for name, _value in pairs]
        duplicated = [name for name, count in Counter(names).items() if count > 1]
        if duplicated:
            raise CatalogOverrideDiagnosticError(
                {
                    "status": "INVALID_OVERRIDE_SHAPE",
                    "reason": "invalid-override-shape",
                    "diagnosticReason": "duplicate-json-key",
                    "fieldPath": source_label,
                    "message": f"Chave JSON duplicada em {source_label}: {duplicated[0]}",
                    "overridePath": str(path),
                    "effectiveCatalogAction": "block-resolution",
                }
            )
        return dict(pairs)

    try:
        return json.loads(path.read_text(encoding="utf-8-sig"), object_pairs_hook=hook)
    except CatalogOverrideDiagnosticError:
        raise
    except FileNotFoundError as exc:
        raise RuntimeError(f"Object type catalog not found: {path}") from exc
    except json.JSONDecodeError as exc:
        raise CatalogOverrideDiagnosticError(
            {
                "status": "INVALID_OVERRIDE_SHAPE",
                "reason": "invalid-override-shape",
                "diagnosticReason": "invalid-json",
                "fieldPath": "$",
                "message": str(exc),
                "overridePath": str(path),
                "effectiveCatalogAction": "block-resolution",
            }
        ) from exc


def normalize_catalog_types(raw_types: object, source_label: str) -> dict[str, dict[str, object]]:
    if not isinstance(raw_types, dict):
        raise RuntimeError(f"Invalid object type catalog format: {source_label}")
    normalized_types: dict[str, dict[str, object]] = {}
    for canonical_type, payload in raw_types.items():
        if not isinstance(payload, dict):
            raise RuntimeError(f"Invalid entry for type {canonical_type!r} in {source_label}")
        entry = dict(payload)
        entry["canonicalType"] = str(canonical_type)
        normalized_types[str(canonical_type)] = entry
    return normalized_types


def load_gx_object_type_catalog_file(path: Path) -> dict[str, object]:
    catalog = _loads_json_with_duplicate_check(path, str(path))
    return {
        "version": int(catalog.get("version", 0)),
        "types": normalize_catalog_types(catalog.get("types"), str(path)),
        "schemaVersion": catalog.get("schemaVersion"),
    }


def _guid_key(value: object) -> str | None:
    if value is None:
        return None
    text = str(value).strip().lower()
    return text or None


def _field_equivalent(override_entry: dict[str, object], base_entry: dict[str, object], field: str) -> bool:
    if field not in override_entry:
        return True
    if field not in base_entry:
        return False
    if field in {"inventoryEligible", "queryableByKbIntelligence", "containerType"}:
        return bool(override_entry[field]) == bool(base_entry[field])
    return str(override_entry[field]).casefold() == str(base_entry[field]).casefold()


def classify_gx_object_type_catalog_override(base: dict[str, object], override: dict[str, object] | None, override_path: Path | None) -> dict[str, object]:
    if override is None:
        return {"status": "OK", "overrideActive": False, "effectiveCatalogAction": "none", "classificationEntries": [], "effectiveUpstreamPending": False, "declaredUpstreamPending": False}
    if not isinstance(override, dict):
        return _invalid("root-not-object", "$", override_path)
    declared = override.get("upstreamPending", False)
    if not isinstance(declared, bool):
        return _invalid("upstream-pending-not-boolean", "upstreamPending", override_path)
    if "types" not in override:
        return _cleanup([], declared, override_path, "metadata-only")
    if not isinstance(override.get("types"), dict):
        return _invalid("types-not-object", "types", override_path, declared)

    base_types = base["types"]  # type: ignore[index]
    base_by_name = {name.casefold(): (name, entry) for name, entry in base_types.items()}  # type: ignore[union-attr]
    base_guid_to_name = {_guid_key(entry.get("objectTypeGuid")): name for name, entry in base_types.items() if _guid_key(entry.get("objectTypeGuid"))}  # type: ignore[union-attr]
    type_names = list(override["types"].keys())
    folded = [name.casefold() for name in type_names]
    if len(folded) != len(set(folded)):
        return _invalid("duplicate-type-name-casefold", "types", override_path, declared)
    guid_seen: dict[str, str] = {}
    for name, entry in override["types"].items():
        if isinstance(entry, dict) and _guid_key(entry.get("objectTypeGuid")):
            guid = _guid_key(entry.get("objectTypeGuid"))
            assert guid is not None
            if guid in guid_seen and guid_seen[guid].casefold() != name.casefold():
                blocked = _entry(name, entry, "divergent", "unsafe-duplicate-guid", "duplicate-guid-in-override", f"types.{name}.objectTypeGuid", action="block-resolution")
                return _blocked([blocked], declared, override_path, "unsafe-duplicate-guid", "duplicate-guid-in-override")
            guid_seen[guid] = name

    entries: list[dict[str, object]] = []
    for name, entry_obj in override["types"].items():
        if not isinstance(entry_obj, dict):
            entries.append(_entry(name, {}, "divergent", "invalid-override-shape", "entry-not-object", f"types.{name}", action="block-resolution")); continue
        entry = dict(entry_obj)
        unsupported = sorted(set(entry) - SUPPORTED_FIELDS)
        ignored = sorted(set(entry) & METADATA_FIELDS)
        base_match = base_by_name.get(name.casefold())
        guid = _guid_key(entry.get("objectTypeGuid"))
        base_by_guid = base_guid_to_name.get(guid) if guid else None
        if base_match is None and base_by_guid:
            base_match = base_by_name[base_by_guid.casefold()]
        if base_match is None:
            missing = [field for field in REQUIRED_WITHOUT_BASE if field not in entry]
            if missing:
                entries.append(_entry(name, entry, "divergent", "invalid-operational-field", "required-field-missing", f"types.{name}.{missing[0]}", ignored=ignored, unsupported=unsupported, action="block-resolution")); continue
        if base_by_guid and base_match and base_by_guid.casefold() != base_match[0].casefold():
            base_name, base_entry = base_by_name[base_by_guid.casefold()]
            entries.append(_entry(name, entry, "divergent", "unsafe-duplicate-guid", "guid-collides-with-other-base-type", f"types.{name}.objectTypeGuid", base_name, base_entry, ignored=ignored, unsupported=unsupported, action="block-resolution")); continue
        if base_match:
            base_name, base_entry = base_match
            if not _guid_key(base_entry.get("objectTypeGuid")) and guid:
                entries.append(_entry(name, entry, "divergent", "unsafe-shadowing", "unsafe-shadowing-base-type-without-guid", f"types.{name}.objectTypeGuid", base_name, base_entry, ignored=ignored, unsupported=unsupported, action="block-resolution")); continue
            divergent = [field for field in OPERATIONAL_FIELDS if not _field_equivalent(entry, base_entry, field)]
            if divergent:
                entries.append(_entry(name, entry, "divergent", "field-divergence", "field-divergence", f"types.{name}", base_name, base_entry, divergent, ignored, unsupported, "merge-with-warning"))
            else:
                entries.append(_entry(name, entry, "redundant", "equivalent", "equivalent", f"types.{name}", base_name, base_entry, ignored=ignored, unsupported=unsupported, action="merge"))
        else:
            entries.append(_entry(name, entry, "pending", "missing-in-base", "missing-in-base", f"types.{name}", ignored=ignored, unsupported=unsupported, action="merge-with-warning"))
    blocked = [entry for entry in entries if entry["effectiveCatalogAction"] == "block-resolution"]
    if blocked:
        first = blocked[0]
        status = "INVALID_OVERRIDE_SHAPE" if first["reason"] in {"invalid-override-shape", "invalid-operational-field"} else "OVERRIDE_RESOLUTION_BLOCKED"
        return _result(status, entries, declared, override_path, first["reason"], first["diagnosticReason"], first["fieldPath"], "block-resolution")
    if any(entry["classification"] in {"pending", "divergent"} for entry in entries):
        return _result("REMINDER_REQUIRED", entries, declared, override_path, "missing-in-base", "missing-in-base", None, "merge-with-warning")
    return _cleanup(entries, declared, override_path, "equivalent")


def _entry(name: str, entry: dict[str, object], classification: str, reason: str, diagnostic: str, field_path: str, base_name: str | None = None, base_entry: dict[str, object] | None = None, divergent: list[str] | None = None, ignored: list[str] | None = None, unsupported: list[str] | None = None, action: str = "merge-with-warning") -> dict[str, object]:
    return {"typeName": name, "objectTypeGuid": entry.get("objectTypeGuid"), "classification": classification, "reason": reason, "diagnosticReason": diagnostic, "fieldPath": field_path, "baseTypeName": base_name, "baseObjectTypeGuid": (base_entry or {}).get("objectTypeGuid"), "divergentFields": divergent or [], "ignoredFields": ignored or [], "unsupportedFields": unsupported or [], "removalRecommended": classification == "redundant", "effectiveCatalogAction": action}


def _invalid(diagnostic: str, field_path: str, path: Path | None, declared: bool = True) -> dict[str, object]:
    return _result("INVALID_OVERRIDE_SHAPE", [], declared, path, "invalid-override-shape", diagnostic, field_path, "block-resolution")


def _blocked(entries: list[dict[str, object]], declared: bool, path: Path | None, reason: str, diagnostic: str) -> dict[str, object]:
    return _result("OVERRIDE_RESOLUTION_BLOCKED", entries, declared, path, reason, diagnostic, None, "block-resolution")


def _cleanup(entries: list[dict[str, object]], declared: bool, path: Path | None, reason: str) -> dict[str, object]:
    return _result("CLEANUP_RECOMMENDED", entries, declared, path, reason, reason if reason == "equivalent" else None, None, "merge" if entries else "none")


def _result(status: str, entries: list[dict[str, object]], declared: bool, path: Path | None, reason: object, diagnostic: object, field_path: object, action: str) -> dict[str, object]:
    pending = [e for e in entries if e["classification"] == "pending"]
    redundant = [e for e in entries if e["classification"] == "redundant"]
    divergent = [e for e in entries if e["classification"] == "divergent"]
    blocked = [e for e in entries if e["effectiveCatalogAction"] == "block-resolution"]
    effective = status in {"REMINDER_REQUIRED", "INVALID_OVERRIDE_SHAPE", "OVERRIDE_RESOLUTION_BLOCKED"}
    return {"status": status, "overrideActive": True, "overridePath": str(path) if path else None, "reason": reason, "diagnosticReason": diagnostic, "fieldPath": field_path, "message": "catalog override diagnostic", "blocked": status in {"INVALID_OVERRIDE_SHAPE", "OVERRIDE_RESOLUTION_BLOCKED"}, "classificationEntries": entries, "declaredUpstreamPending": declared, "effectiveUpstreamPending": effective, "upstreamPending": effective, "cleanupRecommended": status == "CLEANUP_RECOMMENDED", "noticeRequired": status != "OK", "reminderRequired": status == "REMINDER_REQUIRED", "pendingTypeNames": sorted(e["typeName"] for e in pending), "pendingTypeGuids": [e.get("objectTypeGuid") for e in pending if e.get("objectTypeGuid")], "redundantTypeNames": sorted(e["typeName"] for e in redundant), "redundantTypeGuids": [e.get("objectTypeGuid") for e in redundant if e.get("objectTypeGuid")], "divergentTypeNames": sorted(e["typeName"] for e in divergent), "divergentTypeGuids": [e.get("objectTypeGuid") for e in divergent if e.get("objectTypeGuid")], "blockedTypeNames": sorted(e["typeName"] for e in blocked), "blockedTypeGuids": [e.get("objectTypeGuid") for e in blocked if e.get("objectTypeGuid")], "effectiveCatalogAction": action}


def merge_gx_object_type_catalogs(base: dict[str, object], override: dict[str, object] | None, classification: dict[str, object] | None = None) -> dict[str, object]:
    merged_types = {name: dict(entry) for name, entry in base["types"].items()}  # type: ignore[union-attr]
    for name, entry in merged_types.items():
        entry["canonicalType"] = name
    if override is not None and override.get("types"):
        entries = {entry["typeName"]: entry for entry in (classification or {}).get("classificationEntries", [])}
        for name, payload in override["types"].items():  # type: ignore[index]
            if not isinstance(payload, dict):
                continue
            diag = entries.get(name, {})
            if diag.get("effectiveCatalogAction") == "block-resolution":
                continue
            target = diag.get("baseTypeName") or name
            merged = dict(merged_types.get(target, {}))
            for key, value in payload.items():
                if key in SUPPORTED_FIELDS:
                    merged[key] = value
            merged["canonicalType"] = target
            merged_types[str(target)] = merged
    return {"version": int(base.get("version", 0)), "types": merged_types}


def resolve_parallel_kb_root(source_root: Path, parallel_kb_root: Path | None) -> Path | None:
    if parallel_kb_root is not None:
        return parallel_kb_root.resolve()
    if source_root.name.casefold() == "objetosdakbemxml":
        return source_root.parent.resolve()
    return None


def resolve_parallel_kb_root_from_index_path(index_path: Path, parallel_kb_root: Path | None) -> Path | None:
    if parallel_kb_root is not None:
        return parallel_kb_root.resolve()
    parent = index_path.parent.resolve()
    if parent.name.casefold() == "kbintelligence":
        return parent.parent.resolve()
    return None


def resolve_catalog_override_path(parallel_kb_root: Path | None, catalog_override_path: Path | None) -> Path | None:
    if catalog_override_path is not None:
        resolved = catalog_override_path.resolve()
        return resolved if resolved.is_file() else None
    if parallel_kb_root is None:
        return None
    candidate = parallel_kb_root / DEFAULT_OVERRIDE_RELATIVE
    return candidate if candidate.is_file() else None


def build_type_guid_index(types_by_name: dict[str, dict[str, object]]) -> dict[str, str]:
    return {str(entry["objectTypeGuid"]).lower(): canonical_type for canonical_type, entry in types_by_name.items() if entry.get("objectTypeGuid")}


def load_gx_object_type_catalog() -> dict[str, object]:
    return load_gx_object_type_catalog_file(CATEGORY_PATH)


def _load_override(path: Path | None) -> dict[str, object] | None:
    if path is None:
        return None
    return _loads_json_with_duplicate_check(path, "override")


def _resolve_effective(base_path: Path, override_path: Path | None) -> tuple[dict[str, object], Path | None]:
    base_catalog = load_gx_object_type_catalog_file(base_path)
    override_catalog = _load_override(override_path)
    classification = classify_gx_object_type_catalog_override(base_catalog, override_catalog, override_path)
    if classification.get("effectiveCatalogAction") == "block-resolution":
        raise CatalogOverrideDiagnosticError(classification)
    return merge_gx_object_type_catalogs(base_catalog, override_catalog, classification), override_path


def resolve_effective_object_type_catalog(source_root: Path, parallel_kb_root: Path | None = None, catalog_override_path: Path | None = None, base_catalog_path: Path | None = None) -> tuple[dict[str, object], Path | None]:
    base_path = (base_catalog_path or CATEGORY_PATH).resolve()
    resolved_parallel = resolve_parallel_kb_root(source_root, parallel_kb_root)
    override_path = resolve_catalog_override_path(resolved_parallel, catalog_override_path)
    return _resolve_effective(base_path, override_path)


def resolve_effective_object_type_catalog_for_query(index_path: Path, parallel_kb_root: Path | None = None, catalog_override_path: Path | None = None, base_catalog_path: Path | None = None) -> tuple[dict[str, object], Path | None]:
    base_path = (base_catalog_path or CATEGORY_PATH).resolve()
    resolved_parallel = resolve_parallel_kb_root_from_index_path(index_path, parallel_kb_root)
    override_path = resolve_catalog_override_path(resolved_parallel, catalog_override_path)
    return _resolve_effective(base_path, override_path)
