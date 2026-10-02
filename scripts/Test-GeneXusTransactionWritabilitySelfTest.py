#!/usr/bin/env python3
"""Synthetic structural tests for Transaction occurrence and Table.Key analysis."""

from __future__ import annotations

import sys
import tempfile
import xml.etree.ElementTree as ET
from pathlib import Path

import GeneXusTransactionWritabilityCore as core


TRN_TYPE = "1db606f2-af09-4cf9-a3b5-b481519d28f6"
TABLE_TYPE = "857ca50e-7905-0000-0007-c5d9ff2975ec"
LEVEL_PART = "20000000-0000-4000-8000-000000000001"
ATTRS = {
    "CompanyId": "30000000-0000-4000-8000-000000000001",
    "OrderId": "30000000-0000-4000-8000-000000000002",
    "LineNo": "30000000-0000-4000-8000-000000000003",
    "FeeNo": "30000000-0000-4000-8000-000000000004",
    "CustomerId": "30000000-0000-4000-8000-000000000005",
    "CustomerName": "30000000-0000-4000-8000-000000000006",
    "Description": "30000000-0000-4000-8000-000000000007",
    "LineDescription": "30000000-0000-4000-8000-000000000008",
    "FeeDescription": "30000000-0000-4000-8000-000000000009",
    "JoinSuffix": "30000000-0000-4000-8000-000000000010",
    "ComputedId": "30000000-0000-4000-8000-000000000011",
}


def _write_xml(path: Path, root: ET.Element, bom: bool = False) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    data = ET.tostring(root, encoding="utf-8", xml_declaration=True)
    path.write_bytes((b"\xef\xbb\xbf" if bom else b"") + data)


def _write_attribute(root: Path, name: str, formula: bool = False) -> None:
    node = ET.Element("Attribute", {"guid": ATTRS[name], "name": name})
    if formula:
        props = ET.SubElement(node, "Properties")
        prop = ET.SubElement(props, "Property")
        ET.SubElement(prop, "Name").text = "Formula"
        ET.SubElement(prop, "Value").text = "&ComputedValue"
    _write_xml(root / "Attribute" / f"{name}.xml", node)


def _write_table(
    root: Path,
    name: str,
    guid_suffix: str,
    key_names: list[str],
    indexes: list[tuple[str, list[str]]],
) -> None:
    node = ET.Element("Object", {"type": TABLE_TYPE, "name": name,
                                  "guid": f"40000000-0000-4000-8000-{int(guid_suffix):012d}"})
    part = ET.SubElement(node, "Part", {"type": f"50000000-0000-4000-8000-{int(guid_suffix):012d}"})
    key = ET.SubElement(part, "Key")
    for name_item in key_names:
        ET.SubElement(key, "Item", {"guid": ATTRS[name_item]}).text = name_item
    for ordinal, (index_type, member_names) in enumerate(indexes, start=1):
        index = ET.SubElement(part, "Index", {"Type": index_type,
                                                "guid": f"60000000-0000-4000-8000-{int(guid_suffix) * 100 + ordinal:012d}"})
        for member_name in member_names:
            ET.SubElement(index, "Member", {"guid": ATTRS[member_name]}).text = member_name
    _write_xml(root / "Table" / f"{name}.xml", node)


def _level(parent: ET.Element, name: str, guid: str, table_type: str,
           attributes: list[tuple[str, bool]], children: list[dict[str, object]] | None = None) -> ET.Element:
    node = ET.SubElement(parent, "Level", {"Name": name, "Guid": guid, "Type": table_type})
    for attr_name, is_key in attributes:
        ET.SubElement(node, "Attribute", {"key": "True" if is_key else "False",
                                           "Guid": ATTRS[attr_name]}).text = attr_name
    for child in children or []:
        _level(node, str(child["name"]), str(child["guid"]), str(child["type"]),
               child["attributes"], child.get("children"))
    return node


def _write_transaction(root: Path, name: str, guid_suffix: str, level_specs: list[dict[str, object]],
                       *, bom: bool = False) -> Path:
    node = ET.Element("Object", {"type": TRN_TYPE, "name": name,
                                  "guid": f"10000000-0000-4000-8000-{int(guid_suffix):012d}"})
    part = ET.SubElement(node, "Part", {"type": LEVEL_PART})
    for spec in level_specs:
        _level(part, str(spec["name"]), str(spec["guid"]), str(spec["type"]),
               spec["attributes"], spec.get("children"))
    path = root / "Transaction" / f"{name}.xml"
    _write_xml(path, node, bom=bom)
    return path


def _assert(condition: bool, message: str) -> None:
    if not condition:
        raise AssertionError(message)


def main() -> int:
    with tempfile.TemporaryDirectory(prefix="gx-writability-selftest-") as temp:
        root = Path(temp)
        for folder in ("Attribute", "Table", "Transaction", "SubTypeGroup"):
            (root / folder).mkdir()
        for name in ATTRS:
            _write_attribute(root, name, formula=name == "ComputedId")

        _write_table(root, "Customer", "000000000001", ["CustomerId"],
                     [("Duplicate", ["CustomerId"])])
        _write_table(root, "Order", "000000000002", ["CompanyId", "OrderId"], [
            # This own-key index is permuted and must not become a self-FK edge.
            ("Duplicate", ["OrderId", "CompanyId"]),
            # Unique indexes participate in relation inference.
            ("Unique", ["CustomerId"]),
            # A member prefix plus an extra member is not an exact relation.
            ("Duplicate", ["CustomerId", "Description"]),
        ])
        _write_table(root, "OrderLine", "000000000003", ["CompanyId", "OrderId", "LineNo"],
                     [("Unique", ["CompanyId", "OrderId", "LineNo"])])
        _write_table(root, "OrderFee", "000000000004", ["CompanyId", "OrderId", "FeeNo"],
                     [("Duplicate", ["FeeNo", "OrderId", "CompanyId"])])
        _write_table(root, "Other", "000000000005", ["CustomerId", "JoinSuffix"], [])
        _write_table(root, "Broken", "000000000006", ["ComputedId"], [])

        _write_transaction(root, "Customer", "000000000001", [{
            "name": "Customer", "guid": "20000000-0000-4000-8000-000000000001", "type": "Customer",
            "attributes": [("CustomerId", True), ("CustomerName", False)],
        }], bom=True)
        dtd_path = root / "Transaction" / "DtdProbe.xml"
        dtd_path.write_bytes(b'<!DOCTYPE Object SYSTEM "file:///must-not-be-read.dtd"><Object/>')
        try:
            core._read_xml_root(dtd_path)
        except ValueError as exc:
            _assert("DOCTYPE" in str(exc), "XML with a DTD must be rejected before entity access")
        else:
            raise AssertionError("DTD-bearing XML must fail closed")
        dtd_path.unlink()
        order_path = _write_transaction(root, "Order", "000000000002", [{
            "name": "Order", "guid": "20000000-0000-4000-8000-000000000002", "type": "Order",
            "attributes": [("CompanyId", True), ("OrderId", True), ("CustomerId", False),
                           ("CustomerName", False), ("Description", False)],
            "children": [
                {"name": "OrderLine", "guid": "20000000-0000-4000-8000-000000000003", "type": "OrderLine",
                 "attributes": [("LineNo", True), ("LineDescription", False)]},
                {"name": "OrderFee", "guid": "20000000-0000-4000-8000-000000000004", "type": "OrderFee",
                 "attributes": [("FeeNo", True), ("FeeDescription", False)]},
            ],
        }])
        alias_path = _write_transaction(root, "OrderView", "000000000003", [{
            "name": "OrderView", "guid": "20000000-0000-4000-8000-000000000005", "type": "OrderView",
            "attributes": [("CompanyId", True), ("OrderId", True), ("Description", False)],
        }])
        prefix_path = _write_transaction(root, "OrderPrefix", "000000000004", [{
            "name": "OrderPrefix", "guid": "20000000-0000-4000-8000-000000000006", "type": "Order",
            "attributes": [("OrderId", True), ("Description", False)],
        }])
        broken_path = _write_transaction(root, "Broken", "000000000005", [{
            "name": "Broken", "guid": "20000000-0000-4000-8000-000000000007", "type": "Broken",
            "attributes": [("ComputedId", True)],
        }])

        type_guid = core.load_transaction_type_guid(Path(__file__).resolve().parent / "gx-object-type-catalog.json")
        order_rows = core.classify_transaction_attributes(order_path, root, type_guid)
        order_root = {row.attribute_name: row for row in order_rows if row.path_ordinals == [0]}
        child_rows = {(row.level_name, row.attribute_name): row for row in order_rows if len(row.path_ordinals) == 2}
        _assert(order_root["CompanyId"].classification == "key-attribute" and order_root["CompanyId"].writable is True,
                "a Table.Key member should remain writable")
        _assert(order_root["CustomerName"].classification == "extended-fk-descriptive" and order_root["CustomerName"].writable is False,
                "a descriptive field found through the exact relation should remain blocked")
        _assert(order_root["CustomerId"].classification == "unclassified-relation-pending" and order_root["CustomerId"].writable is None,
                "a resolved index candidate still needs an explicit relation decision")
        _assert(order_root["Description"].writable is True and order_root["Description"].classification == "own-physical-indexed",
                "an index member alone must not create an FK relation")
        _assert(child_rows[("OrderLine", "LineNo")].classification == "key-attribute",
                "the child Table.Key must match the ordered accumulated parent and child keys")
        _assert(child_rows[("OrderFee", "FeeNo")].classification == "key-attribute",
                "the sibling must match only its own accumulated Table.Key")
        _assert(not any(row.attribute_name == "LineNo" and row.level_name == "OrderFee" for row in order_rows),
                "a sibling key must not be borrowed as a local occurrence")

        alias_rows = core.classify_transaction_attributes(alias_path, root, type_guid)
        alias_description = next(row for row in alias_rows if row.attribute_name == "Description")
        _assert(alias_description.classification == "unclassified-relation-pending" and alias_description.writable is None,
                "a PK-only alias association must remain pending until the Table group is bound")
        prefix_rows = core.classify_transaction_attributes(prefix_path, root, type_guid)
        _assert(all(row.writable is None for row in prefix_rows), "a key prefix must not match a complete Table.Key")
        broken_rows = core.classify_transaction_attributes(broken_path, root, type_guid)
        _assert(broken_rows[0].classification == "unclassified-identity-conflict" and broken_rows[0].writable is None,
                "Key plus direct Formula must be a non-overridable identity conflict")

        model = core._load_writability_model(root)
        relations, _ = core._table_relation_index(model)
        order_table = next(table for table in model.tables if table.name == "Order")
        order_edges = relations[order_table.guid]
        _assert(len(order_edges) == 1 and order_edges[0]["index"]["type"] == "Unique",
                "only the exact Unique FK candidate should survive own-key and prefix filtering")

        print("OK: Test-GeneXusTransactionWritabilitySelfTest.py")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
