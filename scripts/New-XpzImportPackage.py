#!/usr/bin/env python3
"""Internal engine for GeneXus import_file.xml packaging.

For operational use, call New-XpzImportPackage.ps1. The PowerShell wrapper runs
the required front validations, including the 9-FD front-acervo drift gate;
direct Python execution is not an equivalent safe entry point.
"""

from __future__ import annotations

import argparse
import json
import re
import sys
import xml.etree.ElementTree as ET
import zipfile
from pathlib import Path
from typing import Any
from xml.sax.saxutils import quoteattr


GUID_RE = re.compile(r"^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$")
PLACEHOLDER_RE = re.compile(r"(YOUR[-_]GUID|GUID[-_]HERE|PLACEHOLDER|TODO[-_]GUID|INSERT[-_]HERE|OBJECT[-_]HERE)", re.I)
PANEL_OBJECT_TYPE_GUID = "d82625fd-5892-40b0-99c9-5c8559c197fc"
FRONT_REFERENCE_XML_RE = re.compile(
    r"(^|[-_.\s])(referencia|referência|reference|exemplo|example|template|molde)([-_.\s]|$)",
    re.I,
)


class BlockedError(RuntimeError):
    def __init__(self, message: str, *, reason: str = "BLOCKED", details: dict[str, Any] | None = None) -> None:
        super().__init__(message)
        self.reason = reason
        self.details = details or {}


def block(message: str, *, reason: str = "BLOCKED", details: dict[str, Any] | None = None) -> None:
    raise BlockedError(message, reason=reason, details=details)


def local_name(tag: str) -> str:
    return tag.rsplit("}", 1)[-1]


def read_markdown_table_value(lines: list[str], section_name: str, field_name: str) -> str | None:
    in_section = False
    for line in lines:
        if re.match(r"^\s*##\s+", line):
            in_section = re.match(rf"^\s*##\s+{re.escape(section_name)}\s*$", line) is not None
            continue
        if not in_section:
            continue
        cells = line.split("|")
        if len(cells) < 4:
            continue
        name = cells[1].strip()
        value = cells[2].strip()
        if name.lower() == field_name.lower() and not re.match(r"^-+$", name):
            return value
    return None


def require_value(value: str | None, label: str) -> str:
    trimmed = "" if value is None else value.strip()
    if not trimmed or trimmed == "(ausente)" or re.match(r"^-+$", trimmed):
        block(f"campo obrigatorio ausente em kb-source-metadata.md: {label}")
    return trimmed


def load_metadata(metadata_path: Path) -> dict[str, str]:
    lines = metadata_path.read_text(encoding="utf-8-sig").splitlines()
    return {
        "MajorVersion": require_value(read_markdown_table_value(lines, "KMW", "MajorVersion"), "KMW/MajorVersion"),
        "MinorVersion": require_value(read_markdown_table_value(lines, "KMW", "MinorVersion"), "KMW/MinorVersion"),
        "Build": require_value(read_markdown_table_value(lines, "KMW", "Build"), "KMW/Build"),
        "KbGuid": require_value(read_markdown_table_value(lines, "Source", "kb (GUID)"), "Source/kb (GUID)"),
        "Username": require_value(read_markdown_table_value(lines, "Source", "username"), "Source/username"),
        "UNCPath": require_value(read_markdown_table_value(lines, "Source", "UNCPath"), "Source/UNCPath"),
        "VersionGuid": require_value(read_markdown_table_value(lines, "Source/Version", "guid"), "Source/Version/guid"),
        "VersionName": require_value(read_markdown_table_value(lines, "Source/Version", "name"), "Source/Version/name"),
    }


def make_minimal_template(metadata: dict[str, str]) -> ET.Element:
    root = ET.Element("ExportFile")
    kmw = ET.SubElement(root, "KMW")
    for name in ("MajorVersion", "MinorVersion", "Build"):
        ET.SubElement(kmw, name).text = metadata[name]
    source = ET.SubElement(
        root,
        "Source",
        {"kb": metadata["KbGuid"], "username": metadata["Username"], "UNCPath": metadata["UNCPath"]},
    )
    ET.SubElement(source, "Version", {"guid": metadata["VersionGuid"], "name": metadata["VersionName"]})
    ET.SubElement(root, "Objects")
    ET.SubElement(root, "Dependencies")
    ET.SubElement(root, "ObjectsIdentityMapping")
    return root


def load_template(template_path: Path | None, metadata_path: Path) -> tuple[ET.Element, str, list[str]]:
    warnings: list[str] = []
    if template_path is None:
        warnings.append(
            "envelope-minimo: pacote gerado a partir de kb-source-metadata.md; "
            "para pacote misto/complexo, preferir --template-package-path com export real comparavel."
        )
        return make_minimal_template(load_metadata(metadata_path)), "metadata", warnings
    if not template_path.is_file():
        block(f"TemplatePackagePath nao encontrado: {template_path}")
    if template_path.suffix.lower() in {".xpz", ".zip"}:
        try:
            with zipfile.ZipFile(template_path) as zf:
                for name in sorted(zf.namelist(), key=str.lower):
                    if not name.lower().endswith(".xml"):
                        continue
                    try:
                        root = ET.fromstring(zf.read(name))
                    except ET.ParseError:
                        continue
                    if local_name(root.tag) == "ExportFile":
                        warnings.append(f"template-xpz: envelope ExportFile extraido de {template_path.name}!{name}")
                        return root, "template-xpz", warnings
        except zipfile.BadZipFile as exc:
            block(f"TemplatePackagePath XPZ invalido: {template_path}: {exc}")
        block(f"TemplatePackagePath XPZ nao contem XML com raiz ExportFile: {template_path}")
    try:
        root = ET.parse(template_path).getroot()
    except ET.ParseError as exc:
        block(f"TemplatePackagePath nao e XML bem-formado: {template_path}: {exc}")
    if local_name(root.tag) != "ExportFile":
        block(f"TemplatePackagePath nao tem raiz ExportFile: {template_path}")
    return root, "template", warnings


def validate_template(root: ET.Element) -> None:
    children = {local_name(child.tag): child for child in list(root)}
    for required in ("KMW", "Source"):
        if required not in children:
            block(f"TemplatePackage nao contem bloco obrigatorio <{required}>")


def parse_xml(path: Path, role: str) -> ET.Element:
    try:
        return ET.parse(path).getroot()
    except ET.ParseError as exc:
        block(f"{role} malformado em {path}: {exc}")


def read_xml_text(path: Path) -> str:
    raw_bytes = path.read_bytes()
    for encoding in ("utf-8-sig", "utf-16"):
        try:
            return raw_bytes.decode(encoding)
        except UnicodeDecodeError:
            continue
    block(f"nao foi possivel decodificar XML como utf-8/utf-16: {path}")
    raise AssertionError("unreachable")


def xml_fragment(raw_xml: str) -> str:
    return re.sub(r"^\s*<\?xml\b[^?]*\?>\s*", "", raw_xml, count=1, flags=re.I).strip()


def front_reference_xml_reason(path: Path) -> str | None:
    if FRONT_REFERENCE_XML_RE.search(path.stem):
        return "nome do arquivo indica XML de referencia/exemplo/template/molde"
    return None


def classify_front_xmls(front_dir: Path) -> tuple[list[tuple[Path, ET.Element, str]], list[tuple[Path, ET.Element, str]]]:
    xml_paths = sorted(front_dir.glob("*.xml"), key=lambda p: p.name.lower())
    if not xml_paths:
        block(f"nenhum XML encontrado na pasta da frente: {front_dir}")
    objects: list[tuple[Path, ET.Element, str]] = []
    attributes: list[tuple[Path, ET.Element, str]] = []
    unsupported: list[str] = []
    reference_like: list[str] = []
    for path in xml_paths:
        raw_xml = read_xml_text(path)
        root = parse_xml(path, "XML da frente")
        root_name = local_name(root.tag)
        reference_reason = front_reference_xml_reason(path)
        if reference_reason:
            reference_like.append(f"{path} ({reference_reason})")
            continue
        if root_name == "Object":
            objects.append((path, root, xml_fragment(raw_xml)))
        elif root_name == "Attribute":
            attributes.append((path, root, xml_fragment(raw_xml)))
        else:
            unsupported.append(f"{path}={root_name}")
    if reference_like:
        block(
            "XML de referencia/exemplo/template nao pode ficar na frente ativa de empacotamento: "
            + "; ".join(reference_like)
        )
    if unsupported:
        block("raiz XML nao suportada para empacotamento local: " + "; ".join(unsupported))
    if not objects:
        block(f"nenhum XML com raiz <Object> encontrado na pasta da frente: {front_dir}")
    return objects, attributes


def is_panel_object(root: ET.Element) -> bool:
    object_type = root.attrib.get("type", "")
    return object_type.lower() == PANEL_OBJECT_TYPE_GUID


def panel_level_layout_pairs(root: ET.Element) -> set[str]:
    pairs: set[str] = set()
    pattern = re.compile(
        r'<(?:level|Level)\b[^>]*(?:id|guid)="(?P<level>[^"]+)"[\s\S]*?'
        r'<(?:layout|Layout)\b[^>]*(?:id|guid)="(?P<layout>[^"]+)"',
        re.I,
    )
    for node in root.iter():
        if local_name(node.tag) not in {"Data", "Source"} or not node.text:
            continue
        for match in pattern.finditer(node.text):
            pairs.add(f"{match.group('level')}|{match.group('layout')}")
    return pairs


def panel_package_findings(
    object_roots: list[tuple[Path, ET.Element, str]],
    envelope_source: str,
    template_root: ET.Element,
) -> tuple[list[str], list[str]]:
    panel_names = [
        root.attrib.get("name", path.stem)
        for path, root, _ in object_roots
        if is_panel_object(root)
    ]
    if not panel_names:
        return [], []

    candidate_pairs: set[str] = set()
    for _, root, _ in object_roots:
        if is_panel_object(root):
            candidate_pairs.update(panel_level_layout_pairs(root))
    reference_pairs: set[str] = set()
    for objects in (child for child in template_root if local_name(child.tag) == "Objects"):
        for root in objects:
            if is_panel_object(root):
                reference_pairs.update(panel_level_layout_pairs(root))

    warnings: list[str] = []
    information: list[str] = []
    if envelope_source != "metadata" and candidate_pairs.intersection(reference_pairs):
        information.append(
            "panel-level-layout-confirmed: Panel detectado; par level/layout confirmado "
            "em template comparavel informado."
        )
    elif envelope_source != "metadata":
        warnings.append(
            "panel-level-layout-suspicious: Panel detectado; nenhum par level/layout "
            "do pacote foi localizado no template comparavel informado. Revisar contra "
            "Panel SD exportado pela IDE da mesma KB."
        )
    else:
        warnings.append(
            "panel-level-layout-unverified: Panel detectado sem template comparavel; "
            "nao gerar level id e layout id como GUIDs independentes. Usar par coerente "
            "vindo de Panel SD exportado pela IDE da mesma KB."
        )
    if envelope_source == "metadata":
        warnings.append(
            "panel-envelope-minimo: Panel empacotado com envelope-minimo derivado de kb-source-metadata.md; preferir --template-package-path com XPZ/import_file real comparavel exportado pela IDE para clonar envelope completo."
        )
    information.append("panel-objects: " + ", ".join(panel_names))
    return warnings, information


def format_round(nn: str) -> str:
    if not re.match(r"^\d+$", nn):
        block("NN invalido; use apenas digitos")
    return str(int(nn)).zfill(max(len(nn), 2))


def check_collision(output_path: Path, front_name: str, round_text: str) -> dict[str, Any]:
    output_path.parent.mkdir(parents=True, exist_ok=True)
    expected_name = f"{front_name}_{round_text}.import_file.xml"
    pattern = re.compile(rf"^{re.escape(front_name)}_(?P<nn>\d+)\.import_file\.xml$", re.I)
    used: set[int] = set()
    colliding: Path | None = None
    for child in output_path.parent.iterdir():
        if not child.is_file():
            continue
        match = pattern.match(child.name)
        if not match:
            continue
        used.add(int(match.group("nn")))
        if child.name.lower() == expected_name.lower():
            colliding = child
    if colliding is not None:
        next_free = int(round_text) + 1
        while next_free in used:
            next_free += 1
        next_free_nn = f"{next_free:0{len(round_text)}d}"
        block(
            f"_{round_text} ja existe para o front {front_name}; proximo livre: _{next_free_nn}",
            reason="PACKAGE_ROUND_COLLISION",
            details={
                "frontPrefix": front_name,
                "requestedNN": round_text,
                "requestedRound": int(round_text),
                "nextFreeNN": next_free_nn,
                "nextFreeRound": next_free,
                "outputDir": str(output_path.parent),
                "collidingPath": str(colliding),
            },
        )
    return {
        "status": "ok",
        "reason": "COLLISION_OK",
        "frontPrefix": front_name,
        "requestedNN": round_text,
        "requestedRound": int(round_text),
        "nextFreeNN": None,
        "nextFreeRound": None,
        "outputDir": str(output_path.parent),
        "collidingPath": None,
        "blockingReasons": [],
    }


def serialize_template_block(child: ET.Element) -> str:
    return ET.tostring(child, encoding="unicode", short_empty_elements=True)


def start_tag(name: str, attrs: dict[str, str]) -> str:
    if not attrs:
        return f"<{name}>"
    rendered_attrs = " ".join(f"{key}={quoteattr(value)}" for key, value in attrs.items())
    return f"<{name} {rendered_attrs}>"


def build_package_text(
    template_root: ET.Element,
    object_roots: list[tuple[Path, ET.Element, str]],
    attribute_roots: list[tuple[Path, ET.Element, str]],
) -> str:
    template_blocks: dict[str, ET.Element] = {local_name(child.tag): child for child in list(template_root)}
    lines = ['<?xml version="1.0" encoding="utf-8"?>', start_tag("ExportFile", dict(template_root.attrib))]
    for block_name in ("KMW", "Source"):
        lines.append("  " + serialize_template_block(template_blocks[block_name]).replace("\n", "\n  "))
    lines.append("  <Objects>")
    for _, _, raw_fragment in object_roots:
        lines.append(raw_fragment)
    lines.append("  </Objects>")
    if attribute_roots:
        lines.append("  <Attributes>")
        for _, _, raw_fragment in attribute_roots:
            lines.append(raw_fragment)
        lines.append("  </Attributes>")
    elif "Attributes" in template_blocks:
        lines.append("  " + serialize_template_block(template_blocks["Attributes"]).replace("\n", "\n  "))
    if "Dependencies" in template_blocks:
        lines.append("  " + serialize_template_block(template_blocks["Dependencies"]).replace("\n", "\n  "))
    else:
        lines.append("  <Dependencies />")
    if "ObjectsIdentityMapping" in template_blocks:
        lines.append("  " + serialize_template_block(template_blocks["ObjectsIdentityMapping"]).replace("\n", "\n  "))
    lines.append("</ExportFile>")
    return "\n".join(lines) + "\n"


def validate_envelope(package_root: ET.Element) -> tuple[str, list[str], list[str]]:
    blocking: list[str] = []
    warnings: list[str] = []
    if local_name(package_root.tag) != "ExportFile":
        blocking.append(f"root-not-export-file: raiz encontrada {local_name(package_root.tag)}")
    children = {local_name(child.tag): child for child in list(package_root)}
    for block_name in ("KMW", "Source", "Objects", "Dependencies"):
        if block_name not in children:
            blocking.append(f"missing-{block_name.lower()}: bloco <{block_name}> ausente")
    if "ObjectsIdentityMapping" not in children:
        warnings.append("missing-identity-mapping: <ObjectsIdentityMapping> ausente")
    source = children.get("Source")
    if source is not None:
        kb_guid = source.attrib.get("kb", "")
        version = next((child for child in list(source) if local_name(child.tag) == "Version"), None)
        version_guid = "" if version is None else version.attrib.get("guid", "")
        if not kb_guid:
            blocking.append("source-kb-missing: Source/@kb ausente")
        elif not GUID_RE.match(kb_guid):
            blocking.append(f"source-kb-not-guid: Source/@kb nao esta em formato GUID: {kb_guid}")
        if version is None:
            blocking.append("source-version-missing: Source/Version ausente")
        elif not version_guid:
            blocking.append("source-version-guid-missing: Source/Version/@guid ausente")
        elif not GUID_RE.match(version_guid):
            blocking.append(f"source-version-guid-not-guid: Source/Version/@guid nao esta em formato GUID: {version_guid}")
    objects = children.get("Objects")
    if objects is not None:
        object_children = [child for child in list(objects) if isinstance(child.tag, str)]
        if not object_children:
            blocking.append("objects-empty: <Objects> nao contem nenhum objeto")
        for child in object_children:
            tag_name = local_name(child.tag)
            name = child.attrib.get("name", "")
            guid = child.attrib.get("guid", "")
            if tag_name != "Object":
                blocking.append(
                    f"objects-invalid-child-element: <Objects> deve conter apenas <Object>; encontrado <{tag_name}> (name='{name}')"
                )
            if not guid:
                blocking.append(f"object-guid-missing: elemento <{tag_name}> (name='{name}') sem atributo guid")
            elif PLACEHOLDER_RE.search(guid):
                blocking.append(f"object-guid-placeholder: elemento <{tag_name}> (name='{name}') parece placeholder")
            elif not GUID_RE.match(guid):
                blocking.append(f"object-guid-invalid: elemento <{tag_name}> (name='{name}') guid invalido: {guid}")
            if PLACEHOLDER_RE.search(name):
                warnings.append(f"object-name-placeholder: elemento <{tag_name}> name parece placeholder: {name}")
            if not name:
                warnings.append(f"object-name-missing: elemento <{tag_name}> sem atributo name")
    status = "apto para prosseguir" if not blocking and not warnings else ("apto com ressalvas" if not blocking else "não apto para prosseguir")
    return status, blocking, warnings


def rejected_path(base_path: Path) -> Path:
    for code in range(ord("A"), ord("Z") + 1):
        candidate = base_path.with_name(base_path.name + f".rejected.{chr(code)}")
        if not candidate.exists():
            return candidate
    block(f"limite de rejeicoes atingido: {base_path}.rejected.A..Z ja existem")
    raise AssertionError("unreachable")


def main(argv: list[str]) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--repo-root", required=True)
    parser.add_argument("--front-name", required=True)
    parser.add_argument("--nn", default="01")
    parser.add_argument("--template-package-path")
    args = parser.parse_args(argv)

    try:
        if re.search(r"[\\/]", args.front_name):
            block("FrontName invalido; informe apenas o nome da subpasta da frente")
        repo = Path(args.repo_root).resolve()
        if not repo.is_dir():
            block(f"RepoRoot inexistente: {repo}")
        round_text = format_round(args.nn)
        front_dir = repo / "ObjetosGeradosParaImportacaoNaKbNoGenexus" / args.front_name
        packages_dir = repo / "PacotesGeradosParaImportacaoNaKbNoGenexus"
        metadata_path = repo / "kb-source-metadata.md"
        output_path = packages_dir / f"{args.front_name}_{round_text}.import_file.xml"
        if not front_dir.is_dir():
            block(f"pasta da frente nao encontrada: {front_dir}")
        if not metadata_path.is_file():
            block(f"kb-source-metadata.md nao encontrado: {metadata_path}")
        template_path = Path(args.template_package_path).resolve() if args.template_package_path else None
        object_roots, attribute_roots = classify_front_xmls(front_dir)
        collision_result = check_collision(output_path, args.front_name, round_text)
        template_root, envelope_source, envelope_warnings = load_template(template_path, metadata_path)
        validate_template(template_root)
        package_text = build_package_text(template_root, object_roots, attribute_roots)
        package_root = ET.fromstring(package_text)
        output_path.parent.mkdir(parents=True, exist_ok=True)
        output_path.write_text(package_text, encoding="utf-8", newline="\n")
        status, blocking, validation_warnings = validate_envelope(package_root)
        panel_warnings, panel_information = panel_package_findings(object_roots, envelope_source, template_root)
        all_warnings = envelope_warnings + validation_warnings + panel_warnings
        if not blocking and all_warnings:
            status = "apto com ressalvas"
        rejected = None
        if status == "não apto para prosseguir":
            rejected = rejected_path(output_path)
            output_path.replace(rejected)
        template_blocks = {local_name(child.tag): child for child in list(template_root)}
        top_level_attr_source = (
            "front"
            if attribute_roots
            else ("template" if "Attributes" in template_blocks else "none")
        )
        result: dict[str, Any] = {
            "status": status,
            "exitCode": 0,
            "outputPath": None if rejected else str(output_path),
            "rejectedPath": None if rejected is None else str(rejected),
            "repoRoot": str(repo),
            "frontName": args.front_name,
            "nn": round_text,
            "sourceFolder": str(front_dir),
            "metadataPath": str(metadata_path),
            "templatePackagePath": None if template_path is None else str(template_path),
            "envelopeSource": envelope_source,
            "objectCount": len(object_roots),
            "topLevelAttrCount": len(attribute_roots),
            "topLevelAttrSource": top_level_attr_source,
            "gateStatus": status,
            "collisionGate": collision_result,
            "blockingReasons": blocking,
            "warnings": all_warnings,
            "information": panel_information,
            "includedFiles": [str(path) for path, _, _ in object_roots + attribute_roots],
        }
        print(json.dumps(result, ensure_ascii=False, indent=2))
        return 0
    except BlockedError as exc:
        result = {
            "status": "bloqueado",
            "exitCode": 20,
            "stage": "python-engine",
            "reason": exc.reason,
            "blockingReasons": [str(exc)],
            "warnings": [],
        }
        result.update(exc.details)
        print(json.dumps(result, ensure_ascii=False, indent=2))
        return 20
    except Exception as exc:
        print(json.dumps({"status": "erro", "exitCode": 90, "stage": "python-engine", "blockingReasons": [str(exc)]}, ensure_ascii=False, indent=2))
        return 90


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
