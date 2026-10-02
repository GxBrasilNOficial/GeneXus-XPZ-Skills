#!/usr/bin/env python3
"""Operational New-source extraction and candidate analysis.

Automatic writability remains owned by GeneXusTransactionWritabilityCore.  This
module adds source-occurrence identity and keeps human decisions in a separate
input/output contract.
"""

from __future__ import annotations

import argparse
import copy
import datetime as dt
import hashlib
import json
import re
import shutil
import sys
import tempfile
import uuid
import xml.sax
import xml.etree.ElementTree as ElementTree
from dataclasses import dataclass
from pathlib import Path
from typing import Any

import GeneXusTransactionWritabilityCore as automatic
from GeneXusCanonicalJson import CanonicalJsonError, canonical_bytes, loads_strict


SOURCE_PART_TYPE_GUID = "528d1c06-a9c2-420d-bd35-21dca83f12ff"
PROCEDURE_TYPE_GUID = "84a12160-f59b-4ad7-a683-ea4481ac23e9"
IDENTIFIER_START = re.compile(r"[^\W\d]", re.UNICODE)


class OperationalError(ValueError):
    pass


class DecisionIssue(OperationalError):
    def __init__(self, status: str, reason_code: str, detail: str):
        super().__init__(detail)
        self.status = status
        self.reason_code = reason_code


@dataclass(frozen=True)
class Token:
    kind: str
    value: str
    start: int
    end: int
    line: int


@dataclass(frozen=True)
class Assignment:
    name: str
    start: int
    end: int


@dataclass(frozen=True)
class NewBlock:
    index: int
    start: int
    end: int
    assignments: tuple[Assignment, ...]
    issues: tuple[str, ...]


def _sha256(text: str) -> str:
    return hashlib.sha256(text.encode("utf-8", errors="strict")).hexdigest()


def _identifier_start(char: str) -> bool:
    return char == "_" or bool(IDENTIFIER_START.fullmatch(char))


def _identifier_continue(char: str) -> bool:
    return char == "_" or char.isalnum()


def lex_source(source: str) -> list[Token]:
    """Lex code tokens while ignoring GeneXus strings and documented comments.

    GeneXus 18 documentation confirms double-slash and C-style block comments.
    Quoted strings support doubled quote delimiters.  Backslash escapes before a
    quote are rejected because the official language material does not define
    them consistently; they must not silently alter block boundaries.
    """
    tokens: list[Token] = []
    i = 0
    line = 1
    line_start = 0
    length = len(source)
    while i < length:
        char = source[i]
        if char in "\r\n":
            if char == "\r" and i + 1 < length and source[i + 1] == "\n":
                i += 1
            i += 1
            line += 1
            line_start = i
            continue
        if char.isspace():
            i += 1
            continue
        if source.startswith("//", i):
            end = i + 2
            while end < length and source[end] not in "\r\n":
                end += 1
            i = end
            continue
        if source.startswith("/*", i):
            end = source.find("*/", i + 2)
            if end < 0:
                raise OperationalError("new-extraction-incomplete: unterminated block comment")
            line += source.count("\n", i, end + 2)
            last_lf = source.rfind("\n", i, end + 2)
            if last_lf >= 0:
                line_start = last_lf + 1
            i = end + 2
            continue
        if char in ('"', "'"):
            quote = char
            start = i
            i += 1
            closed = False
            while i < length:
                if source[i] == "\\" and i + 1 < length and source[i + 1] == quote:
                    raise OperationalError("new-extraction-incomplete: unsupported backslash quote escape")
                if source[i] == quote:
                    if i + 1 < length and source[i + 1] == quote:
                        i += 2
                        continue
                    i += 1
                    closed = True
                    break
                if source[i] in "\r\n":
                    if source[i] == "\r" and i + 1 < length and source[i + 1] == "\n":
                        i += 1
                    i += 1
                    line += 1
                    line_start = i
                    continue
                i += 1
            if not closed:
                raise OperationalError(f"new-extraction-incomplete: unterminated string at offset {start}")
            tokens.append(Token("string", source[start:i], start, i, line))
            continue
        if _identifier_start(char):
            start = i
            i += 1
            while i < length and _identifier_continue(source[i]):
                i += 1
            tokens.append(Token("identifier", source[start:i], start, i, line))
            continue
        if char == "&":
            tokens.append(Token("ampersand", char, i, i + 1, line))
            i += 1
            continue
        if char in "=<>!":
            start = i
            i += 1
            if i < length and source[i] in "=<>":
                i += 1
            tokens.append(Token("operator", source[start:i], start, i, line))
            continue
        tokens.append(Token("punctuation", char, i, i + 1, line))
        i += 1
    return tokens


def _is_command_keyword(tokens: list[Token], index: int, keyword: str) -> bool:
    token = tokens[index]
    if token.kind != "identifier" or token.value.casefold() != keyword.casefold():
        return False
    if index > 0 and tokens[index - 1].kind == "ampersand":
        return False
    if index > 0 and tokens[index - 1].value == ".":
        return False
    line_prefix = tokens[index - 1].line if index > 0 else None
    return index == 0 or token.line != line_prefix


def _assignment_on_line(source: str, line_tokens: list[Token]) -> tuple[Assignment | None, str | None]:
    if not line_tokens:
        return None, None
    # Multiple commands separated by semicolons are handled as independent starts.
    segments: list[list[Token]] = [[]]
    for token in line_tokens:
        if token.value == ";":
            segments.append([])
        else:
            segments[-1].append(token)
    found: list[Assignment] = []
    for segment in segments:
        if not segment:
            continue
        if segment[0].kind == "ampersand":
            continue
        if segment[0].kind != "identifier":
            continue
        if len(segment) >= 2 and segment[1].value == ".":
            if len(segment) >= 4 and segment[3].value == "=":
                return None, "new-assignment-qualified-lhs-unsupported"
            continue
        if len(segment) < 2 or segment[1].value != "=":
            continue
        operator = segment[1]
        if operator.value != "=":
            continue
        found.append(Assignment(segment[0].value, segment[0].start, operator.end))
    if len(found) > 1:
        return None, "new-multiple-assignments-on-one-line-unsupported"
    return (found[0], None) if found else (None, None)


def extract_new_blocks(source: str) -> list[NewBlock]:
    tokens = lex_source(source)
    stack: list[Token] = []
    matched: list[tuple[Token, Token]] = []
    for index, token in enumerate(tokens):
        if _is_command_keyword(tokens, index, "New"):
            if stack:
                raise OperationalError("new-extraction-incomplete: nested New blocks are unsupported")
            stack.append(token)
        elif _is_command_keyword(tokens, index, "EndNew"):
            if not stack:
                raise OperationalError(f"new-extraction-incomplete: unmatched EndNew at offset {token.start}")
            matched.append((stack.pop(), token))
    if stack:
        raise OperationalError(f"new-extraction-incomplete: unmatched New at offset {stack[0].start}")

    blocks: list[NewBlock] = []
    for ordinal, (start_token, end_token) in enumerate(matched, start=1):
        body_tokens = [token for token in tokens if start_token.end <= token.start < end_token.start]
        assignments: list[Assignment] = []
        issues: set[str] = set()
        lines: dict[int, list[Token]] = {}
        for token in body_tokens:
            lines.setdefault(token.line, []).append(token)
        for line_tokens in lines.values():
            visible = line_tokens
            if visible and visible[0].kind == "identifier" and visible[0].value.casefold() == "when":
                break
            assignment, issue = _assignment_on_line(source, visible)
            if issue:
                issues.add(issue)
            if assignment is not None:
                assignments.append(assignment)
        blocks.append(NewBlock(ordinal, start_token.start, end_token.end,
                               tuple(assignments), tuple(sorted(issues))))
    return blocks


def _strict_xml(path: Path) -> ElementTree.Element:
    try:
        raw = path.read_bytes()
    except OSError as exc:
        raise OperationalError(f"object file cannot be read: {path}: {exc}") from exc
    try:
        root = automatic._parse_xml_without_doctype(raw)
    except (ElementTree.ParseError, xml.sax.SAXException, ValueError) as exc:
        raise OperationalError(f"object XML is malformed or invalidly encoded: {path}: {exc}") from exc
    return root


def _overlay_model_corpus(corpus_root: Path, delta_root: Path,
                          overlay_root: Path) -> dict[str, str]:
    """Build a disposable XML-only corpus overlay; source roots remain untouched."""
    origins: dict[str, str] = {}
    modeled_folders = ("Attribute", "Table", "Transaction", "SubTypeGroup")
    for folder in modeled_folders:
        source_folder = corpus_root / folder
        target_folder = overlay_root / folder
        if source_folder.is_dir():
            target_folder.mkdir(parents=True, exist_ok=True)
            for source in sorted(source_folder.rglob("*.xml"), key=lambda item: item.relative_to(source_folder).as_posix()):
                try:
                    source.resolve(strict=True).relative_to(corpus_root.resolve(strict=True))
                except (OSError, ValueError) as exc:
                    raise OperationalError(f"corpus model path escapes its root: {source}") from exc
                target = target_folder / source.relative_to(source_folder)
                target.parent.mkdir(parents=True, exist_ok=True)
                shutil.copyfile(source, target)
                origins[(Path(folder) / source.relative_to(source_folder)).as_posix()] = "corpus"

    for folder in modeled_folders:
        delta_folder = delta_root / folder
        if not delta_folder.is_dir():
            continue
        existing_by_guid: dict[str, list[Path]] = {}
        target_folder = overlay_root / folder
        target_folder.mkdir(parents=True, exist_ok=True)
        for existing in target_folder.rglob("*.xml"):
            try:
                node = automatic._parse_xml_without_doctype(existing.read_bytes())
            except (ElementTree.ParseError, xml.sax.SAXException, ValueError, OSError) as exc:
                raise OperationalError(f"overlay base has invalid XML: {existing}: {exc}") from exc
            guid = _xml_guid(next((value for key, value in node.attrib.items() if key.casefold() == "guid"), ""))
            if guid:
                existing_by_guid.setdefault(guid, []).append(existing)
        seen_delta_guids: set[str] = set()
        for source in sorted(delta_folder.rglob("*.xml"), key=lambda item: item.relative_to(delta_root).as_posix()):
            try:
                source.resolve(strict=True).relative_to(delta_root.resolve(strict=True))
            except (OSError, ValueError) as exc:
                raise OperationalError(f"delta model path escapes its root: {source}") from exc
            try:
                node = automatic._parse_xml_without_doctype(source.read_bytes())
            except (ElementTree.ParseError, xml.sax.SAXException, ValueError, OSError) as exc:
                raise OperationalError(f"delta model XML is invalid: {source}: {exc}") from exc
            guid = _xml_guid(next((value for key, value in node.attrib.items() if key.casefold() == "guid"), ""))
            if guid and guid in seen_delta_guids:
                raise OperationalError(f"delta model repeats object GUID {guid}: {folder}")
            if guid:
                seen_delta_guids.add(guid)
            relative_in_folder = source.relative_to(delta_folder)
            path_match = next((item for item in target_folder.rglob("*.xml")
                               if item.relative_to(target_folder).as_posix().casefold()
                               == relative_in_folder.as_posix().casefold()), None)
            guid_matches = existing_by_guid.get(guid, []) if guid else []
            if len(guid_matches) > 1:
                raise OperationalError(f"overlay cannot resolve duplicate base GUID {guid}: {folder}")
            replace_path = guid_matches[0] if guid_matches else path_match
            if replace_path is not None:
                old_rel = replace_path.relative_to(overlay_root).as_posix()
                replace_path.unlink()
                origins.pop(old_rel, None)
            destination = target_folder / relative_in_folder
            destination.parent.mkdir(parents=True, exist_ok=True)
            if destination.exists():
                if replace_path is None or destination != replace_path:
                    raise OperationalError(f"delta path collides with a different base object: {destination}")
                destination.unlink()
            shutil.copyfile(source, destination)
            origins[destination.relative_to(overlay_root).as_posix()] = "delta"
    return origins


def _local(tag: str) -> str:
    return tag.rsplit("}", 1)[-1]


def _xml_guid(value: str) -> str | None:
    return automatic._normalize_guid(value)


def _procedure_source(path: Path) -> tuple[ElementTree.Element, str, str]:
    root = _strict_xml(path)
    if _local(root.tag).casefold() != "object":
        raise OperationalError("procedure XML root must be Object")
    if _xml_guid(root.attrib.get("type", "")) != PROCEDURE_TYPE_GUID:
        raise OperationalError("object is not a GeneXus Procedure")
    guid = _xml_guid(root.attrib.get("guid", ""))
    if not guid:
        raise OperationalError("procedure GUID is missing or invalid")
    parts = [node for node in root.iter() if _local(node.tag).casefold() == "part"
             and _xml_guid(node.attrib.get("type", "")) == SOURCE_PART_TYPE_GUID]
    if len(parts) != 1:
        raise OperationalError(f"procedure Source part count is {len(parts)}; expected exactly one")
    sources = [node for node in parts[0].iter() if _local(node.tag).casefold() == "source"]
    if len(sources) != 1 or list(sources[0]):
        raise OperationalError("procedure Source element is missing, duplicated, or structurally unsupported")
    text = sources[0].text or ""
    return root, guid, text


def _property_name(root: ElementTree.Element) -> str:
    for prop in (node for node in root.iter() if _local(node.tag).casefold() == "property"):
        children = list(prop)
        name = next((child for child in children if _local(child.tag).casefold() == "name"), None)
        value = next((child for child in children if _local(child.tag).casefold() == "value"), None)
        if name is not None and (name.text or "").strip().casefold() == "name" and value is not None:
            return (value.text or "").strip()
    return ""


def _object_ref(root_kind: str, relative_path: str, object_type: str, guid: str | None,
                name: str) -> dict[str, object]:
    return {"type": object_type, "guid": guid, "name": name, "path": relative_path,
            "rootKind": root_kind}


def _row_identity_key(row: Any) -> tuple[object, ...]:
    return (row.transaction_guid, row.part_type, tuple(row.path_ordinals), row.attribute_guid)


def _selection_eligibility(group_views: list[dict[str, object]],
                           assignment_targets: list[dict[str, object]]) -> tuple[bool, list[str]]:
    """A target choice may retain inferential uncertainty, never technical gaps."""
    issues: set[str] = set()
    if not group_views or any(view.get("associationStatus") != "resolved-level-type-and-table-key"
                              for view in group_views):
        issues.add("new-target-table-association-incomplete")
    if not assignment_targets:
        issues.add("new-target-has-no-assignments")
    automatic_positive_codes = {
        "key-attribute": {"key-attribute"},
        "own-physical": {"own-physical"},
        "own-physical-indexed": {"own-physical-indexed"},
        "extended-fk-key": {"extended-fk-key"},
        "extended-subtype-key": {"subtype-key"},
    }
    for target in assignment_targets:
        occurrences = target.get("occurrences")
        if not isinstance(occurrences, list) or not occurrences:
            issues.add("new-target-assignment-occurrence-missing")
            continue
        for occurrence in occurrences:
            context = occurrence.get("contextualAnalysis")
            evaluated = (context if occurrence.get("decisionState") == "applied"
                         and isinstance(context, dict) else occurrence)
            classification = evaluated.get("classification")
            writable = evaluated.get("writable")
            codes = set(evaluated.get("reasonCodes", []))
            coverage = evaluated.get("coverage")
            if classification in automatic_positive_codes:
                if (writable is not True or coverage != "complete-in-model"
                        or codes != automatic_positive_codes[classification]):
                    issues.add("new-target-automatic-fact-inconsistent")
            elif classification == "unclassified-relation-pending":
                if writable is not None or codes != {"inferred-fk-key"}:
                    issues.add("new-target-inferential-candidate-has-technical-cause")
            elif classification == "extended-fk-descriptive":
                if writable is not False or codes != {"inferred-fk-descriptive"} or coverage != "complete-in-model":
                    issues.add("new-target-inferential-candidate-has-technical-cause")
            elif classification == "unclassified-role-conflict":
                if writable is not None or codes != {"heuristic-role-conflict"} or coverage != "complete-in-model":
                    issues.add("new-target-inferential-candidate-has-technical-cause")
            else:
                issues.add("new-target-contains-nonselectable-occurrence")
    return not issues, sorted(issues)


def _type_matches(value: Any, expected: str | list[str]) -> bool:
    choices = [expected] if isinstance(expected, str) else expected
    for choice in choices:
        if choice == "null" and value is None:
            return True
        if choice == "object" and isinstance(value, dict):
            return True
        if choice == "array" and isinstance(value, list):
            return True
        if choice == "string" and isinstance(value, str):
            return True
        if choice == "boolean" and isinstance(value, bool):
            return True
        if choice == "integer" and isinstance(value, int) and not isinstance(value, bool):
            return True
        if choice == "number" and isinstance(value, (int, float)) and not isinstance(value, bool):
            return True
    return False


def _schema_at_pointer(document: dict[str, Any], pointer: str) -> dict[str, Any]:
    value: Any = document
    for part in pointer.removeprefix("#/").split("/"):
        value = value[part.replace("~1", "/").replace("~0", "~")]
    if not isinstance(value, dict):
        raise OperationalError(f"schema reference is not an object: {pointer}")
    return value


def _validate_schema_value(value: Any, schema: dict[str, Any], document: dict[str, Any], path: str = "$") -> None:
    if "$ref" in schema:
        _validate_schema_value(value, _schema_at_pointer(document, str(schema["$ref"])), document, path)
    if "type" in schema and not _type_matches(value, schema["type"]):
        raise OperationalError(f"manifest schema type mismatch at {path}")
    if "const" in schema and value != schema["const"]:
        raise OperationalError(f"manifest schema const mismatch at {path}")
    if "enum" in schema and value not in schema["enum"]:
        raise OperationalError(f"manifest schema enum mismatch at {path}")
    if isinstance(value, str):
        if len(value) < int(schema.get("minLength", 0)):
            raise OperationalError(f"manifest schema string is empty or too short at {path}")
        if "pattern" in schema and re.search(str(schema["pattern"]), value) is None:
            raise OperationalError(f"manifest schema pattern mismatch at {path}")
        fmt = schema.get("format")
        if fmt == "uuid":
            try:
                uuid.UUID(value)
            except ValueError as exc:
                raise OperationalError(f"manifest schema UUID is invalid at {path}") from exc
        if fmt == "date-time":
            if not re.fullmatch(r"\d{4}-\d\d-\d\dT\d\d:\d\d:\d\d(?:\.\d+)?(?:Z|[+-]\d\d:\d\d)", value):
                raise OperationalError(f"approvedAt must be RFC3339 with an explicit timezone at {path}")
            try:
                dt.datetime.fromisoformat(value.replace("Z", "+00:00"))
            except ValueError as exc:
                raise OperationalError(f"approvedAt is not a valid RFC3339 timestamp at {path}") from exc
    if isinstance(value, int) and not isinstance(value, bool) and value < int(schema.get("minimum", -(2**63))):
        raise OperationalError(f"manifest schema minimum mismatch at {path}")
    if isinstance(value, dict):
        for key in schema.get("required", []):
            if key not in value:
                raise OperationalError(f"manifest schema missing {key!r} at {path}")
        props = schema.get("properties", {})
        if schema.get("additionalProperties") is False:
            unknown = sorted(set(value) - set(props))
            if unknown:
                raise OperationalError(f"manifest schema unknown fields at {path}: {', '.join(unknown)}")
        for key, item in value.items():
            if key in props:
                _validate_schema_value(item, props[key], document, f"{path}.{key}")
    if isinstance(value, list):
        item_schema = schema.get("items")
        if item_schema:
            for index, item in enumerate(value):
                _validate_schema_value(item, item_schema, document, f"{path}[{index}]")
        if schema.get("uniqueItems"):
            serialized = [canonical_bytes(item) for item in value]
            if len(set(serialized)) != len(serialized):
                raise OperationalError(f"manifest schema duplicate array items at {path}")
    if "not" in schema and isinstance(value, str):
        forbidden = schema["not"].get("pattern")
        if forbidden and re.search(str(forbidden), value):
            raise OperationalError(f"manifest path is not relative and normalized at {path}")


def _validate_manifest(raw: bytes) -> dict[str, Any]:
    manifest = loads_strict(raw)
    if not isinstance(manifest, dict):
        raise OperationalError("decision manifest root must be a JSON object")
    schema_path = Path(__file__).with_name("gx-writability-decision-manifest.schema.json")
    schema = loads_strict(schema_path.read_bytes())
    _validate_schema_value(manifest, schema, schema)
    ids = [decision["decisionId"] for decision in manifest["decisions"]]
    if len(set(ids)) != len(ids):
        raise OperationalError("decision manifest repeats decisionId")
    id_set = set(ids)
    for decision in manifest["decisions"]:
        for field in ("actor", "justification", "approvalReceipt.reference", "approvalReceipt.text"):
            value: Any = decision
            for part in field.split("."):
                value = value[part]
            if not value.strip():
                raise OperationalError(f"decision has an empty human receipt field: {decision['decisionId']} ({field})")
        if decision["decisionId"] in decision["dependsOnDecisionIds"]:
            raise OperationalError(f"decision depends on itself: {decision['decisionId']}")
        if len(set(decision["dependsOnDecisionIds"])) != len(decision["dependsOnDecisionIds"]):
            raise OperationalError(f"decision repeats a dependency: {decision['decisionId']}")
        missing = sorted(set(decision["dependsOnDecisionIds"]) - id_set)
        if decision["reasonCodes"] != sorted(set(decision["reasonCodes"])):
            raise OperationalError(f"reasonCodes must be a sorted set: {decision['decisionId']}")
        if decision["dependsOnDecisionIds"] != sorted(set(decision["dependsOnDecisionIds"])):
            raise OperationalError(f"dependsOnDecisionIds must be a sorted set: {decision['decisionId']}")
        for field in ("proofFiles", "evidenceReferences"):
            keys = [(item["rootKind"], item["path"]) for item in decision[field]]
            if len(keys) != len(set(keys)):
                raise OperationalError(f"decision repeats a {field} path: {decision['decisionId']}")
        if decision["proofFiles"] != sorted(decision["proofFiles"], key=lambda item: (item["rootKind"], item["path"])):
            raise OperationalError(f"proofFiles must be sorted by rootKind/path: {decision['decisionId']}")
        for target in decision["scope"]["newTargets"]:
            if not target["table"].get("guid"):
                raise OperationalError(f"authorized Table requires a GUID: {decision['decisionId']}")
            for assignment_target in target["assignmentTargets"]:
                if not assignment_target["occurrence"]["attribute"].get("guid"):
                    raise OperationalError(f"authorized Attribute requires a GUID: {decision['decisionId']}")
        for assignment in decision["scope"]["assignments"]:
            if not assignment["object"].get("guid") or not assignment["attribute"].get("guid"):
                raise OperationalError(f"authorized assignment requires Procedure and Attribute GUIDs: {decision['decisionId']}")
    return manifest


def _relative_path(root: Path, relative: str) -> Path:
    pure = Path(relative)
    if pure.is_absolute() or any(part in {"", ".", ".."} for part in relative.split("/")) or "\\" in relative:
        raise OperationalError(f"unsafe relative path: {relative!r}")
    resolved_root = root.resolve(strict=True)
    target = (resolved_root / Path(*relative.split("/"))).resolve(strict=True)
    try:
        target.relative_to(resolved_root)
    except ValueError as exc:
        raise OperationalError(f"proof path escapes its root: {relative!r}") from exc
    if not target.is_file():
        raise OperationalError(f"proof path is not a file: {relative}")
    return target


def _proof_digest(proof_files: list[dict[str, str]]) -> str:
    ordered = sorted(proof_files, key=lambda item: (item["rootKind"], item["path"]))
    return _sha256(canonical_bytes(ordered).decode("utf-8"))


def _semantic_decision_digest(front_id: str, rule_version: str, decision: dict[str, Any]) -> str:
    fields = {key: decision[key] for key in (
        "decisionId", "type", "scope", "reasonCodes", "dependsOnDecisionIds",
        "inventoryDigest", "proofDigest", "deltaDigest")}
    fields["frontId"] = front_id
    fields["ruleVersion"] = rule_version
    return hashlib.sha256(canonical_bytes(fields)).hexdigest()


def _scope_identity(decision: dict[str, Any]) -> bytes:
    return canonical_bytes(decision["scope"])


def _group_new_target(block_result: dict[str, Any], group: dict[str, Any]) -> dict[str, Any]:
    block = {key: block_result["block"][key] for key in (
        "object", "partType", "sourceSha256", "start", "end", "snippetSha256")}
    views = [{key: view[key] for key in ("transaction", "partType", "level")}
             for view in group["views"]]
    assignment_targets: list[dict[str, Any]] = []
    for target in group["assignmentTargets"]:
        eligible_occurrences = sorted(target["occurrences"],
                                      key=lambda item: canonical_bytes(item["occurrence"]))
        if not eligible_occurrences:
            raise OperationalError("candidate group has an assignment without a real occurrence")
        assignment_targets.append({"assignment": target["assignment"],
                                   "occurrence": eligible_occurrences[0]["occurrence"]})
    table = group["table"]
    if not table.get("guid"):
        raise OperationalError("selectable Table lacks GUID")
    return {"block": block, "table": table, "views": views,
            "assignmentTargets": assignment_targets}


def _expected_scope(decision_type: str, new_target: dict[str, Any],
                    selected_assignment: dict[str, Any] | None = None) -> dict[str, Any]:
    target_assignments = new_target["assignmentTargets"]
    if selected_assignment is not None:
        target_assignments = [selected_assignment]
    targets = [item["occurrence"] for item in target_assignments]
    assignments = [item["assignment"] for item in target_assignments]
    if decision_type == "select-new-target":
        return {"targets": targets, "assignments": assignments, "tableBindings": [],
                "relations": [], "newTargets": [new_target]}
    return {"targets": targets, "assignments": assignments, "tableBindings": [],
            "relations": [], "newTargets": []}


def _proof_files_for_block(corpus_root: Path, delta_root: Path | None,
                           result: dict[str, Any], block_result: dict[str, Any]) -> list[dict[str, str]]:
    paths: set[tuple[str, str]] = set()
    for candidate in block_result["candidates"]:
        for ref in [candidate["table"], *(view["transaction"] for view in candidate["views"])]:
            if ref.get("path") and ref.get("rootKind") in {"corpus", "delta"}:
                paths.add((str(ref["rootKind"]), str(ref["path"])))
        for target in candidate["assignmentTargets"]:
            for occurrence in target["occurrences"]:
                ref = occurrence["occurrence"]
                attr = ref["attribute"]
                tx = ref["transaction"]
                if attr.get("path"):
                    paths.add((str(attr.get("rootKind", "corpus")), str(attr["path"])))
                if tx.get("path"):
                    paths.add((str(tx.get("rootKind", "corpus")), str(tx["path"])))
                for related in occurrence.get("relatedProofRefs", []):
                    if related.get("path") and related.get("rootKind") in {"corpus", "delta"}:
                        paths.add((str(related["rootKind"]), str(related["path"])))
    procedure = block_result["block"]["object"]
    if procedure.get("rootKind") in {"corpus", "delta"}:
        paths.add((procedure["rootKind"], procedure["path"]))
    proof_files: list[dict[str, str]] = []
    for root_kind, relative in sorted(paths):
        root = corpus_root if root_kind == "corpus" else delta_root
        if root is None:
            raise OperationalError("decision proof refers to delta but no delta root was supplied")
        file_path = _relative_path(root, relative)
        proof_files.append({"rootKind": root_kind, "path": relative,
                            "sha256": hashlib.sha256(file_path.read_bytes()).hexdigest()})
    return proof_files


def _decision_inventory_digest(decision_type: str, block_result: dict[str, Any],
                               candidate_set: list[dict[str, Any]], predecessor_digests: list[tuple[str, str]]) -> str:
    # Decision-result fields are presentation state. Exclude them so evaluating
    # the same request twice cannot change its semantic digest.
    def semantic_assignment(reference: dict[str, Any]) -> dict[str, Any]:
        return {key: reference.get(key) for key in (
            "object", "partType", "sourceSha256", "start", "end", "snippetSha256",
            "attribute", "operation", "blockStart", "blockEnd", "blockSha256")}

    semantic_candidates = []
    for group in candidate_set:
        semantic_assignments = []
        for target in group["assignmentTargets"]:
            semantic_occurrences = []
            for occurrence in target["occurrences"]:
                semantic_occurrences.append({key: occurrence.get(key) for key in (
                    "occurrence", "classification", "writable", "canAssignInNew", "reason",
                    "reasonCodes", "coverage", "evidence", "provenance", "relatedProofRefs")})
            semantic_occurrences.sort(key=canonical_bytes)
            semantic_assignments.append({"assignment": semantic_assignment(target["assignment"]),
                                         "occurrences": semantic_occurrences,
                                         "reasonCodes": target.get("reasonCodes", [])})
        new_target = group.get("newTargetRef")
        semantic_new_target = None
        if new_target is not None:
            semantic_new_target = {
                "block": new_target["block"], "table": new_target["table"],
                "views": new_target["views"],
                "assignmentTargets": [{
                    "assignment": semantic_assignment(item["assignment"]),
                    "occurrence": item["occurrence"],
                } for item in new_target["assignmentTargets"]],
            }
        semantic_candidates.append({
            "table": group["table"], "views": group["views"],
            "assignmentTargets": semantic_assignments,
            "selectable": group["selectable"],
            "selectionReasonCodes": group["selectionReasonCodes"],
            "newTargetRef": semantic_new_target,
        })
    semantic_candidates.sort(key=lambda item: canonical_bytes(item["table"]))
    semantic_block_assignments = [{
        "assignment": semantic_assignment(assignment["assignment"]),
        **{key: assignment.get(key) for key in ("name", "line", "identityStatus", "reasonCodes")}}
        for assignment in block_result["assignments"]]
    closure = {"block": block_result["block"], "candidateState": block_result["candidateState"],
               "coverage": block_result["coverage"], "reasonCodes": block_result["reasonCodes"],
               "assignments": semantic_block_assignments, "candidates": semantic_candidates,
               "writabilityRuleVersion": automatic.WRITABILITY_RULE_VERSION,
               "predecessors": [{"decisionId": key, "semanticDecisionDigest": value}
                                for key, value in sorted(predecessor_digests)]}
    if decision_type == "select-new-target":
        closure["selectionCandidates"] = [group["table"] for group in semantic_candidates]
    return hashlib.sha256(canonical_bytes(closure)).hexdigest()


def _delta_digest(delta_root: Path | None, proof_files: list[dict[str, str]],
                  scope: dict[str, Any]) -> str:
    delta_files = [{"path": item["path"], "sha256": item["sha256"]}
                   for item in proof_files if item["rootKind"] == "delta"]
    payload = {"presence": "present" if delta_root is not None else "absent",
               "files": sorted(delta_files, key=lambda item: (item["path"], item["sha256"])),
               "targets": scope["targets"], "assignments": scope["assignments"]}
    return hashlib.sha256(canonical_bytes(payload)).hexdigest()


def _affirm_scope(block_result: dict[str, Any], group: dict[str, Any],
                  assignment: dict[str, Any]) -> tuple[dict[str, Any], list[str], bool]:
    assignment_bytes = canonical_bytes(assignment)
    matches = [target for target in group["assignmentTargets"]
               if canonical_bytes(target["assignment"]) == assignment_bytes]
    if len(matches) != 1:
        raise OperationalError("affirm target assignment is absent or ambiguous")
    target = matches[0]
    occurrences = sorted(target["occurrences"], key=lambda item: canonical_bytes(item["occurrence"]))
    scope = {"targets": [item["occurrence"] for item in occurrences], "assignments": [assignment],
             "tableBindings": [], "relations": [], "newTargets": []}
    reason_codes = sorted({code for item in occurrences for code in item["reasonCodes"]})
    eligible_classes = {"extended-fk-descriptive", "unclassified-role-conflict"}
    eligible_reasons = {"inferred-fk-descriptive", "heuristic-role-conflict"}
    eligible = bool(occurrences) and all(
        item["classification"] in eligible_classes
        and item["coverage"] == "complete-in-model"
        and item["writable"] in (False, None)
        and set(item["reasonCodes"]) <= eligible_reasons
        and bool(item["reasonCodes"])
        for item in occurrences
    )
    return scope, reason_codes, eligible


def _block_key(block_result: dict[str, Any]) -> tuple[str, str, str, str, int, int]:
    block = block_result["block"]
    object_ref = block["object"]
    return (str(object_ref.get("rootKind")), str(object_ref.get("path")),
            str(object_ref.get("guid")), str(block["sourceSha256"]),
            int(block["start"]), int(block["end"]))


def _topological_decisions(decisions: list[dict[str, Any]]) -> tuple[list[dict[str, Any]], set[str]]:
    by_id = {decision["decisionId"]: decision for decision in decisions}
    # Mark only members of cyclic strongly connected components. A decision
    # that merely depends on a cycle must remain a dependent and become stale.
    adjacency = {
        identifier: [dependency for dependency in decision["dependsOnDecisionIds"]
                     if dependency in by_id]
        for identifier, decision in by_id.items()
    }
    index = 0
    indexes: dict[str, int] = {}
    lowlinks: dict[str, int] = {}
    stack: list[str] = []
    on_stack: set[str] = set()
    cycle_ids: set[str] = set()

    def visit(identifier: str) -> None:
        nonlocal index
        indexes[identifier] = index
        lowlinks[identifier] = index
        index += 1
        stack.append(identifier)
        on_stack.add(identifier)
        for dependency in adjacency[identifier]:
            if dependency not in indexes:
                visit(dependency)
                lowlinks[identifier] = min(lowlinks[identifier], lowlinks[dependency])
            elif dependency in on_stack:
                lowlinks[identifier] = min(lowlinks[identifier], indexes[dependency])
        if lowlinks[identifier] != indexes[identifier]:
            return
        component: list[str] = []
        while stack:
            member = stack.pop()
            on_stack.remove(member)
            component.append(member)
            if member == identifier:
                break
        if len(component) > 1 or identifier in adjacency[identifier]:
            cycle_ids.update(component)

    for identifier in sorted(by_id):
        if identifier not in indexes:
            visit(identifier)

    ordered_ids = sorted(cycle_ids)
    completed = set(cycle_ids)
    pending = set(by_id) - cycle_ids
    while pending:
        ready = sorted(identifier for identifier in pending
                       if {dependency for dependency in adjacency[identifier]
                           if dependency not in cycle_ids} <= completed)
        if not ready:
            # Defensive: Tarjan should have classified every cycle.
            unresolved = sorted(pending)
            cycle_ids.update(unresolved)
            ordered_ids.extend(unresolved)
            break
        ordered_ids.extend(ready)
        pending.difference_update(ready)
        completed.update(ready)
    return [by_id[identifier] for identifier in ordered_ids], cycle_ids


def _all_blocks(results: list[dict[str, Any]]) -> list[tuple[dict[str, Any], dict[str, Any]]]:
    return [(procedure, block) for procedure in results for block in procedure.get("newBlocks", [])]


def _find_current_block(results: list[dict[str, Any]], block_ref: dict[str, Any]) -> tuple[dict[str, Any], dict[str, Any]] | None:
    key = (str(block_ref["object"].get("rootKind")), str(block_ref["object"].get("path")),
           str(block_ref["object"].get("guid")), str(block_ref["sourceSha256"]),
           int(block_ref["start"]), int(block_ref["end"]))
    matches = [(procedure, block) for procedure, block in _all_blocks(results)
               if _block_key(block) == key and canonical_bytes({k: block["block"][k] for k in (
                   "object", "partType", "sourceSha256", "start", "end", "snippetSha256")}) == canonical_bytes(block_ref)]
    return matches[0] if len(matches) == 1 else None


def _proof_files_for_targets(corpus_root: Path, delta_root: Path | None,
                             result: dict[str, Any], blocks: list[dict[str, Any]]) -> list[dict[str, str]]:
    all_files: dict[tuple[str, str], dict[str, str]] = {}
    for block_result in blocks:
        for proof in _proof_files_for_block(corpus_root, delta_root, result, block_result):
            key = (proof["rootKind"], proof["path"])
            existing = all_files.get(key)
            if existing is not None and existing["sha256"] != proof["sha256"]:
                raise OperationalError(f"proof changed during decision evaluation: {proof['path']}")
            all_files[key] = proof
    return [all_files[key] for key in sorted(all_files)]


def _decision_digests(decision: dict[str, Any], front_id: str, rule_version: str,
                      block_results: list[dict[str, Any]], corpus_root: Path,
                      delta_root: Path | None, result: dict[str, Any],
                      semantic_predecessors: dict[str, str],
                      decisions_by_id: dict[str, dict[str, Any]] | None = None) -> tuple[str, list[dict[str, str]], str, str]:
    if not block_results:
        raise OperationalError("decision scope has no current New block")
    proof_files = _proof_files_for_targets(corpus_root, delta_root, result, block_results)
    proof_digest = _proof_digest(proof_files)
    delta_digest = _delta_digest(delta_root, proof_files, decision["scope"])
    predecessor_digests = _decision_dependency_closure(
        decision, semantic_predecessors, decisions_by_id)
    semantic_blocks = [{
        "block": block["block"],
        "inventoryDigest": _decision_inventory_digest(
            decision["type"], block, block["candidates"], predecessor_digests),
    } for block in sorted(block_results, key=lambda item: _block_key(item))]
    inventory_digest = hashlib.sha256(canonical_bytes({
        "frontId": front_id, "ruleVersion": rule_version,
        "blocks": semantic_blocks,
    })).hexdigest()
    return inventory_digest, proof_files, proof_digest, delta_digest


def _transaction_identity(transaction: dict[str, object]) -> dict[str, object]:
    return _object_ref(str(transaction.get("rootKind", "corpus")),
                       str(transaction["path"]), "Transaction",
                       transaction.get("guid") if isinstance(transaction.get("guid"), str) else None,
                       str(transaction["name"]))


def _model_root_kind(model: Any, relative_path: str) -> str:
    return str(getattr(model, "root_kinds_by_path", {}).get(relative_path, "corpus"))


def _model_object_ref(model: Any, relative_path: str, object_type: str,
                      guid: str | None, name: str) -> dict[str, object]:
    return _object_ref(_model_root_kind(model, relative_path), relative_path,
                       object_type, guid, name)


def _model_source_path(model: Any, relative_path: str) -> tuple[str, Path]:
    root_kind = _model_root_kind(model, relative_path)
    roots = getattr(model, "source_roots", {"corpus": model.root})
    root = roots.get(root_kind)
    if root is None:
        raise OperationalError(f"source root is unavailable for {root_kind}:{relative_path}")
    return root_kind, _relative_path(Path(root), relative_path)


def _stamp_row_root_kinds(model: Any, rows: list[Any]) -> None:
    for row in rows:
        attribute_path = row.identity["attribute"].get("path")
        if isinstance(attribute_path, str):
            row.identity["attribute"]["rootKind"] = _model_root_kind(model, attribute_path)


def _level_identity(level: Any) -> dict[str, object]:
    return {"guid": level.guid, "pathOrdinals": list(level.path_ordinals)}


def _view_identity(level: Any) -> dict[str, object]:
    return {"transaction": _transaction_identity(level.transaction),
            "partType": level.part_type, "level": _level_identity(level)}


def _occurrence_identity(level: Any, ref: Any, attribute: Any | None) -> dict[str, object]:
    return {"transaction": _transaction_identity(level.transaction),
            "partType": level.part_type, "level": _level_identity(level),
            "attribute": _object_ref("corpus", attribute.path if attribute else "", "Attribute",
                                      ref.guid, ref.name)}


def _transaction_snapshot(transaction_path: Path, corpus_root: Path, *,
                          root_kinds_by_path: dict[str, str] | None = None,
                          source_roots: dict[str, Path] | None = None) -> tuple[Any, Any, list[Any], list[Any]]:
    """Load automatic and isolated contextual copies for one Transaction snapshot."""
    model = automatic._load_writability_model(corpus_root)
    model.root_kinds_by_path = {str(path).replace("\\", "/"): kind
                                for path, kind in (root_kinds_by_path or {}).items()}
    model.source_roots = source_roots or {"corpus": corpus_root.resolve(strict=True)}
    for item in model.transactions:
        item["rootKind"] = _model_root_kind(model, str(item["path"]))
    absolute = transaction_path.resolve(strict=True)
    matches = [item for item in model.transactions
               if Path(str(item["_absolutePath"])).resolve() == absolute]
    if len(matches) != 1:
        raise OperationalError(f"Transaction identity is not unique in corpus inventory: {absolute}")
    transaction = matches[0]
    levels = [item for item in model.levels
              if item.transaction.get("path") == transaction.get("path")
              and item.transaction.get("guid") == transaction.get("guid")]
    attributes_by_guid: dict[str, list[Any]] = {}
    for attribute in model.attributes:
        if attribute.guid:
            attributes_by_guid.setdefault(attribute.guid, []).append(attribute)
    relations, table_views = automatic._table_relation_index(model)
    automatic_rows = [row for level in levels for row in automatic._classify_model_level(
        level, model, attributes_by_guid, relations, table_views)]
    _stamp_row_root_kinds(model, automatic_rows)
    contextual_model = copy.deepcopy(model)
    contextual_transaction = next(item for item in contextual_model.transactions
                                  if item.get("path") == transaction.get("path")
                                  and item.get("guid") == transaction.get("guid"))
    contextual_levels = [item for item in contextual_model.levels
                         if item.transaction.get("path") == contextual_transaction.get("path")
                         and item.transaction.get("guid") == contextual_transaction.get("guid")]
    return model, contextual_model, automatic_rows, contextual_levels


def _apply_table_binding_context(model: Any, levels: list[Any], binding: dict[str, Any]) -> Any:
    """Apply a previously validated binding only to an isolated analysis model."""
    target = binding["table"]
    transaction_ref = binding["transaction"]
    level_ref = binding["level"]
    selected_transaction = _transaction_identity(levels[0].transaction) if levels else None
    if selected_transaction is None or canonical_bytes(selected_transaction) != canonical_bytes(transaction_ref):
        raise DecisionIssue("out-of-scope", "table-binding-transaction-mismatch",
                            "table binding names a different Transaction snapshot")
    matching_levels = [level for level in levels
                       if level.part_type == binding["partType"]
                       and level.guid == level_ref.get("guid")
                       and list(level.path_ordinals) == level_ref.get("pathOrdinals")]
    if len(matching_levels) != 1:
        raise DecisionIssue("stale", "table-binding-level-stale",
                            "table binding Level is absent or ambiguous in the current snapshot")
    level = matching_levels[0]
    tables = [table for table in model.tables
              if table.guid == target.get("guid") and table.path == target.get("path")
              and table.name == target.get("name")]
    if len(tables) != 1 or tables[0] not in level.table_candidates:
        raise DecisionIssue("out-of-scope", "table-binding-candidate-not-current",
                            "selected Table is not a current PK-compatible candidate")
    table = tables[0]
    key_guids = [ref.guid for ref in level.key_refs]
    if not key_guids or not all(key_guids) or [ref.guid for ref in table.key_refs] != key_guids:
        raise DecisionIssue("ineligible", "table-binding-key-mismatch",
                            "selected Table primary key no longer matches this Level")
    view = _view_identity(level)
    if canonical_bytes(binding["views"]) != canonical_bytes([view]):
        raise DecisionIssue("out-of-scope", "table-binding-view-scope-mismatch",
                            "binding must cover exactly the displayed Level view")
    level.table_candidates = [table]
    level.association_status = "resolved-level-type-and-table-key"
    level.association_evidence = [{"guid": table.guid, "name": table.name,
                                   "path": table.path, "keyGuids": key_guids,
                                   "bindingDecision": True}]
    return level


def _classify_transaction_context(model: Any, levels: list[Any],
                                  relation_actions: list[tuple[str, dict[str, Any]]] | None = None) -> list[Any]:
    relations, table_views = automatic._table_relation_index(model)
    for action, relation_ref in relation_actions or []:
        source_guid = relation_ref["sourceTable"].get("guid")
        target_guid = relation_ref["targetTable"].get("guid")
        source_edges = relations.get(str(source_guid), [])
        matching = [edge for edge in source_edges
                    if str(edge["index"].get("identity")) == relation_ref["indexIdentity"]
                    and any(table.guid == target_guid and table.path == relation_ref["targetTable"].get("path")
                            for table in edge["targets"])]
        if len(matching) != 1:
            raise OperationalError("validated relation decision no longer matches the contextual graph")
        edge = matching[0]
        if action == "resolve-inferred-relation":
            edge["targets"] = [table for table in edge["targets"] if table.guid == target_guid]
            edge["ambiguous"] = False
            edge["confirmedByDecision"] = True
        elif action == "reject-inferred-relation":
            edge["targets"] = [table for table in edge["targets"] if table.guid != target_guid]
            edge["ambiguous"] = len(edge["targets"]) != 1
            if not edge["targets"]:
                source_edges.remove(edge)
        else:
            raise OperationalError(f"unsupported contextual relation action: {action}")
    attributes_by_guid: dict[str, list[Any]] = {}
    for attribute in model.attributes:
        if attribute.guid:
            attributes_by_guid.setdefault(attribute.guid, []).append(attribute)
    rows = [row for level in levels for row in automatic._classify_model_level(
        level, model, attributes_by_guid, relations, table_views)]
    _stamp_row_root_kinds(model, rows)
    return rows


def _transaction_level_key(level: Any) -> tuple[object, ...]:
    return (str(level.transaction.get("path")), str(level.transaction.get("guid")),
            level.part_type, level.guid, tuple(level.path_ordinals))


def _transaction_binding_ref(model: Any, level: Any, table: Any) -> dict[str, Any]:
    return {"transaction": _transaction_identity(level.transaction),
            "partType": level.part_type, "level": _level_identity(level),
            "table": _model_object_ref(model, table.path, "Table", table.guid, table.name),
            "views": [_view_identity(level)]}


def _transaction_scope(binding: dict[str, Any], rows: list[Any]) -> dict[str, Any]:
    level_ref = binding["level"]
    transaction_ref = binding["transaction"]
    targets = [row.identity for row in rows
               if canonical_bytes(row.identity["transaction"]) == canonical_bytes(transaction_ref)
               and row.part_type == binding["partType"]
               and row.level_guid == level_ref.get("guid")
               and row.path_ordinals == level_ref.get("pathOrdinals")]
    return {"targets": sorted(targets, key=canonical_bytes), "assignments": [],
            "tableBindings": [binding], "relations": [], "newTargets": []}


def _relation_candidates_for_attribute(model: Any, level: Any,
                                       attribute_guid: str) -> tuple[list[dict[str, Any]], list[str]]:
    relations, table_views = automatic._table_relation_index(model)
    tables_by_guid = {item.guid: item for item in model.tables if item.guid}
    attributes_by_guid: dict[str, list[Any]] = {}
    for attribute in model.attributes:
        if attribute.guid:
            attributes_by_guid.setdefault(attribute.guid, []).append(attribute)
    start_tables = [table for table in level.table_candidates if table.guid]
    queue: list[tuple[Any, int]] = [(item, 0) for item in start_tables]
    scheduled = {item.guid for item in start_tables}
    visited: set[str] = set()
    refs: dict[bytes, dict[str, Any]] = {}
    issues: set[str] = set()
    inspected_edges = 0
    while queue:
        source, depth = queue.pop(0)
        if source.guid in visited:
            continue
        visited.add(source.guid)
        edges = relations.get(source.guid, [])
        inspected_edges += len(edges)
        if inspected_edges > 4096:
            issues.add("relation-search-budget-exhausted")
            break
        if depth >= 10:
            if edges:
                issues.add("relation-depth-exhausted")
            continue
        source_views = table_views.get(source.guid, [])
        for edge in edges:
            index = edge["index"]
            members = list(index["members"])
            targets = list(edge["targets"])
            for target in targets:
                target_views = table_views.get(target.guid or "", [])
                relevant_views = [view for view in target_views
                                  if any(ref.guid == attribute_guid for ref in view.attributes)]
                relevant = attribute_guid in edge["memberGuids"] or bool(relevant_views)
                if relevant:
                    target_key = list(target.key_refs)
                    if len(members) != len(target_key) or any(
                            left.guid != right.guid for left, right in zip(members, target_key)):
                        issues.add("relation-mapping-incomplete")
                    else:
                        for source_view in source_views:
                            for target_view in relevant_views:
                                mapping: list[dict[str, Any]] = []
                                valid_mapping = True
                                for source_ref, target_ref in zip(members, target_key):
                                    source_attrs = attributes_by_guid.get(source_ref.guid or "", [])
                                    target_attrs = attributes_by_guid.get(target_ref.guid or "", [])
                                    if len(source_attrs) != 1 or len(target_attrs) != 1:
                                        valid_mapping = False
                                        break
                                    mapping.append({
                                        "sourceAttribute": _model_object_ref(model, source_attrs[0].path,
                                                                             "Attribute", source_ref.guid,
                                                                             source_ref.name),
                                        "targetAttribute": _model_object_ref(model, target_attrs[0].path,
                                                                             "Attribute", target_ref.guid,
                                                                             target_ref.name),
                                    })
                                if not valid_mapping:
                                    issues.add("relation-mapping-identity-incomplete")
                                    continue
                                relation_ref = {
                                    "sourceTable": _model_object_ref(model, source.path, "Table",
                                                                     source.guid, source.name),
                                    "sourceView": _view_identity(source_view),
                                    "targetTable": _model_object_ref(model, target.path, "Table",
                                                                     target.guid, target.name),
                                    "targetView": _view_identity(target_view),
                                    "indexIdentity": str(index["identity"]),
                                    "mapping": mapping,
                                }
                                refs[canonical_bytes(relation_ref)] = relation_ref
                if target.guid and target.guid not in scheduled:
                    scheduled.add(target.guid)
                    queue.append((target, depth + 1))
    return [refs[key] for key in sorted(refs)], sorted(issues)


def _transaction_inventory(model: Any, level: Any) -> dict[str, Any]:
    attrs = sorted(({"guid": ref.guid, "name": ref.name, "key": ref.key,
                     "redundant": ref.is_redundant, "identitySource": ref.identity_source,
                     "issue": ref.issue} for ref in level.attributes),
                   key=canonical_bytes)
    key_refs = [{"guid": ref.guid, "name": ref.name, "issue": ref.issue}
                for ref in level.key_refs]
    candidates = []
    for table in sorted(level.table_candidates, key=lambda item: (item.path, str(item.guid))):
        candidates.append({"table": _model_object_ref(model, table.path, "Table", table.guid, table.name),
                           "keyGuids": [ref.guid for ref in table.key_refs],
                           "indexes": [{"identity": index["identity"],
                                        "memberGuids": [ref.guid for ref in index["members"]],
                                        "type": index["type"], "role": index["role"]}
                                       for index in table.indexes],
                           "errors": sorted(table.errors)})
    relation_candidates: dict[bytes, dict[str, Any]] = {}
    relation_issues: set[str] = set()
    for ref in level.attributes:
        if not ref.guid:
            continue
        candidates, issues = _relation_candidates_for_attribute(model, level, ref.guid)
        relation_issues.update(issues)
        for candidate in candidates:
            relation_candidates[canonical_bytes(candidate)] = candidate
    return {"transaction": _transaction_identity(level.transaction),
            "partType": level.part_type, "level": _level_identity(level),
            "name": level.name, "type": level.level_type,
            "associationStatus": level.association_status,
            "associationEvidence": level.association_evidence,
            "keyRefs": key_refs, "attributes": attrs, "candidates": candidates,
            "relationCandidates": [relation_candidates[key] for key in sorted(relation_candidates)],
            "relationIssues": sorted(relation_issues),
            "inventoryErrors": sorted(model.errors)}


def _transaction_proof_files(model: Any, level: Any) -> list[dict[str, str]]:
    paths: set[str] = {str(level.transaction["path"])}
    relevant_guids = {ref.guid for ref in [*level.attributes, *level.key_refs] if ref.guid}
    for table in level.table_candidates:
        paths.add(table.path)
        relevant_guids.update(ref.guid for ref in table.key_refs if ref.guid)
        for index in table.indexes:
            relevant_guids.update(ref.guid for ref in index["members"] if ref.guid)
    for attribute_ref in level.attributes:
        if not attribute_ref.guid:
            continue
        relation_refs, _ = _relation_candidates_for_attribute(model, level, attribute_ref.guid)
        for relation_ref in relation_refs:
            paths.add(str(relation_ref["sourceTable"]["path"]))
            paths.add(str(relation_ref["targetTable"]["path"]))
            paths.add(str(relation_ref["sourceView"]["transaction"]["path"]))
            paths.add(str(relation_ref["targetView"]["transaction"]["path"]))
            for pair in relation_ref["mapping"]:
                relevant_guids.add(pair["sourceAttribute"].get("guid"))
                relevant_guids.add(pair["targetAttribute"].get("guid"))
    for attribute in model.attributes:
        if attribute.guid in relevant_guids:
            paths.add(attribute.path)
    proof_files: list[dict[str, str]] = []
    for relative in sorted(paths):
        root_kind, absolute = _model_source_path(model, relative)
        proof_files.append({"rootKind": root_kind, "path": relative,
                            "sha256": hashlib.sha256(absolute.read_bytes()).hexdigest()})
    return proof_files


def _transaction_inventory_digest(front_id: str, rule_version: str, decision: dict[str, Any],
                                  model: Any, level: Any,
                                  predecessor_digests: dict[str, str],
                                  decisions_by_id: dict[str, dict[str, Any]] | None = None) -> str:
    ancestors = _decision_dependency_closure(decision, predecessor_digests, decisions_by_id)
    payload = {"frontId": front_id, "ruleVersion": rule_version,
               "inventory": _transaction_inventory(model, level),
               "scope": decision["scope"],
               "predecessors": ancestors}
    return hashlib.sha256(canonical_bytes(payload)).hexdigest()


def _decision_dependency_closure(decision: dict[str, Any],
                                 semantic_digests: dict[str, str],
                                 decisions_by_id: dict[str, dict[str, Any]] | None = None) -> list[tuple[str, str]]:
    identifiers: set[str] = set()
    pending = list(decision["dependsOnDecisionIds"])
    while pending:
        identifier = pending.pop()
        if identifier in identifiers:
            continue
        identifiers.add(identifier)
        if decisions_by_id and identifier in decisions_by_id:
            pending.extend(decisions_by_id[identifier]["dependsOnDecisionIds"])
    return sorted(((identifier, semantic_digests[identifier])
                   for identifier in identifiers if identifier in semantic_digests),
                  key=lambda item: item[0])


def _transaction_decision_request(model: Any, levels: list[Any], rows: list[Any],
                                  corpus_root: Path, front_id: str,
                                  delta_root: Path | None) -> dict[str, Any]:
    requests: list[dict[str, Any]] = []
    templates: list[dict[str, Any]] = []
    choice_bundles: list[dict[str, Any]] = []
    rule_version = automatic.WRITABILITY_RULE_VERSION
    for level in levels:
        if level.association_status not in {"table-binding-proposed", "table-binding-ambiguous"}:
            continue
        level_rows = [row for row in rows if row.part_type == level.part_type
                      and row.transaction_guid == level.transaction.get("guid")
                      and row.level_guid == level.guid
                      and row.path_ordinals == list(level.path_ordinals)]
        if not level_rows or not level.table_candidates:
            continue
        reason_codes = sorted({code for row in level_rows for code in row.reason_codes
                               if code.startswith("table-binding-")})
        if not reason_codes:
            continue
        candidate_templates: list[dict[str, Any]] = []
        for table in sorted(level.table_candidates, key=lambda item: (item.path, str(item.guid))):
            binding = _transaction_binding_ref(model, level, table)
            scope = _transaction_scope(binding, level_rows)
            identifier = (f"bind-table-group-{str(level.transaction.get('guid') or '')[:8]}-"
                          f"{(level.guid or '-'.join(map(str, level.path_ordinals)))[:8]}-"
                          f"{str(table.guid or '')[:8]}")
            proof_files = _transaction_proof_files(model, level)
            template: dict[str, Any] = {
                "decisionId": identifier, "type": "bind-table-group",
                "actor": "PREENCHER", "approvedAt": "PREENCHER RFC3339",
                "approvalReceipt": {"reference": "PREENCHER", "text": "PREENCHER"},
                "justification": "PREENCHER", "evidenceReferences": [],
                "reasonCodes": reason_codes, "dependsOnDecisionIds": [],
                "scope": scope,
                "inventoryDigest": "", "proofFiles": proof_files,
                "proofDigest": _proof_digest(proof_files),
                "deltaDigest": _delta_digest(delta_root, proof_files, scope),
            }
            template["inventoryDigest"] = _transaction_inventory_digest(
                front_id, rule_version, template, model, level, {})
            candidate_templates.append(template)
            requests.append({"decisionId": identifier, "type": "bind-table-group",
                             "transaction": binding["transaction"], "level": binding["level"],
                             "table": binding["table"], "reasonCodes": reason_codes,
                             "scope": scope, "inventoryDigest": template["inventoryDigest"],
                             "proofFiles": proof_files, "proofDigest": template["proofDigest"],
                             "deltaDigest": template["deltaDigest"]})
        if len(candidate_templates) == 1:
            templates.extend(candidate_templates)
        elif candidate_templates:
            choice_bundles.append({"type": "bind-table-group",
                                   "transaction": _transaction_identity(level.transaction),
                                   "level": _level_identity(level),
                                   "decisionTemplates": candidate_templates})
    relation_reasons = {"inferred-fk-key", "inferred-fk-descriptive", "relation-target-ambiguous",
                        "heuristic-role-conflict"}
    for level in levels:
        if level.association_status != "resolved-level-type-and-table-key":
            continue
        level_rows = [row for row in rows if row.part_type == level.part_type
                      and row.transaction_guid == level.transaction.get("guid")
                      and row.level_guid == level.guid
                      and row.path_ordinals == list(level.path_ordinals)]
        for row in level_rows:
            if not set(row.reason_codes) or not set(row.reason_codes) <= relation_reasons:
                continue
            if row.coverage not in {"complete-in-model", "partial"}:
                continue
            relation_refs, relation_issues = _relation_candidates_for_attribute(
                model, level, row.attribute_guid or "")
            if relation_issues:
                continue
            resolve_templates: dict[tuple[str, str], list[dict[str, Any]]] = {}
            seen_relation_targets: set[tuple[str, str]] = set()
            for relation_ref in relation_refs:
                source_guid = relation_ref["sourceTable"].get("guid")
                source_edges = automatic._table_relation_index(model)[0].get(str(source_guid), [])
                edge = next((item for item in source_edges
                             if str(item["index"].get("identity")) == relation_ref["indexIdentity"]), None)
                if edge is None:
                    continue
                action: str | None = None
                unique_fk_confirmation = (
                    row.classification == "unclassified-relation-pending"
                    and set(row.reason_codes) == {"inferred-fk-key"}
                    and len(edge["targets"]) == 1
                )
                if len(edge["targets"]) > 1 and "relation-target-ambiguous" in row.reason_codes:
                    action = "resolve-inferred-relation"
                elif unique_fk_confirmation:
                    action = "resolve-inferred-relation"
                elif row.classification in {"extended-fk-descriptive", "unclassified-role-conflict"}:
                    action = "reject-inferred-relation"
                if action is None:
                    continue
                relation_choice_key = (str(source_guid), relation_ref["indexIdentity"])
                if action == "resolve-inferred-relation":
                    physical_choice = (relation_choice_key[0],
                                       str(relation_ref["targetTable"].get("guid")))
                    if physical_choice in seen_relation_targets:
                        continue
                    seen_relation_targets.add(physical_choice)
                scope = {"targets": [row.identity], "assignments": [], "tableBindings": [],
                         "relations": [relation_ref], "newTargets": []}
                relation_digest = hashlib.sha256(canonical_bytes(relation_ref)).hexdigest()[:8]
                identifier = (f"{action}-{str(level.transaction.get('guid') or '')[:8]}-"
                              f"{str(row.attribute_guid or '')[:8]}-{relation_digest}")
                proof_files = _transaction_proof_files(model, level)
                template = {
                    "decisionId": identifier, "type": action, "actor": "PREENCHER",
                    "approvedAt": "PREENCHER RFC3339",
                    "approvalReceipt": {"reference": "PREENCHER", "text": "PREENCHER"},
                    "justification": "PREENCHER", "evidenceReferences": [],
                    "reasonCodes": sorted(row.reason_codes), "dependsOnDecisionIds": [],
                    "scope": scope, "inventoryDigest": "", "proofFiles": proof_files,
                    "proofDigest": _proof_digest(proof_files),
                    "deltaDigest": _delta_digest(delta_root, proof_files, scope),
                }
                template["inventoryDigest"] = _transaction_inventory_digest(
                    front_id, rule_version, template, model, level, {})
                if action == "resolve-inferred-relation" and not unique_fk_confirmation:
                    resolve_templates.setdefault(relation_choice_key, []).append(template)
                else:
                    templates.append(template)
                requests.append({"decisionId": identifier, "type": action,
                                 "target": row.identity, "relation": relation_ref,
                                 "reasonCodes": template["reasonCodes"], "scope": scope,
                                 "inventoryDigest": template["inventoryDigest"],
                                 "proofFiles": proof_files, "proofDigest": template["proofDigest"],
                                 "deltaDigest": template["deltaDigest"]})
            for key, options in resolve_templates.items():
                if len(options) > 1:
                    choice_bundles.append({"type": "resolve-inferred-relation",
                                           "target": row.identity,
                                           "sourceTableGuid": key[0], "indexIdentity": key[1],
                                           "decisionTemplates": options})
                elif options:
                    omitted_ids = {item["decisionId"] for item in options}
                    requests = [item for item in requests if item["decisionId"] not in omitted_ids]
    return {"kind": "gx-writability-transaction-decision-request", "schemaVersion": 1,
            "frontId": front_id, "corpusRoot": str(corpus_root.resolve()),
            "deltaRoot": str(delta_root.resolve()) if delta_root else None,
            "ruleVersion": rule_version, "requests": requests,
            "decisionChoices": choice_bundles,
            "manifestTemplate": {"kind": "gx-writability-front-decisions", "schemaVersion": 1,
                                 "frontId": front_id, "corpusRoot": str(corpus_root.resolve()),
                                 "deltaRoot": str(delta_root.resolve()) if delta_root else None,
                                 "ruleVersion": rule_version,
                                 "decisions": templates}}


def _apply_transaction_decisions(manifest_raw: bytes, model: Any, contextual_model: Any,
                                 automatic_levels: list[Any], contextual_levels: list[Any],
                                 automatic_rows: list[Any], corpus_root: Path,
                                 front_id: str, delta_root: Path | None) -> dict[str, Any]:
    manifest = _validate_manifest(manifest_raw)
    if Path(manifest["corpusRoot"]).resolve(strict=True) != corpus_root.resolve(strict=True):
        raise OperationalError("decision manifest corpusRoot does not match the evaluated corpus")
    declared_delta = Path(manifest["deltaRoot"]).resolve(strict=True) if manifest["deltaRoot"] else None
    expected_delta = delta_root.resolve(strict=True) if delta_root else None
    if declared_delta != expected_delta:
        raise OperationalError("decision manifest deltaRoot does not match the evaluated Transaction snapshot")
    if manifest["ruleVersion"] != automatic.WRITABILITY_RULE_VERSION:
        raise OperationalError("decision manifest ruleVersion is stale")
    ordered, cycle_ids = _topological_decisions(manifest["decisions"])
    decisions_by_id = {item["decisionId"]: item for item in manifest["decisions"]}
    levels_by_key = {_transaction_level_key(level): level for level in automatic_levels}
    context_levels_by_key = {_transaction_level_key(level): level for level in contextual_levels}
    binds_by_level: dict[tuple[object, ...], list[str]] = {}
    for decision in manifest["decisions"]:
        if decision["type"] != "bind-table-group" or len(decision["scope"]["tableBindings"]) != 1:
            continue
        binding = decision["scope"]["tableBindings"][0]
        key = (str(binding["transaction"].get("path")), str(binding["transaction"].get("guid")),
               binding["partType"], binding["level"].get("guid"),
               tuple(binding["level"].get("pathOrdinals", [])))
        binds_by_level.setdefault(key, []).append(decision["decisionId"])
    conflicting = {identifier for ids in binds_by_level.values() if len(ids) > 1 for identifier in ids}
    statuses: dict[str, dict[str, Any]] = {}
    semantic_digests: dict[str, str] = {}
    applied_bindings: list[tuple[str, dict[str, Any]]] = []
    applied_relations: list[tuple[str, str, dict[str, Any]]] = []
    rows_by_level: dict[tuple[object, ...], list[Any]] = {}
    for row in automatic_rows:
        key = (str(row.identity["transaction"].get("path")),
               str(row.identity["transaction"].get("guid")), row.part_type,
               row.level_guid, tuple(row.path_ordinals))
        rows_by_level.setdefault(key, []).append(row)

    for decision in ordered:
        identifier = decision["decisionId"]
        if identifier in cycle_ids:
            statuses[identifier] = {"decisionId": identifier, "status": "conflicting",
                                    "reasonCodes": ["decision-dependency-cycle"]}
            continue
        if identifier in conflicting:
            statuses[identifier] = {"decisionId": identifier, "status": "conflicting",
                                    "reasonCodes": ["table-binding-conflict"]}
            continue
        missing = [item for item in decision["dependsOnDecisionIds"] if item not in decisions_by_id]
        if missing:
            statuses[identifier] = {"decisionId": identifier, "status": "malformed",
                                    "reasonCodes": ["dependency-reference-missing"],
                                    "causingDecisionIds": missing}
            continue
        failed = [item for item in decision["dependsOnDecisionIds"]
                  if statuses.get(item, {}).get("status") != "applied"]
        if failed:
            statuses[identifier] = {"decisionId": identifier, "status": "stale",
                                    "reasonCodes": ["predecessor-not-applied"],
                                    "causingDecisionIds": failed}
            continue
        if decision["type"] in {"resolve-inferred-relation", "reject-inferred-relation"}:
            try:
                scope = decision["scope"]
                if (len(scope["relations"]) != 1 or len(scope["targets"]) != 1
                        or scope["assignments"] or scope["tableBindings"] or scope["newTargets"]):
                    raise DecisionIssue("out-of-scope", "relation-decision-scope-invalid",
                                        "relation decision must name one exact occurrence and one relation")
                target = scope["targets"][0]
                occurrence_rows = [row for row in automatic_rows
                                   if canonical_bytes(row.identity) == canonical_bytes(target)]
                if len(occurrence_rows) != 1:
                    raise DecisionIssue("stale", "relation-target-stale",
                                        "relation decision target is absent or ambiguous in the current snapshot")
                target_row = occurrence_rows[0]
                level_key = (str(target["transaction"].get("path")),
                             str(target["transaction"].get("guid")), target["partType"],
                             target["level"].get("guid"), tuple(target["level"].get("pathOrdinals", [])))
                level = levels_by_key.get(level_key)
                contextual_level = context_levels_by_key.get(level_key)
                if level is None or contextual_level is None:
                    raise DecisionIssue("stale", "relation-target-stale",
                                        "relation decision Level is absent in the current snapshot")
                relation_ref = scope["relations"][0]
                candidates, issues = _relation_candidates_for_attribute(
                    contextual_model, contextual_level, str(target["attribute"].get("guid") or ""))
                if issues or canonical_bytes(relation_ref) not in {canonical_bytes(item) for item in candidates}:
                    raise DecisionIssue("stale", "relation-candidate-stale",
                                        "selected inferred relation is no longer an exact current candidate")
                relation_graph, _ = automatic._table_relation_index(contextual_model)
                source_guid = str(relation_ref["sourceTable"].get("guid"))
                edges = [edge for edge in relation_graph.get(source_guid, [])
                         if str(edge["index"].get("identity")) == relation_ref["indexIdentity"]]
                matching_targets = [edge for edge in edges
                                    if any(table.guid == relation_ref["targetTable"].get("guid")
                                           and table.path == relation_ref["targetTable"].get("path")
                                           for table in edge["targets"])]
                if len(matching_targets) != 1:
                    raise DecisionIssue("stale", "relation-candidate-stale",
                                        "selected relation edge is absent or ambiguous")
                unique_fk_confirmation = (
                    target_row.classification == "unclassified-relation-pending"
                    and set(target_row.reason_codes) == {"inferred-fk-key"}
                    and len(matching_targets[0]["targets"]) == 1
                )
                if (decision["type"] == "resolve-inferred-relation"
                        and len(matching_targets[0]["targets"]) < 2
                        and not unique_fk_confirmation):
                    raise DecisionIssue("out-of-scope", "relation-resolution-not-required",
                                        "resolve-inferred-relation requires an ambiguous target or one exact inferred FK-key candidate")
                expected_scope = {"targets": [target], "assignments": [], "tableBindings": [],
                                  "relations": [relation_ref], "newTargets": []}
                if canonical_bytes(expected_scope) != canonical_bytes(scope):
                    raise DecisionIssue("out-of-scope", "relation-decision-scope-mismatch",
                                        "relation decision scope must match the exact displayed relation")
                if sorted(target_row.reason_codes) != decision["reasonCodes"]:
                    raise DecisionIssue("stale", "decision-reasons-stale",
                                        "relation reasonCodes no longer match automatic analysis")
                proof_files = _transaction_proof_files(contextual_model, contextual_level)
                inventory_digest = _transaction_inventory_digest(
                    front_id, manifest["ruleVersion"], decision, model, level,
                    semantic_digests, decisions_by_id)
                expected_digests = {
                    "inventoryDigest": inventory_digest,
                    "proofFiles": proof_files,
                    "proofDigest": _proof_digest(proof_files),
                    "deltaDigest": _delta_digest(delta_root, proof_files, scope),
                }
                mismatches = [name for name, expected in expected_digests.items()
                              if canonical_bytes(decision[name]) != canonical_bytes(expected)]
                if mismatches:
                    raise DecisionIssue("stale", "decision-proof-stale",
                                        f"relation proof or semantic inventory is stale: {', '.join(mismatches)}")
                statuses[identifier] = {"decisionId": identifier, "status": "applied",
                                        "reasonCodes": [], "actor": decision["actor"],
                                        "approvedAt": decision["approvedAt"],
                                        "approvalReceipt": decision["approvalReceipt"]}
                semantic_digests[identifier] = _semantic_decision_digest(
                    front_id, manifest["ruleVersion"], decision)
                applied_relations.append((identifier, decision["type"], relation_ref))
            except DecisionIssue as exc:
                statuses[identifier] = {"decisionId": identifier, "status": exc.status,
                                        "reasonCodes": [exc.reason_code], "detail": str(exc)}
            except (OperationalError, OSError, ValueError, KeyError) as exc:
                statuses[identifier] = {"decisionId": identifier, "status": "stale",
                                        "reasonCodes": ["decision-validation-failed"], "detail": str(exc)}
            continue
        if decision["type"] != "bind-table-group":
            statuses[identifier] = {"decisionId": identifier, "status": "ineligible",
                                    "reasonCodes": ["decision-type-not-supported-by-transaction-route"]}
            continue
        try:
            scope = decision["scope"]
            if (len(scope["tableBindings"]) != 1 or scope["assignments"] or scope["relations"]
                    or scope["newTargets"]):
                raise DecisionIssue("out-of-scope", "table-binding-scope-invalid",
                                    "bind-table-group must name one Table binding and no unrelated effects")
            binding = scope["tableBindings"][0]
            level_key = (str(binding["transaction"].get("path")),
                         str(binding["transaction"].get("guid")), binding["partType"],
                         binding["level"].get("guid"),
                         tuple(binding["level"].get("pathOrdinals", [])))
            level = levels_by_key.get(level_key)
            contextual_level = context_levels_by_key.get(level_key)
            if level is None or contextual_level is None:
                raise DecisionIssue("stale", "table-binding-level-stale",
                                    "binding Level is absent from the current Transaction snapshot")
            if level.association_status not in {"table-binding-proposed", "table-binding-ambiguous"}:
                raise DecisionIssue("out-of-scope", "table-binding-not-required",
                                    "the current Level association is already resolved or cannot be bound")
            expected_binding = next((item for item in level.table_candidates
                                     if item.guid == binding["table"].get("guid")
                                     and item.path == binding["table"].get("path")
                                     and item.name == binding["table"].get("name")), None)
            if expected_binding is None:
                raise DecisionIssue("out-of-scope", "table-binding-candidate-not-current",
                                    "selected Table is not a current PK-compatible candidate")
            expected_binding_ref = _transaction_binding_ref(model, level, expected_binding)
            if canonical_bytes(expected_binding_ref) != canonical_bytes(binding):
                raise DecisionIssue("out-of-scope", "table-binding-scope-mismatch",
                                    "binding does not match the current Level/Table view")
            level_rows = rows_by_level.get(level_key, [])
            expected_scope = _transaction_scope(expected_binding_ref, level_rows)
            if canonical_bytes(expected_scope) != canonical_bytes(scope):
                raise DecisionIssue("out-of-scope", "table-binding-target-scope-mismatch",
                                    "binding must cover every current occurrence in the displayed Level")
            expected_reasons = sorted({code for row in level_rows for code in row.reason_codes
                                       if code.startswith("table-binding-")})
            if expected_reasons != decision["reasonCodes"]:
                raise DecisionIssue("stale", "decision-reasons-stale",
                                    "binding reasonCodes no longer match automatic analysis")
            proof_files = _transaction_proof_files(model, level)
            inventory_digest = _transaction_inventory_digest(
                front_id, manifest["ruleVersion"], decision, model, level,
                semantic_digests, decisions_by_id)
            expected_digests = {
                "inventoryDigest": inventory_digest,
                "proofFiles": proof_files,
                "proofDigest": _proof_digest(proof_files),
                    "deltaDigest": _delta_digest(delta_root, proof_files, scope),
            }
            mismatches = [name for name, expected in expected_digests.items()
                          if canonical_bytes(decision[name]) != canonical_bytes(expected)]
            if mismatches:
                raise DecisionIssue("stale", "decision-proof-stale",
                                    f"binding proof or semantic inventory is stale: {', '.join(mismatches)}")
            _apply_table_binding_context(contextual_model, contextual_levels, binding)
            status = {"decisionId": identifier, "status": "applied", "reasonCodes": [],
                      "actor": decision["actor"], "approvedAt": decision["approvedAt"],
                      "approvalReceipt": decision["approvalReceipt"]}
            statuses[identifier] = status
            semantic_digests[identifier] = _semantic_decision_digest(
                front_id, manifest["ruleVersion"], decision)
            applied_bindings.append((identifier, binding))
        except DecisionIssue as exc:
            statuses[identifier] = {"decisionId": identifier, "status": exc.status,
                                    "reasonCodes": [exc.reason_code], "detail": str(exc)}
        except (OperationalError, OSError, ValueError, KeyError) as exc:
            statuses[identifier] = {"decisionId": identifier, "status": "stale",
                                    "reasonCodes": ["decision-validation-failed"], "detail": str(exc)}

    for identifier, status in list(statuses.items()):
        if status.get("status") != "applied":
            continue
        decision = decisions_by_id[identifier]
        for proof in decision["proofFiles"]:
            try:
                proof_root = (corpus_root if proof["rootKind"] == "corpus" else delta_root)
                current = (hashlib.sha256(_relative_path(proof_root, proof["path"]).read_bytes()).hexdigest()
                           if proof_root is not None else "")
            except (OperationalError, OSError, ValueError):
                current = ""
            if current != proof["sha256"]:
                status["status"] = "stale"
                status["reasonCodes"] = ["proof-changed-during-validation"]
                break
    changed = True
    while changed:
        changed = False
        for decision in ordered:
            status = statuses.get(decision["decisionId"], {})
            if status.get("status") == "applied":
                failed = [item for item in decision["dependsOnDecisionIds"]
                          if statuses.get(item, {}).get("status") != "applied"]
                if failed:
                    status["status"] = "stale"
                    status["reasonCodes"] = ["predecessor-not-applied"]
                    status["causingDecisionIds"] = failed
                    changed = True
    applied_ids = {identifier for identifier, status in statuses.items()
                   if status.get("status") == "applied"}
    return {"manifest": manifest,
            "decisionResults": [statuses.get(item["decisionId"],
                                {"decisionId": item["decisionId"], "status": "malformed",
                                 "reasonCodes": ["decision-not-processed"]})
                                for item in manifest["decisions"]],
            "statuses": statuses,
            "appliedBindings": [(identifier, binding) for identifier, binding in applied_bindings
                                if identifier in applied_ids],
            "appliedRelations": [(action, relation_ref) for identifier, action, relation_ref in applied_relations
                                 if statuses.get(identifier, {}).get("status") == "applied"],
            "appliedRelationTargets": [target
                                       for identifier, action, relation_ref in applied_relations
                                       if statuses.get(identifier, {}).get("status") == "applied"
                                       for target in decisions_by_id[identifier]["scope"]["targets"]]}


def analyze_transaction(transaction_path: Path, corpus_root: Path, *, front_id: str | None = None,
                        decision_raw: bytes | None = None,
                        include_request: bool = False,
                        delta_root: Path | None = None,
                        model_root: Path | None = None,
                        root_kinds_by_path: dict[str, str] | None = None,
                        source_roots: dict[str, Path] | None = None,
                        display_path: Path | None = None) -> dict[str, Any]:
    corpus_root = corpus_root.resolve(strict=True)
    transaction_path = transaction_path.resolve(strict=True)
    model, contextual_model, automatic_rows, contextual_levels = _transaction_snapshot(
        transaction_path, (model_root or corpus_root).resolve(strict=True),
        root_kinds_by_path=root_kinds_by_path,
        source_roots=source_roots or {"corpus": corpus_root,
                                     **({"delta": delta_root.resolve(strict=True)} if delta_root else {})})
    transaction = next(item for item in model.transactions
                       if Path(str(item["_absolutePath"])).resolve() == transaction_path)
    automatic_levels = [item for item in model.levels
                        if item.transaction.get("path") == transaction.get("path")
                        and item.transaction.get("guid") == transaction.get("guid")]
    identifier = front_id or corpus_root.name
    request = _transaction_decision_request(model, automatic_levels, automatic_rows,
                                            corpus_root, identifier, delta_root)
    decision_summary: dict[str, Any] | None = None
    manifest_error: str | None = None
    if decision_raw is not None:
        try:
            decision_summary = _apply_transaction_decisions(
                decision_raw, model, contextual_model, automatic_levels,
                contextual_levels, automatic_rows, corpus_root, identifier, delta_root)
        except (OperationalError, ValueError, OSError, CanonicalJsonError) as exc:
            manifest_error = str(exc)
    applied_relations = decision_summary.get("appliedRelations", []) if decision_summary else []
    applied_relation_targets = {canonical_bytes(item) for item in
                                decision_summary.get("appliedRelationTargets", [])} if decision_summary else set()
    contextual_rows = _classify_transaction_context(contextual_model, contextual_levels, applied_relations)
    contextual_by_identity: dict[bytes, list[Any]] = {}
    for row in contextual_rows:
        contextual_by_identity.setdefault(canonical_bytes(row.identity), []).append(row)
    applied_bindings = decision_summary.get("appliedBindings", []) if decision_summary else []
    applied_level_keys = {
        (str(binding["transaction"].get("path")), str(binding["transaction"].get("guid")),
         binding["partType"], binding["level"].get("guid"),
         tuple(binding["level"].get("pathOrdinals", []))): identifier
        for identifier, binding in applied_bindings
    }
    result_rows: list[dict[str, Any]] = []
    requested_targets: set[bytes] = set()
    for request_item in request["requests"] if include_request else []:
        requested_targets.update(canonical_bytes(item) for item in request_item["scope"]["targets"])
    if decision_summary:
        for decision in decision_summary["manifest"]["decisions"]:
            requested_targets.update(canonical_bytes(item) for item in decision["scope"]["targets"])
    status_by_target: dict[bytes, list[dict[str, Any]]] = {}
    applied_target_types: set[tuple[bytes, str]] = set()
    if decision_summary:
        for decision in decision_summary["manifest"]["decisions"]:
            status = decision_summary["statuses"].get(decision["decisionId"],
                                                       {"decisionId": decision["decisionId"],
                                                        "status": "malformed"})
            for target in decision["scope"]["targets"]:
                status_by_target.setdefault(canonical_bytes(target), []).append(status)
                if status.get("status") == "applied":
                    applied_target_types.add((canonical_bytes(target), decision["type"]))
    for row in automatic_rows:
        key_bytes = canonical_bytes(row.identity)
        context_matches = contextual_by_identity.get(key_bytes, [])
        contextual_row = context_matches.pop(0) if context_matches else None
        level_key = (str(row.identity["transaction"].get("path")),
                     str(row.identity["transaction"].get("guid")), row.part_type,
                     row.level_guid, tuple(row.path_ordinals))
        binding_decision_id = applied_level_keys.get(level_key)
        applied_here = binding_decision_id is not None or key_bytes in applied_relation_targets
        auto_payload = automatic.attribute_writability_to_gate_row(row)
        context_payload = (automatic.attribute_writability_to_gate_row(contextual_row)
                           if applied_here and contextual_row is not None else None)
        effective = context_payload if context_payload is not None else auto_payload
        decision_results = status_by_target.get(key_bytes, [])
        decision_ids = sorted({item["decisionId"] for item in decision_results})
        decision_states = {str(item.get("status", "malformed")) for item in decision_results}
        decision_state = ("applied" if applied_here else
                          next(iter(sorted(decision_states)), "pending" if key_bytes in requested_targets else "none"))
        applied_decision_ids = {item["decisionId"] for item in decision_results
                                if item.get("status") == "applied"}
        pending = [item for item in request["requests"]
                   if item["decisionId"] not in applied_decision_ids
                   and (key_bytes, item["type"]) not in applied_target_types
                   and key_bytes in {canonical_bytes(target) for target in item["scope"]["targets"]}]
        result_rows.append({**auto_payload,
                            "contextualAnalysis": context_payload,
                            "effectiveWritable": effective["writable"],
                            "effectiveCanAssignInNew": effective["canAssignInNew"],
                            "decisionState": decision_state,
                            "decisionIds": decision_ids or ([binding_decision_id] if binding_decision_id else []),
                            "decisionReceipts": [{key: item[key] for key in (
                                "decisionId", "actor", "approvedAt", "approvalReceipt") if key in item}
                                for item in decision_results if item.get("status") == "applied"],
                            "pendingDecisions": pending})
    invalid_states = {"malformed", "stale", "out-of-scope", "ineligible", "conflicting"}
    decision_results = decision_summary["decisionResults"] if decision_summary else []
    invalid_decision = manifest_error is not None or any(item.get("status") in invalid_states
                                                         for item in decision_results)
    if not include_request and decision_raw is None:
        operational_status = "not-requested"
    elif invalid_decision:
        operational_status = "blocked"
    elif any(item.get("status") == "pending" for item in decision_results) or (
            include_request and request["requests"]):
        operational_status = "attention"
    else:
        scoped = [item for item in result_rows if canonical_bytes(item["identity"]) in requested_targets]
        operational_status = ("blocked" if any(item["effectiveWritable"] is not True for item in scoped)
                              else "attention" if applied_bindings else "clear")
    meta = automatic._read_xml_root(transaction_path)
    return {"status": "pass", "operationalStatus": operational_status,
            "transactionName": str(transaction.get("name")),
            "transactionGuid": transaction.get("guid"),
            "transactionPath": str((display_path or transaction_path).resolve()),
            "coverage": automatic._coverage_from_rows(automatic_rows),
            "writabilityRuleVersion": automatic.WRITABILITY_RULE_VERSION,
            "levelAttributes": result_rows,
            "decisionResults": decision_results,
            "decisionManifestError": manifest_error,
            "decisionRequest": request if include_request else None,
            "inventoryStatus": "partial" if model.errors else "complete-in-model",
            "inventoryErrors": sorted(set(model.errors))}


def _decision_request(results: list[dict[str, Any]], corpus_root: Path,
                      delta_root: Path | None, front_id: str) -> dict[str, Any]:
    requests: list[dict[str, Any]] = []
    templates: list[dict[str, Any]] = []
    choice_bundles: list[dict[str, Any]] = []
    rule_version = automatic.WRITABILITY_RULE_VERSION

    def make_template(decision_type: str, procedure: dict[str, Any], block: dict[str, Any],
                      group: dict[str, Any], scope: dict[str, Any], reason_codes: list[str],
                      decision_id: str, dependencies: list[str], predecessor_digests: dict[str, str]) -> dict[str, Any]:
        proof_files = _proof_files_for_targets(corpus_root, delta_root, procedure, [block])
        template: dict[str, Any] = {
            "decisionId": decision_id,
            "type": decision_type,
            "actor": "PREENCHER",
            "approvedAt": "PREENCHER RFC3339",
            "approvalReceipt": {"reference": "PREENCHER", "text": "PREENCHER"},
            "justification": "PREENCHER",
            "evidenceReferences": [],
            "reasonCodes": reason_codes,
            "dependsOnDecisionIds": sorted(dependencies),
            "scope": scope,
            "inventoryDigest": "",
            "proofFiles": proof_files,
            "proofDigest": _proof_digest(proof_files),
            "deltaDigest": _delta_digest(delta_root, proof_files, scope),
        }
        inventory, _, _, _ = _decision_digests(
            template, front_id, rule_version, [block], corpus_root, delta_root,
            procedure, predecessor_digests)
        template["inventoryDigest"] = inventory
        return template

    for procedure in results:
        for block in procedure.get("newBlocks", []):
            if block["candidateState"] == "new-extraction-incomplete" or block["coverage"] != "complete-in-model":
                continue
            groups = block["candidates"]
            if not groups:
                continue
            is_ambiguous = len(groups) > 1
            candidate_groups = [group for group in groups if not is_ambiguous or group.get("selectable")]
            for group in candidate_groups:
                bundle: list[dict[str, Any]] = []
                predecessor_digests: dict[str, str] = {}
                selection_id: str | None = None
                table_id = str(group["table"].get("guid", ""))
                if is_ambiguous:
                    new_target = group.get("newTargetRef") or _group_new_target(block, group)
                    scope = _expected_scope("select-new-target", new_target)
                    selection_id = (f"select-new-target-{block['block']['snippetSha256'][:10]}-"
                                    f"{block['block']['start']}-{table_id.replace('-', '')[:8]}")
                    selection = make_template("select-new-target", procedure, block, group, scope, [],
                                              selection_id, [], {})
                    bundle.append(selection)
                    predecessor_digests[selection_id] = _semantic_decision_digest(
                        front_id, rule_version, selection)
                    requests.append({"decisionId": selection_id, "type": "select-new-target",
                                     "block": block["block"], "table": group["table"],
                                     "scope": scope, "inventoryDigest": selection["inventoryDigest"],
                                     "proofFiles": selection["proofFiles"],
                                     "proofDigest": selection["proofDigest"],
                                     "deltaDigest": selection["deltaDigest"]})
                for target in group["assignmentTargets"]:
                    scope, reason_codes, eligible = _affirm_scope(block, group, target["assignment"])
                    if not eligible:
                        continue
                    assignment = target["assignment"]
                    affirm_id = (f"affirm-writable-target-{block['block']['snippetSha256'][:10]}-"
                                 f"{block['block']['start']}-{assignment['start']}-"
                                 f"{str(assignment['attribute']['guid']).replace('-', '')[:8]}")
                    if is_ambiguous:
                        affirm_id += f"-{table_id.replace('-', '')[:8]}"
                    dependencies = [selection_id] if selection_id else []
                    affirm = make_template("affirm-writable-target", procedure, block, group, scope,
                                           reason_codes, affirm_id, dependencies, predecessor_digests)
                    bundle.append(affirm)
                    requests.append({"decisionId": affirm_id, "type": "affirm-writable-target",
                                     "block": block["block"], "table": group["table"],
                                     "assignment": assignment, "reasonCodes": reason_codes,
                                     "dependsOnDecisionIds": dependencies,
                                     "scope": scope, "inventoryDigest": affirm["inventoryDigest"],
                                     "proofFiles": affirm["proofFiles"],
                                     "proofDigest": affirm["proofDigest"],
                                     "deltaDigest": affirm["deltaDigest"]})
                if is_ambiguous:
                    choice_bundles.append({"block": block["block"], "table": group["table"],
                                           "decisionTemplates": bundle})
                else:
                    templates.extend(bundle)
    return {
        "kind": "gx-writability-front-decision-request", "schemaVersion": 1,
        "frontId": front_id, "corpusRoot": str(corpus_root.resolve()),
        "deltaRoot": str(delta_root.resolve()) if delta_root else None,
        "ruleVersion": rule_version, "requests": requests,
        "decisionChoices": choice_bundles,
        "manifestTemplate": {"kind": "gx-writability-front-decisions", "schemaVersion": 1,
                             "frontId": front_id, "corpusRoot": str(corpus_root.resolve()),
                             "deltaRoot": str(delta_root.resolve()) if delta_root else None,
                             "ruleVersion": rule_version, "decisions": templates},
    }


def _set_decision_diagnostics(results: list[dict[str, Any]], manifest: dict[str, Any],
                              statuses: dict[str, dict[str, Any]],
                              selected: dict[tuple[str, str, str, str, int, int], tuple[str, str]]) -> None:
    decisions_by_id = {item["decisionId"]: item for item in manifest["decisions"]}
    for procedure, block in _all_blocks(results):
        key = _block_key(block)
        if key in selected:
            decision_id, table_guid = selected[key]
            block["selectedTableGuid"] = table_guid
            block["decisionIds"] = [decision_id]
            block["decisionState"] = "applied"
            block["pendingDecisions"] = []
            chosen = next((group for group in block["candidates"]
                           if group["table"].get("guid") == table_guid), None)
            for target in block["assignments"]:
                target["decisionState"] = "applied"
                target["decisionIds"] = [decision_id]
            if chosen:
                for assignment_group in chosen["assignmentTargets"]:
                    for occurrence in assignment_group["occurrences"]:
                        occurrence.setdefault("effectiveWritable", occurrence["writable"])
                        occurrence.setdefault("effectiveCanAssignInNew", occurrence["canAssignInNew"])
                        occurrence["decisionState"] = "applied"
                        occurrence["decisionIds"] = [decision_id]
        block.setdefault("decisionResults", [])
        for decision_id, status in statuses.items():
            decision = decisions_by_id[decision_id]
            scope = decision["scope"]
            references = [(assignment.get("object"), assignment.get("sourceSha256"))
                          for assignment in scope.get("assignments", [])]
            references.extend((target.get("block", {}).get("object"),
                               target.get("block", {}).get("sourceSha256"))
                              for target in scope.get("newTargets", []))
            affected = {canonical_bytes(item) for item in scope.get("targets", [])}
            has_block_scope = any(object_ref is not None
                                  and canonical_bytes(object_ref) == canonical_bytes(block["block"]["object"])
                                  and source_sha == block["block"]["sourceSha256"]
                                  for object_ref, source_sha in references)
            has_occurrence_scope = any(
                canonical_bytes(occurrence["occurrence"]) in affected
                for group in block["candidates"]
                for assignment_target in group["assignmentTargets"]
                for occurrence in assignment_target["occurrences"]
            )
            has_binding_scope = any(
                canonical_bytes(binding.get("transaction")) == canonical_bytes(view.get("transaction"))
                and binding.get("partType") == view.get("partType")
                and canonical_bytes(binding.get("level")) == canonical_bytes(view.get("level"))
                and binding.get("table", {}).get("guid") == group.get("table", {}).get("guid")
                and binding.get("table", {}).get("path") == group.get("table", {}).get("path")
                for binding in scope.get("tableBindings", [])
                for group in block["candidates"]
                for view in group.get("views", [])
            )
            if not (has_block_scope or has_occurrence_scope or has_binding_scope):
                continue
            block["decisionResults"].append(status)
            state = str(status.get("status", "malformed"))
            block.setdefault("decisionIds", []).append(decision_id)
            block["decisionIds"] = sorted(set(block["decisionIds"]))
            if state == "applied":
                block["decisionState"] = "applied"
            elif block.get("decisionState") != "applied":
                block["decisionState"] = state
            for group in block["candidates"]:
                for assignment_target in group["assignmentTargets"]:
                    for occurrence in assignment_target["occurrences"]:
                        if canonical_bytes(occurrence["occurrence"]) in affected:
                            occurrence["decisionState"] = state
                            occurrence["decisionIds"] = sorted(set(
                                [*occurrence.get("decisionIds", []), decision_id]))


def _apply_transaction_context_to_new_results(
    manifest: dict[str, Any], results: list[dict[str, Any]], corpus_root: Path,
    delta_root: Path | None,
) -> tuple[dict[str, dict[str, Any]], dict[str, str]]:
    transaction_types = {"bind-table-group", "resolve-inferred-relation", "reject-inferred-relation"}
    decisions = [item for item in manifest["decisions"] if item["type"] in transaction_types]
    if not decisions:
        return {}, {}
    decisions_by_id = {item["decisionId"]: item for item in manifest["decisions"]}
    by_transaction: dict[bytes, list[dict[str, Any]]] = {}
    transaction_refs: dict[bytes, dict[str, Any]] = {}
    for decision in decisions:
        scope = decision["scope"]
        refs = (scope["tableBindings"] if decision["type"] == "bind-table-group"
                else scope["targets"])
        transaction_ref = refs[0]["transaction"] if refs and decision["type"] != "bind-table-group" else (
            refs[0]["transaction"] if refs else None)
        if transaction_ref is None:
            continue
        key = canonical_bytes(transaction_ref)
        by_transaction.setdefault(key, []).append(decision)
        transaction_refs[key] = transaction_ref

    statuses: dict[str, dict[str, Any]] = {}
    semantic_digests: dict[str, str] = {}
    row_context: dict[bytes, dict[str, Any]] = {}
    applied_bindings: list[dict[str, Any]] = []
    overlay_context: Any = tempfile.TemporaryDirectory(prefix="gx-writability-new-context-") if delta_root else None
    try:
        model_root = Path(overlay_context.name) if overlay_context else corpus_root
        root_kinds = _overlay_model_corpus(corpus_root, delta_root, model_root) if delta_root else None
        source_roots = {"corpus": corpus_root.resolve(strict=True)}
        if delta_root:
            source_roots["delta"] = delta_root.resolve(strict=True)
        for key, transaction_decisions in by_transaction.items():
            group_ids = {item["decisionId"] for item in transaction_decisions}
            unsupported: set[str] = set()
            for decision in transaction_decisions:
                pending = list(decision["dependsOnDecisionIds"])
                visited: set[str] = set()
                while pending:
                    dependency = pending.pop()
                    if dependency in visited:
                        continue
                    visited.add(dependency)
                    dependency_decision = decisions_by_id.get(dependency)
                    if dependency_decision is None or dependency not in group_ids:
                        unsupported.add(decision["decisionId"])
                        break
                    pending.extend(dependency_decision["dependsOnDecisionIds"])
            active = [item for item in transaction_decisions if item["decisionId"] not in unsupported]
            for identifier in unsupported:
                statuses[identifier] = {"decisionId": identifier, "status": "stale",
                                        "reasonCodes": ["transaction-context-predecessor-out-of-scope"]}
            if not active:
                continue
            transaction_ref = transaction_refs[key]
            root_kind = transaction_ref["rootKind"]
            real_root = corpus_root if root_kind == "corpus" else delta_root
            if real_root is None:
                for decision in active:
                    statuses[decision["decisionId"]] = {
                        "decisionId": decision["decisionId"], "status": "stale",
                        "reasonCodes": ["transaction-context-root-unavailable"],
                    }
                continue
            try:
                _relative_path(real_root, transaction_ref["path"])
                transaction_path = _relative_path(model_root, transaction_ref["path"])
                submanifest = {**manifest, "decisions": active}
                analysis = analyze_transaction(
                    transaction_path, corpus_root, front_id=manifest["frontId"],
                    decision_raw=canonical_bytes(submanifest), delta_root=delta_root,
                    model_root=model_root, root_kinds_by_path=root_kinds,
                    source_roots=source_roots,
                )
            except (OperationalError, OSError, ValueError, KeyError, CanonicalJsonError) as exc:
                for decision in active:
                    statuses[decision["decisionId"]] = {
                        "decisionId": decision["decisionId"], "status": "stale",
                        "reasonCodes": ["transaction-context-validation-failed"], "detail": str(exc),
                    }
                continue
            for item in analysis.get("decisionResults", []):
                identifier = item["decisionId"]
                statuses[identifier] = item
                if item.get("status") == "applied":
                    decision = decisions_by_id[identifier]
                    semantic_digests[identifier] = _semantic_decision_digest(
                        manifest["frontId"], manifest["ruleVersion"], decision)
            for row in analysis.get("levelAttributes", []):
                if row.get("decisionState") == "applied" and row.get("contextualAnalysis") is not None:
                    row_context.setdefault(canonical_bytes(row["identity"]), row)
            for decision in active:
                if (decision["type"] == "bind-table-group"
                        and statuses.get(decision["decisionId"], {}).get("status") == "applied"):
                    applied_bindings.append(decision["scope"]["tableBindings"][0])

        for _procedure, block in _all_blocks(results):
            for group in block.get("candidates", []):
                kept_views: list[dict[str, Any]] = []
                for view in group.get("views", []):
                    matching_bindings = [binding for binding in applied_bindings
                                         if canonical_bytes(binding["transaction"]) == canonical_bytes(view["transaction"])
                                         and binding["partType"] == view["partType"]
                                         and canonical_bytes(binding["level"]) == canonical_bytes(view["level"])]
                    if matching_bindings:
                        if not any(binding["table"].get("guid") == group["table"].get("guid")
                                   and binding["table"].get("path") == group["table"].get("path")
                                   for binding in matching_bindings):
                            continue
                        view["associationStatus"] = "resolved-level-type-and-table-key"
                    kept_views.append(view)
                group["views"] = kept_views
                for assignment_target in group.get("assignmentTargets", []):
                    for occurrence in assignment_target.get("occurrences", []):
                        context = row_context.get(canonical_bytes(occurrence["occurrence"]))
                        if context is None:
                            continue
                        occurrence["contextualAnalysis"] = context["contextualAnalysis"]
                        occurrence["effectiveWritable"] = context["effectiveWritable"]
                        occurrence["effectiveCanAssignInNew"] = context["effectiveCanAssignInNew"]
                        occurrence["decisionState"] = context["decisionState"]
                        occurrence["decisionIds"] = context["decisionIds"]
                        occurrence["decisionReceipts"] = context.get("decisionReceipts", [])
                        occurrence["pendingDecisions"] = context.get("pendingDecisions", [])
                group["selectable"], group["selectionReasonCodes"] = _selection_eligibility(
                    group["views"], group.get("assignmentTargets", []))
            block["candidates"] = [group for group in block.get("candidates", []) if group["views"]]
            if block.get("candidateState") != "new-extraction-incomplete":
                block["candidateState"] = ("new-target-ambiguous" if len(block["candidates"]) > 1
                                            else "candidate" if block["candidates"]
                                            else "new-target-unresolved")
    finally:
        if overlay_context is not None:
            overlay_context.cleanup()
    return statuses, semantic_digests


def _apply_decisions(manifest_raw: bytes, results: list[dict[str, Any]], corpus_root: Path,
                     delta_root: Path | None) -> dict[str, Any]:
    manifest = _validate_manifest(manifest_raw)
    if Path(manifest["corpusRoot"]).resolve(strict=True) != corpus_root.resolve(strict=True):
        raise OperationalError("decision manifest corpusRoot does not match the evaluated corpus")
    expected_delta = delta_root.resolve(strict=True) if delta_root else None
    declared_delta = Path(manifest["deltaRoot"]).resolve(strict=True) if manifest["deltaRoot"] else None
    if declared_delta != expected_delta:
        raise OperationalError("decision manifest deltaRoot does not match the evaluated front")
    if manifest["ruleVersion"] != automatic.WRITABILITY_RULE_VERSION:
        raise OperationalError("decision manifest ruleVersion is stale")
    original_results = copy.deepcopy(results) if manifest["decisions"] else None
    ordered, cycle_ids = _topological_decisions(manifest["decisions"])
    decisions_by_id = {item["decisionId"]: item for item in manifest["decisions"]}
    front_id = manifest["frontId"]
    statuses, semantic_digests = _apply_transaction_context_to_new_results(
        manifest, results, corpus_root, delta_root)
    transaction_decision_ids = {item["decisionId"] for item in manifest["decisions"]
                                if item["type"] in {"bind-table-group", "resolve-inferred-relation",
                                                    "reject-inferred-relation"}}
    selected: dict[tuple[str, str, str, str, int, int], tuple[str, str]] = {}
    staged_affirms: list[tuple[dict[str, Any], tuple[dict[str, Any], dict[str, Any]], dict[str, Any], dict[str, Any]]] = []
    selections_per_block: dict[tuple[str, str, str, str, int, int], list[tuple[str, str]]] = {}
    for decision in ordered:
        if decision["type"] == "select-new-target":
            for target in decision["scope"]["newTargets"]:
                current = _find_current_block(results, target["block"])
                if current:
                    selections_per_block.setdefault(_block_key(current[1]), []).append(
                        (decision["decisionId"], str(target["table"].get("guid"))))
    conflicts = {key for key, values in selections_per_block.items()
                 if len({item[0] for item in values}) > 1 or len({item[1] for item in values}) > 1}
    for decision in ordered:
        identifier = decision["decisionId"]
        if identifier in transaction_decision_ids:
            continue
        if identifier in cycle_ids:
            statuses[identifier] = {"decisionId": identifier, "status": "conflicting",
                                    "reasonCodes": ["decision-dependency-cycle"]}
            continue
        missing_dependencies = [dep for dep in decision["dependsOnDecisionIds"]
                                if dep not in {item["decisionId"] for item in manifest["decisions"]}]
        if missing_dependencies:
            statuses[identifier] = {"decisionId": identifier, "status": "malformed",
                                    "reasonCodes": ["dependency-reference-missing"],
                                    "causingDecisionIds": missing_dependencies}
            continue
        failed_predecessors = [dep for dep in decision["dependsOnDecisionIds"]
                               if statuses.get(dep, {}).get("status") != "applied"]
        if failed_predecessors:
            statuses[identifier] = {"decisionId": identifier, "status": "stale",
                                    "reasonCodes": ["predecessor-not-applied"],
                                    "causingDecisionIds": failed_predecessors}
            continue
        if decision["type"] not in {"select-new-target", "affirm-writable-target"}:
            statuses[identifier] = {"decisionId": identifier, "status": "ineligible",
                                    "reasonCodes": ["decision-type-not-supported-by-current-operational-route"]}
            continue
        try:
            blocks: list[dict[str, Any]] = []
            if decision["type"] == "select-new-target":
                targets = decision["scope"]["newTargets"]
                if not targets:
                    raise OperationalError("selection decision has no target blocks")
                built_scopes: list[dict[str, Any]] = []
                current_groups: list[tuple[dict[str, Any], dict[str, Any], dict[str, Any]]] = []
                for target in targets:
                    current = _find_current_block(results, target["block"])
                    if current is None:
                        raise DecisionIssue("stale", "decision-target-stale",
                                            "selection block is stale or out of scope")
                    procedure, block = current
                    if _block_key(block) in conflicts:
                        raise DecisionIssue("conflicting", "decision-selection-conflict",
                                            "conflicting New Table selections target the same block")
                    if block["candidateState"] == "new-extraction-incomplete" or block["coverage"] != "complete-in-model":
                        raise DecisionIssue("ineligible", "decision-target-incomplete",
                                            "selection block has incomplete extraction or inventory")
                    if len(block["candidates"]) < 2:
                        raise DecisionIssue("out-of-scope", "selection-not-required",
                                            "select-new-target is out of scope when the physical Table is already unique")
                    table_guid = target["table"].get("guid")
                    matches = [group for group in block["candidates"] if group["table"].get("guid") == table_guid]
                    if len(matches) != 1:
                        raise DecisionIssue("out-of-scope", "selection-candidate-not-current",
                                            "selected physical Table is not a current candidate")
                    if not matches[0].get("selectable"):
                        raise DecisionIssue("ineligible", "selection-candidate-ineligible",
                                            "selected physical Table has a technical or coverage gap")
                    group = matches[0]
                    expected_target = group.get("newTargetRef") or _group_new_target(block, group)
                    if canonical_bytes(expected_target) != canonical_bytes(target):
                        raise DecisionIssue("out-of-scope", "selection-scope-mismatch",
                                            "selection does not map the complete current assignment set")
                    built_scopes.append(_expected_scope("select-new-target", expected_target))
                    blocks.append(block)
                    current_groups.append((procedure, block, group))
                combined = {"targets": [], "assignments": [], "tableBindings": [], "relations": [], "newTargets": []}
                for scope in built_scopes:
                    for field in combined:
                        combined[field].extend(scope[field])
                if canonical_bytes(combined) != canonical_bytes(decision["scope"]):
                    raise DecisionIssue("out-of-scope", "selection-scope-mismatch",
                                        "selection scope contains missing, extra, or reordered targets")
                if decision["reasonCodes"]:
                    raise DecisionIssue("out-of-scope", "selection-reason-scope-invalid",
                                        "select-new-target must not replace automatic reason codes")
                first_proc = current_groups[0][0]
                inventory, proof_files, proof_digest, delta_digest = _decision_digests(
                    decision, front_id, manifest["ruleVersion"], blocks, corpus_root, delta_root,
                    first_proc, semantic_digests, decisions_by_id)
                mismatches = [name for name, current, expected in (
                    ("inventoryDigest", inventory, decision["inventoryDigest"]),
                    ("proofFiles", proof_files, decision["proofFiles"]),
                    ("proofDigest", proof_digest, decision["proofDigest"]),
                    ("deltaDigest", delta_digest, decision["deltaDigest"])) if current != expected]
                if mismatches:
                    raise DecisionIssue("stale", "decision-proof-stale",
                                        f"selection proof or semantic inventory is stale: {', '.join(mismatches)}")
                status = "applied"
                for procedure, block, group in current_groups:
                    selected[_block_key(block)] = (identifier, str(group["table"]["guid"]))
            else:
                assignments = decision["scope"]["assignments"]
                if len(assignments) != 1 or decision["scope"]["newTargets"]:
                    raise OperationalError("affirm decision must name one exact assignment and no new-target selection")
                assignment = assignments[0]
                matches: list[tuple[dict[str, Any], dict[str, Any], dict[str, Any], dict[str, Any], dict[str, Any]]] = []
                for procedure, block in _all_blocks(results):
                    key = _block_key(block)
                    selected_guid = selected[key][1] if key in selected else None
                    current_groups = [group for group in block["candidates"]
                                      if selected_guid is None or group["table"].get("guid") == selected_guid]
                    for group in current_groups:
                        for target in group["assignmentTargets"]:
                            if canonical_bytes(target["assignment"]) == canonical_bytes(assignment):
                                matches.append((procedure, block, group, target, assignment))
                if len(matches) != 1:
                    raise DecisionIssue("stale", "decision-target-stale",
                                        "affirm assignment is absent or ambiguous in current New analysis")
                procedure, block, group, target, _ = matches[0]
                key = _block_key(block)
                if key in selected:
                    selected_group = next((candidate for candidate in block["candidates"]
                                           if candidate["table"].get("guid") == selected[key][1]), None)
                    if selected_group is None or selected_group["table"].get("guid") != group["table"].get("guid"):
                        raise DecisionIssue("out-of-scope", "affirm-selection-mismatch",
                                            "affirm assignment does not follow the applied Table selection")
                    if selected[key][0] not in decision["dependsOnDecisionIds"]:
                        raise DecisionIssue("malformed", "decision-dependency-omitted",
                                            "affirm must declare its applied Table-selection predecessor")
                elif len(block["candidates"]) != 1:
                    raise DecisionIssue("out-of-scope", "affirm-requires-target-selection",
                                        "ambiguous New origin requires an applied select-new-target predecessor")
                expected_scope, expected_reasons, eligible = _affirm_scope(block, group, assignment)
                if not eligible:
                    raise DecisionIssue("ineligible", "affirm-target-has-nondispensable-cause",
                                        "affirm target has a direct or technical cause that cannot be overridden")
                if canonical_bytes(expected_scope) != canonical_bytes(decision["scope"]):
                    raise DecisionIssue("out-of-scope", "affirm-scope-mismatch",
                                        "affirm scope must cover the exact assignment and all its candidate occurrences")
                if expected_reasons != decision["reasonCodes"]:
                    raise DecisionIssue("stale", "decision-reasons-stale",
                                        "affirm reasonCodes no longer match automatic analysis")
                blocks = [block]
                inventory, proof_files, proof_digest, delta_digest = _decision_digests(
                    decision, front_id, manifest["ruleVersion"], blocks, corpus_root, delta_root,
                    procedure, semantic_digests, decisions_by_id)
                mismatches = [name for name, current, expected in (
                    ("inventoryDigest", inventory, decision["inventoryDigest"]),
                    ("proofFiles", proof_files, decision["proofFiles"]),
                    ("proofDigest", proof_digest, decision["proofDigest"]),
                    ("deltaDigest", delta_digest, decision["deltaDigest"])) if current != expected]
                if mismatches:
                    raise DecisionIssue("stale", "decision-proof-stale",
                                        f"affirm proof or semantic inventory is stale: {', '.join(mismatches)}")
                staged_affirms.append((decision, (procedure, block), group, target))
                status = "applied"
            statuses[identifier] = {"decisionId": identifier, "status": status, "reasonCodes": [],
                                    "actor": decision["actor"], "approvedAt": decision["approvedAt"],
                                    "approvalReceipt": decision["approvalReceipt"]}
            semantic_digests[identifier] = _semantic_decision_digest(front_id, manifest["ruleVersion"], decision)
        except DecisionIssue as exc:
            statuses[identifier] = {"decisionId": identifier, "status": exc.status,
                                    "reasonCodes": [exc.reason_code], "detail": str(exc)}
        except (OperationalError, OSError, ValueError, KeyError) as exc:
            statuses[identifier] = {"decisionId": identifier, "status": "stale",
                                    "reasonCodes": ["decision-validation-failed"], "detail": str(exc)}
    provisionally_applied_ids = {identifier for identifier, status in statuses.items()
                                 if status.get("status") == "applied"}
    # Recheck every input proof after all semantic analysis and provisional effects.
    for identifier, status in list(statuses.items()):
        if status.get("status") != "applied":
            continue
        decision = next(item for item in manifest["decisions"] if item["decisionId"] == identifier)
        for proof in decision["proofFiles"]:
            root = corpus_root if proof["rootKind"] == "corpus" else delta_root
            try:
                current_hash = hashlib.sha256(_relative_path(root, proof["path"]).read_bytes()).hexdigest() if root else ""
            except (OperationalError, OSError, ValueError):
                current_hash = ""
            if current_hash != proof["sha256"]:
                status["status"] = "stale"
                status["reasonCodes"] = ["proof-changed-during-validation"]
                break
    changed = True
    while changed:
        changed = False
        for decision in ordered:
            status = statuses.get(decision["decisionId"], {})
            if status.get("status") == "applied":
                failed = [dep for dep in decision["dependsOnDecisionIds"]
                          if statuses.get(dep, {}).get("status") != "applied"]
                if failed:
                    status["status"] = "stale"
                    status["reasonCodes"] = ["predecessor-not-applied"]
                    status["causingDecisionIds"] = failed
                    changed = True
    final_applied_ids = {identifier for identifier, status in statuses.items()
                         if status.get("status") == "applied"}
    invalidated_ids = provisionally_applied_ids - final_applied_ids
    if invalidated_ids:
        if original_results is None:
            raise OperationalError("decision context cannot be rebuilt without an automatic snapshot")
        rebuilt_results = copy.deepcopy(original_results)
        surviving_decisions = [item for item in manifest["decisions"]
                               if item["decisionId"] in final_applied_ids]
        replay_statuses: dict[str, dict[str, Any]] = {}
        if surviving_decisions:
            replay_manifest = {**manifest, "decisions": surviving_decisions}
            replay = _apply_decisions(canonical_bytes(replay_manifest), rebuilt_results,
                                      corpus_root, delta_root)
            replay_statuses = replay["statuses"]
        final_statuses = dict(statuses)
        for decision in surviving_decisions:
            identifier = decision["decisionId"]
            replay_status = replay_statuses.get(identifier)
            if replay_status is None:
                final_statuses[identifier] = {
                    "decisionId": identifier, "status": "stale",
                    "reasonCodes": ["decision-context-rebuild-incomplete"],
                }
            else:
                final_statuses[identifier] = replay_status
        applied_occurrences: set[bytes] = set()
        for _procedure, block in _all_blocks(rebuilt_results):
            for group in block.get("candidates", []):
                for assignment_target in group.get("assignmentTargets", []):
                    for occurrence in assignment_target.get("occurrences", []):
                        if occurrence.get("decisionState") == "applied":
                            applied_occurrences.add(canonical_bytes(occurrence["occurrence"]))
        _set_decision_diagnostics(rebuilt_results, manifest, final_statuses, {})
        for _procedure, block in _all_blocks(rebuilt_results):
            for group in block.get("candidates", []):
                for assignment_target in group.get("assignmentTargets", []):
                    for occurrence in assignment_target.get("occurrences", []):
                        if canonical_bytes(occurrence["occurrence"]) in applied_occurrences:
                            occurrence["decisionState"] = "applied"
        results[:] = rebuilt_results
        return {"manifest": manifest, "decisionResults": [final_statuses.get(item["decisionId"],
                {"decisionId": item["decisionId"], "status": "malformed",
                 "reasonCodes": ["decision-not-processed"]}) for item in manifest["decisions"]],
                "statuses": final_statuses}
    usable_selected = {key: value for key, value in selected.items()
                       if statuses.get(value[0], {}).get("status") == "applied"}
    _set_decision_diagnostics(results, manifest, statuses, usable_selected)
    for decision, (procedure, block), group, target in staged_affirms:
        if statuses.get(decision["decisionId"], {}).get("status") != "applied":
            continue
        assignment_bytes = canonical_bytes(target["assignment"])
        for occurrence in target["occurrences"]:
            occurrence["contextualAnalysis"] = {key: occurrence[key] for key in (
                "classification", "writable", "canAssignInNew", "reason", "reasonCodes", "coverage", "evidence")}
            occurrence["effectiveWritable"] = True
            occurrence["effectiveCanAssignInNew"] = True
            occurrence["decisionState"] = "applied"
            occurrence["decisionIds"] = [decision["decisionId"]]
        block.setdefault("decisionIds", []).append(decision["decisionId"])
        block.setdefault("decisionReasonCodes", []).append("new-assignment-writable-by-decision")
        block["decisionReasonCodes"] = sorted(set(block["decisionReasonCodes"]))
        block["decisionState"] = "applied"
        block["decisionIds"] = sorted(set(block["decisionIds"]))
    for procedure, block in _all_blocks(results):
        for candidate in block["candidates"]:
            for assignment_target in candidate["assignmentTargets"]:
                for occurrence in assignment_target["occurrences"]:
                    occurrence.setdefault("contextualAnalysis", None)
                    occurrence.setdefault("effectiveWritable", occurrence["writable"])
                    occurrence.setdefault("effectiveCanAssignInNew", occurrence["canAssignInNew"])
                    occurrence.setdefault("decisionState", "none")
                    occurrence.setdefault("decisionIds", [])
                    occurrence.setdefault("pendingDecisions", [])
    return {"manifest": manifest, "decisionResults": [statuses.get(item["decisionId"],
             {"decisionId": item["decisionId"], "status": "malformed", "reasonCodes": ["decision-not-processed"]})
             for item in manifest["decisions"]], "statuses": statuses}


def _candidate_groups(source_root: Path, procedure_path: Path, source_sha: str,
                      source_text: str, blocks: list[NewBlock], root_kind: str = "delta",
                      delta_root: Path | None = None,
                      corpus_reference_root: Path | None = None,
                      root_kinds_by_path: dict[str, str] | None = None) -> dict[str, object]:
    model = automatic._load_writability_model(source_root)
    root_kinds_by_path = root_kinds_by_path or {}
    for transaction in model.transactions:
        transaction["rootKind"] = root_kinds_by_path.get(str(transaction.get("path", "")), "corpus")
    relations, table_views = automatic._table_relation_index(model)
    attrs_by_guid: dict[str, list[automatic._AttributeObject]] = {}
    attrs_by_name: dict[str, list[automatic._AttributeObject]] = {}
    tables_by_guid: dict[str, automatic._TableV2] = {}
    for attribute in model.attributes:
        if attribute.guid:
            attrs_by_guid.setdefault(attribute.guid, []).append(attribute)
        attrs_by_name.setdefault(attribute.name.casefold(), []).append(attribute)
    tables_by_guid = {table.guid: table for table in model.tables if table.guid}
    automatic_rows = automatic.build_corpus_writability(source_root,
                                                          automatic._type_guid(automatic._catalog_types(), "Transaction") or "")
    rows_by_key = {_row_identity_key(row): row for row in automatic_rows}
    procedure_root, procedure_guid, _ = _procedure_source(procedure_path)
    procedure_name = _property_name(procedure_root) or procedure_path.stem
    procedure_absolute = procedure_path.resolve(strict=True)
    corpus_reference_root = corpus_reference_root or source_root
    try:
        procedure_relative = procedure_absolute.relative_to(corpus_reference_root.resolve(strict=True)).as_posix()
        procedure_root_kind = "corpus"
    except ValueError:
        if delta_root is None:
            procedure_relative = procedure_path.name
            procedure_root_kind = root_kind
        else:
            try:
                procedure_relative = procedure_absolute.relative_to(delta_root.resolve(strict=True)).as_posix()
                procedure_root_kind = "delta"
            except ValueError:
                procedure_relative = procedure_path.name
                procedure_root_kind = root_kind
    procedure_ref = _object_ref(procedure_root_kind, procedure_relative, "Procedure", procedure_guid, procedure_name)
    block_results: list[dict[str, object]] = []

    for block in blocks:
        block_text = source_text[block.start:block.end]
        block_ref = {"object": procedure_ref, "partType": SOURCE_PART_TYPE_GUID,
                     "sourceSha256": source_sha, "start": block.start, "end": block.end,
                     "snippetSha256": _sha256(block_text)}
        assignment_records: list[dict[str, object]] = []
        resolved: list[tuple[Assignment, str, dict[str, object] | None, list[str]]] = []
        for assignment in block.assignments:
            matches = attrs_by_name.get(assignment.name.casefold(), [])
            attribute = matches[0] if len(matches) == 1 else None
            issue_codes: list[str] = []
            if not matches:
                issue_codes.append("assignment-attribute-not-found")
            elif len(matches) != 1 or not attribute or not attribute.guid:
                issue_codes.append("assignment-attribute-identity-ambiguous")
            lhs_text = source_text[assignment.start:assignment.end]
            assignment_ref = {
                "object": procedure_ref, "partType": SOURCE_PART_TYPE_GUID,
                "sourceSha256": source_sha, "start": assignment.start, "end": assignment.end,
                "snippetSha256": _sha256(lhs_text),
                "attribute": (_object_ref(root_kinds_by_path.get(attribute.path, "corpus"),
                                           attribute.path, "Attribute", attribute.guid, attribute.name)
                              if attribute else None),
                "operation": "new-assign", "blockStart": block.start, "blockEnd": block.end,
                "blockSha256": _sha256(block_text),
            }
            assignment_records.append({"assignment": assignment_ref, "name": assignment.name,
                                       "line": source_text.count("\n", 0, assignment.start) + 1,
                                       "identityStatus": "resolved" if not issue_codes else "invalid",
                                       "reasonCodes": issue_codes})
            resolved.append((assignment, assignment.name, assignment_ref, issue_codes))

        group_by_guid: dict[str, dict[str, Any]] = {}
        for table in model.tables:
            if not table.guid:
                continue
            views = table_views.get(table.guid, [])
            if not views:
                continue
            per_assignment: list[dict[str, object]] = []
            all_mapped = True
            for assignment, name, assignment_ref, assignment_issues in resolved:
                attribute_candidates = attrs_by_name.get(name.casefold(), [])
                if len(attribute_candidates) != 1 or not attribute_candidates[0].guid:
                    per_assignment.append({"assignment": assignment_ref, "occurrences": [],
                                           "reasonCodes": assignment_issues or ["assignment-attribute-identity-ambiguous"]})
                    all_mapped = False
                    continue
                attr_guid = attribute_candidates[0].guid
                occurrence_candidates: dict[tuple[object, ...], dict[str, object]] = {}
                for view in views:
                    path = tuple(view.path_ordinals)
                    eligible_levels = [candidate for candidate in model.levels
                                       if candidate.transaction.get("path") == view.transaction.get("path")
                                       and candidate.part_type == view.part_type
                                       and path[:len(candidate.path_ordinals)] == tuple(candidate.path_ordinals)]
                    for occurrence_level in eligible_levels:
                        for ref in occurrence_level.attributes:
                            if ref.guid != attr_guid:
                                continue
                            occurrence_key = (occurrence_level.transaction.get("guid"), occurrence_level.part_type,
                                              tuple(occurrence_level.path_ordinals), ref.guid)
                            auto_row = rows_by_key.get(occurrence_key)
                            occurrence_ref = {
                                "transaction": _object_ref(str(occurrence_level.transaction.get("rootKind", "corpus")),
                                                           str(occurrence_level.transaction.get("path", "")),
                                                           "Transaction", occurrence_level.transaction.get("guid"),
                                                           str(occurrence_level.transaction.get("name", ""))),
                                "partType": occurrence_level.part_type,
                                "level": {"guid": occurrence_level.guid,
                                          "pathOrdinals": list(occurrence_level.path_ordinals)},
                                "attribute": _object_ref(root_kinds_by_path.get(attribute_candidates[0].path, "corpus"),
                                                          attribute_candidates[0].path, "Attribute",
                                                          attr_guid, attribute_candidates[0].name),
                            }
                            occurrence_candidates[occurrence_key] = {
                                "occurrence": occurrence_ref,
                                "classification": auto_row.classification if auto_row else "unclassified-evidence-incomplete",
                                "writable": auto_row.writable if auto_row else None,
                                "canAssignInNew": auto_row.can_assign_in_new if auto_row else None,
                                "reason": auto_row.reason if auto_row else "automatic-occurrence-not-found",
                                "reasonCodes": auto_row.reason_codes if auto_row else ["automatic-occurrence-not-found"],
                                "coverage": auto_row.coverage if auto_row else "partial",
                                "evidence": auto_row.evidence if auto_row else "",
                                "contextualAnalysis": None,
                                "effectiveWritable": auto_row.writable if auto_row else None,
                                "effectiveCanAssignInNew": auto_row.can_assign_in_new if auto_row else None,
                                "decisionState": "none",
                                "decisionIds": [],
                                "pendingDecisions": [],
                                "provenance": auto_row.provenance if auto_row else {},
                                "relatedProofRefs": ([
                                    _object_ref(root_kinds_by_path.get(tables_by_guid[guid].path, "corpus"),
                                                tables_by_guid[guid].path, "Table", guid,
                                                tables_by_guid[guid].name)
                                    for guid in auto_row.provenance.get("relationAnalysis", {}).get("visitedTableGuids", [])
                                    if guid in tables_by_guid
                                ] + [
                                    _object_ref(str(view.transaction.get("rootKind", "corpus")),
                                                view.transaction.get("path", ""), "Transaction",
                                                view.transaction.get("guid"), str(view.transaction.get("name", "")))
                                    for guid in auto_row.provenance.get("relationAnalysis", {}).get("visitedTableGuids", [])
                                    for view in table_views.get(guid, [])
                                ] if auto_row else []),
                            }
                occurrences = list(occurrence_candidates.values())
                if not occurrences:
                    all_mapped = False
                per_assignment.append({"assignment": assignment_ref, "occurrences": occurrences,
                                       "reasonCodes": [] if occurrences else ["assignment-not-in-table-group"]})
            if all_mapped and len(per_assignment) == len(block.assignments):
                group_views = [{"transaction": _object_ref(str(view.transaction.get("rootKind", "corpus")),
                                                              str(view.transaction.get("path", "")), "Transaction",
                                                              view.transaction.get("guid"), str(view.transaction.get("name", ""))),
                                "partType": view.part_type,
                                "level": {"guid": view.guid, "pathOrdinals": list(view.path_ordinals)},
                                "associationStatus": view.association_status}
                               for view in sorted(views, key=lambda item: (str(item.transaction.get("path")),
                                                                          item.part_type, item.path_ordinals))]
                selection_eligible, selection_issues = _selection_eligibility(group_views, per_assignment)
                group_by_guid[table.guid] = {
                    "table": _object_ref(root_kinds_by_path.get(table.path, "corpus"),
                                          table.path, "Table", table.guid, table.name),
                    "views": group_views,
                    "assignmentTargets": per_assignment,
                    "selectable": selection_eligible,
                    "selectionReasonCodes": selection_issues,
                }

        groups = sorted(group_by_guid.values(), key=lambda item: (str(item["table"]["name"]).casefold(),
                                                                  str(item["table"]["guid"])))
        issues = list(block.issues)
        if not assignment_records:
            issues.append("new-block-has-no-direct-attribute-assignments")
        if any(record["identityStatus"] != "resolved" for record in assignment_records):
            issues.append("new-assignment-identity-incomplete")
        candidate_state = "new-target-ambiguous" if len(groups) > 1 else "candidate" if len(groups) == 1 else "new-target-unresolved"
        if block.issues:
            candidate_state = "new-extraction-incomplete"
        for group in groups:
            if group["selectable"]:
                group["newTargetRef"] = _group_new_target(
                    {"block": {**block_ref, "index": block.index}}, group)
        block_results.append({
            "block": {**block_ref, "index": block.index},
            "assignments": assignment_records,
            "candidates": groups,
            "candidateState": candidate_state,
            "coverage": "partial" if issues or model.errors else "complete-in-model",
            "reasonCodes": sorted(set([*issues, *model.errors])),
            "decisionState": "pending" if len(groups) > 1 else "none",
            "pendingDecisions": ([{"type": "select-new-target", "block": block_ref,
                                    "candidateTables": [group["table"] for group in groups]}
                                   for _ in [0] if len(groups) > 1 and any(group["selectable"] for group in groups)]),
        })
    return {"procedure": procedure_ref, "sourceSha256": source_sha,
            "writabilityRuleVersion": automatic.WRITABILITY_RULE_VERSION,
            "inventoryStatus": "partial" if model.errors else "complete-in-model",
            "transactionsIndexed": len(model.transactions),
            "inventoryErrors": model.errors,
            "newBlocks": block_results}


def analyze_procedure(procedure_path: Path, corpus_root: Path,
                      delta_root: Path | None = None, *, model_root: Path | None = None,
                      root_kinds_by_path: dict[str, str] | None = None) -> dict[str, object]:
    procedure = procedure_path.resolve(strict=True)
    corpus = corpus_root.resolve(strict=True)
    root, guid, source = _procedure_source(procedure)
    try:
        source.encode("utf-8", errors="strict")
    except UnicodeEncodeError as exc:
        raise OperationalError(f"Source is not valid Unicode text: {exc}") from exc
    try:
        relative = procedure.relative_to(corpus).as_posix()
    except ValueError:
        relative = procedure.name
    name = _property_name(root) or procedure.stem
    source_sha = _sha256(source)
    blocks = extract_new_blocks(source)
    if not blocks:
        try:
            relative = procedure.relative_to(corpus).as_posix()
            root_kind = "corpus"
        except ValueError:
            if delta_root is not None and procedure.is_relative_to(delta_root.resolve(strict=True)):
                relative = procedure.relative_to(delta_root.resolve(strict=True)).as_posix()
                root_kind = "delta"
            else:
                relative = procedure.name
                root_kind = "delta"
        return {"status": "pass", "operationalStatus": "clear", "procedure": {
                    "type": "Procedure", "guid": guid, "name": name, "path": relative,
                    "rootKind": root_kind},
                "newBlocks": [], "reasonCodes": ["new-no-blocks"], "writabilityRuleVersion": automatic.WRITABILITY_RULE_VERSION}
    result = _candidate_groups(model_root or corpus, procedure, source_sha, source, blocks,
                               delta_root=delta_root, corpus_reference_root=corpus,
                               root_kinds_by_path=root_kinds_by_path)
    if delta_root is not None and procedure.is_relative_to(delta_root.resolve(strict=True)):
        result["procedure"] = {**result["procedure"], "rootKind": "delta",
                                "path": procedure.relative_to(delta_root.resolve(strict=True)).as_posix()}
    any_fail = False
    any_attention = False
    for block_result in result["newBlocks"]:
        groups = block_result["candidates"]
        if block_result["candidateState"] == "new-extraction-incomplete" or block_result["coverage"] != "complete-in-model" or not groups:
            any_fail = True
            continue
        if len(groups) > 1:
            any_attention = True
            continue
        group = groups[0]
        statuses = [occurrence["writable"] for target in group["assignmentTargets"]
                    for occurrence in target["occurrences"]]
        associations_complete = all(view["associationStatus"] == "resolved-level-type-and-table-key"
                                    for view in group["views"])
        if statuses and all(status is True for status in statuses) and associations_complete:
            continue
        inferential = all(occurrence["classification"] in {
            "unclassified-relation-pending", "extended-fk-descriptive", "unclassified-role-conflict"
        } or occurrence["writable"] is True
                          for target in group["assignmentTargets"] for occurrence in target["occurrences"])
        if inferential and group["selectable"]:
            any_attention = True
        else:
            any_fail = True
    result["status"] = "fail" if any_fail else "alert" if any_attention else "pass"
    result["operationalStatus"] = "blocked" if any_fail else "attention" if any_attention else "clear"
    result["proceduresScanned"] = 1
    result["newBlocksScanned"] = len(result["newBlocks"])
    result["assignmentsScanned"] = sum(len(block["assignments"]) for block in result["newBlocks"])
    return result


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Analyze GeneXus New assignments with occurrence identities.")
    parser.add_argument("--transaction-path", type=Path)
    parser.add_argument("--procedure-path", type=Path, action="append")
    parser.add_argument("--front-folder", type=Path)
    parser.add_argument("--corpus-root", type=Path, required=True)
    parser.add_argument("--delta-root", type=Path)
    parser.add_argument("--front-id")
    parser.add_argument("--decision-path", type=Path)
    parser.add_argument("--request-path", type=Path)
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    try:
        corpus_root = args.corpus_root.resolve(strict=True)
        delta_root = args.delta_root.resolve(strict=True) if args.delta_root else (
            args.front_folder.resolve(strict=True) if args.front_folder else None)
        if delta_root is not None and not delta_root.is_dir():
            raise OperationalError(f"delta root is not a directory: {delta_root}")
        if args.transaction_path:
            if args.procedure_path or args.front_folder:
                raise OperationalError("Transaction analysis cannot be combined with procedure/front-folder analysis")
            input_transaction = args.transaction_path.resolve(strict=True)
            decision_raw = args.decision_path.resolve(strict=True).read_bytes() if args.decision_path else None
            if delta_root is None:
                result = analyze_transaction(input_transaction, corpus_root, front_id=args.front_id,
                                             decision_raw=decision_raw,
                                             include_request=args.request_path is not None,
                                             display_path=input_transaction)
            else:
                with tempfile.TemporaryDirectory(prefix="gx-writability-transaction-overlay-") as temp_folder:
                    overlay_root = Path(temp_folder)
                    origins = _overlay_model_corpus(corpus_root, delta_root, overlay_root)
                    candidate_path: Path | None = None
                    for source_root in (delta_root, corpus_root):
                        try:
                            relative = input_transaction.relative_to(source_root).as_posix()
                        except ValueError:
                            continue
                        possible = overlay_root / relative
                        if possible.is_file():
                            candidate_path = possible
                            break
                    if candidate_path is None:
                        input_xml = _strict_xml(input_transaction)
                        input_guid = _xml_guid(input_xml.attrib.get("guid", ""))
                        matches = [overlay_root / path for path, _kind in origins.items()
                                   if path.startswith("Transaction/")
                                   and _xml_guid(_strict_xml(overlay_root / path).attrib.get("guid", "")) == input_guid]
                        if len(matches) != 1:
                            raise OperationalError("Transaction cannot be resolved uniquely in corpus/delta overlay")
                        candidate_path = matches[0]
                    relative = candidate_path.relative_to(overlay_root).as_posix()
                    root_kind = origins.get(relative, "corpus")
                    display_root = delta_root if root_kind == "delta" else corpus_root
                    display_path = display_root / relative
                    result = analyze_transaction(
                        candidate_path, corpus_root, model_root=overlay_root, front_id=args.front_id,
                        decision_raw=decision_raw, include_request=args.request_path is not None,
                        delta_root=delta_root, root_kinds_by_path=origins,
                        source_roots={"corpus": corpus_root, "delta": delta_root},
                        display_path=display_path)
            if args.request_path:
                request_path = args.request_path.resolve()
                request_path.parent.mkdir(parents=True, exist_ok=True)
                request_path.write_bytes(canonical_bytes(result["decisionRequest"]))
                result["requestPath"] = str(request_path)
            print(json.dumps(result, ensure_ascii=False, separators=(",", ":")))
            return 0
        paths: list[Path] = []
        for raw_path in args.procedure_path or []:
            path = raw_path.resolve(strict=True)
            if path not in paths:
                paths.append(path)
        if args.front_folder:
            front = args.front_folder.resolve(strict=True)
            if not front.is_dir():
                raise OperationalError(f"FrontFolder is not a directory: {front}")
            for path in sorted(front.rglob("*.xml"), key=lambda item: item.relative_to(front).as_posix()):
                try:
                    root = _strict_xml(path)
                except OperationalError as exc:
                    raise OperationalError(f"front inventory is incomplete at {path}: {exc}") from exc
                if _local(root.tag).casefold() == "object" and _xml_guid(root.attrib.get("type", "")) == PROCEDURE_TYPE_GUID:
                    resolved = path.resolve(strict=True)
                    if resolved not in paths:
                        paths.append(resolved)
        if not paths:
            raise OperationalError("provide --procedure-path or a front folder containing a Procedure")
        if args.front_folder and delta_root != args.front_folder.resolve(strict=True):
            raise OperationalError("front-folder and delta-root must identify the same snapshot")
        if delta_root:
            with tempfile.TemporaryDirectory(prefix="gx-writability-overlay-") as temp_folder:
                overlay_root = Path(temp_folder)
                origins = _overlay_model_corpus(corpus_root, delta_root, overlay_root)
                results = [analyze_procedure(path, corpus_root, delta_root,
                                             model_root=overlay_root,
                                             root_kinds_by_path=origins) for path in paths]
        else:
            results = [analyze_procedure(path, corpus_root) for path in paths]
        front_id = args.front_id or (delta_root.name if delta_root else corpus_root.name)
        decision_summary: dict[str, Any] | None = None
        manifest_error: str | None = None
        if args.decision_path:
            try:
                decision_summary = _apply_decisions(args.decision_path.resolve(strict=True).read_bytes(),
                                                    results, corpus_root, delta_root)
            except (OperationalError, ValueError, OSError, CanonicalJsonError) as exc:
                manifest_error = str(exc)
                for procedure, block in _all_blocks(results):
                    block["decisionState"] = "malformed"
                    block["decisionError"] = manifest_error
                    block["pendingDecisions"] = []
        request = _decision_request(results, corpus_root, delta_root, front_id) if args.request_path else None
        if request is not None:
            request_path = args.request_path.resolve()
            request_path.parent.mkdir(parents=True, exist_ok=True)
            request_path.write_bytes(canonical_bytes(request))
        precedence = {"pass": 0, "alert": 1, "fail": 2}
        status = max((str(item.get("status", "fail")) for item in results), key=lambda item: precedence.get(item, 2))
        if manifest_error or (decision_summary and any(item["status"] in {"malformed", "stale", "out-of-scope", "ineligible", "conflicting"}
                                                       for item in decision_summary["decisionResults"])):
            status = "fail"
        elif decision_summary and decision_summary["decisionResults"]:
            status = "alert" if status != "fail" else status
        result = {"status": status,
                  "operationalStatus": "blocked" if status == "fail" else "attention" if status == "alert" else "clear",
                  "frontFolder": str(args.front_folder.resolve()) if args.front_folder else None,
                  "deltaRoot": str(delta_root) if delta_root else None,
                  "corpusFolder": str(corpus_root),
                  "writabilityRuleVersion": automatic.WRITABILITY_RULE_VERSION,
                  "proceduresScanned": len(results),
                  "transactionsIndexed": max((int(item.get("transactionsIndexed", 0)) for item in results), default=0),
                  "newBlocksScanned": sum(int(item.get("newBlocksScanned", 0)) for item in results),
                  "assignmentsScanned": sum(int(item.get("assignmentsScanned", 0)) for item in results),
                  "procedures": results,
                  "findings": [block for item in results for block in item.get("newBlocks", [])],
                  "decisionResults": decision_summary["decisionResults"] if decision_summary else [],
                  "decisionManifestError": manifest_error,
                  "requestPath": str(args.request_path.resolve()) if args.request_path else None}
    except (OperationalError, ValueError, OSError, CanonicalJsonError) as exc:
        print(json.dumps({"status": "fail", "operationalStatus": "blocked",
                          "reasonCodes": ["new-extraction-incomplete"], "error": str(exc)},
                         ensure_ascii=False, separators=(",", ":")), file=sys.stderr)
        return 2
    print(json.dumps(result, ensure_ascii=False, separators=(",", ":")))
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except (OperationalError, OSError, ValueError, CanonicalJsonError) as exc:
        print(json.dumps({"status": "fail", "operationalStatus": "blocked",
                          "reasonCodes": ["new-extraction-incomplete"], "error": str(exc)},
                         ensure_ascii=False, separators=(",", ":")), file=sys.stderr)
        raise SystemExit(2)
