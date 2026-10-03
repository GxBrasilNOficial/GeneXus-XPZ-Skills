#!/usr/bin/env python3
"""Synthetic tests for Source lexing and occurrence-bound New analysis."""

from __future__ import annotations

import hashlib
import copy
import json
import shutil
import subprocess
import sys
import tempfile
import xml.etree.ElementTree as ET
from pathlib import Path

import GeneXusWritabilityOperational as operational


SCRIPT_DIR = Path(__file__).resolve().parent
ATTRIBUTE_IDS = {
    "CustomerId": "30000000-0000-4000-8000-000000000001",
    "CustomerName": "30000000-0000-4000-8000-000000000002",
    "OrderId": "30000000-0000-4000-8000-000000000003",
}
TABLE_GUID = "40000000-0000-4000-8000-000000000001"
TRANSACTION_GUID = "10000000-0000-4000-8000-000000000001"
LEVEL_GUID = "20000000-0000-4000-8000-000000000001"
PROCEDURE_GUID = "70000000-0000-4000-8000-000000000001"
TABLE_TYPE = "857ca50e-7905-0000-0007-c5d9ff2975ec"
TRANSACTION_TYPE = "1db606f2-af09-4cf9-a3b5-b481519d28f6"
PROCEDURE_TYPE = operational.PROCEDURE_TYPE_GUID


def _write_xml(path: Path, root: ET.Element) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_bytes(ET.tostring(root, encoding="utf-8", xml_declaration=True))


def _write_attribute(root: Path, name: str) -> None:
    _write_xml(root / "Attribute" / f"{name}.xml",
               ET.Element("Attribute", {"guid": ATTRIBUTE_IDS[name], "name": name}))


def _create_corpus(root: Path) -> Path:
    for folder in ("Attribute", "Table", "Transaction", "Procedure", "SubTypeGroup"):
        (root / folder).mkdir(parents=True, exist_ok=True)
    for name in ATTRIBUTE_IDS:
        _write_attribute(root, name)

    table = ET.Element("Object", {"type": TABLE_TYPE, "guid": TABLE_GUID, "name": "Customer"})
    table_part = ET.SubElement(table, "Part", {"type": "50000000-0000-4000-8000-000000000001"})
    key = ET.SubElement(table_part, "Key")
    ET.SubElement(key, "Item", {"guid": ATTRIBUTE_IDS["CustomerId"]}).text = "CustomerId"
    _write_xml(root / "Table" / "Customer.xml", table)

    transaction = ET.Element("Object", {"type": TRANSACTION_TYPE, "guid": TRANSACTION_GUID,
                                         "name": "Customer"})
    part = ET.SubElement(transaction, "Part", {"type": "20000000-0000-4000-8000-000000000099"})
    level = ET.SubElement(part, "Level", {"Name": "Customer", "Guid": LEVEL_GUID, "Type": "Customer"})
    ET.SubElement(level, "Attribute", {"Guid": ATTRIBUTE_IDS["CustomerId"], "key": "True"}).text = "CustomerId"
    ET.SubElement(level, "Attribute", {"Guid": ATTRIBUTE_IDS["CustomerName"], "key": "False"}).text = "CustomerName"
    _write_xml(root / "Transaction" / "Customer.xml", transaction)

    source = (
        "😀 // New ignored\n"
        "New\n"
        "    CustomerId = &id\n"
        "    If &id = 0\n"
        "        CustomerName = \"EndNew // /* doubled \"\" quote\"\n"
        "    EndIf\n"
        "When Duplicate\n"
        "    CustomerName = \"not an insert assignment\"\n"
        "EndNew\n"
        "&text = \"New EndNew\" // New\n"
    )
    procedure = ET.Element("Object", {"type": PROCEDURE_TYPE, "guid": PROCEDURE_GUID})
    properties = ET.SubElement(procedure, "Properties")
    prop = ET.SubElement(properties, "Property")
    ET.SubElement(prop, "Name").text = "Name"
    ET.SubElement(prop, "Value").text = "InsertCustomer"
    source_part = ET.SubElement(procedure, "Part", {"type": operational.SOURCE_PART_TYPE_GUID})
    source_node = ET.SubElement(source_part, "Source")
    source_node.text = source
    path = root / "Procedure" / "InsertCustomer.xml"
    _write_xml(path, procedure)
    return path


def _add_competing_customer_table(root: Path) -> None:
    table = ET.Element("Object", {"type": TABLE_TYPE,
                                    "guid": "40000000-0000-4000-8000-000000000002",
                                    "name": "CustomerCopy"})
    part = ET.SubElement(table, "Part", {"type": "50000000-0000-4000-8000-000000000002"})
    key = ET.SubElement(part, "Key")
    ET.SubElement(key, "Item", {"guid": ATTRIBUTE_IDS["CustomerId"]}).text = "CustomerId"
    _write_xml(root / "Table" / "CustomerCopy.xml", table)

    transaction = ET.Element("Object", {"type": TRANSACTION_TYPE,
                                          "guid": "10000000-0000-4000-8000-000000000002",
                                          "name": "CustomerCopy"})
    tx_part = ET.SubElement(transaction, "Part", {"type": "20000000-0000-4000-8000-000000000098"})
    level = ET.SubElement(tx_part, "Level", {"Name": "CustomerCopy",
                                               "Guid": "20000000-0000-4000-8000-000000000002",
                                               "Type": "CustomerCopy"})
    ET.SubElement(level, "Attribute", {"Guid": ATTRIBUTE_IDS["CustomerId"], "key": "True"}).text = "CustomerId"
    ET.SubElement(level, "Attribute", {"Guid": ATTRIBUTE_IDS["CustomerName"], "key": "False"}).text = "CustomerName"
    _write_xml(root / "Transaction" / "CustomerCopy.xml", transaction)


def _add_order_relation(root: Path) -> Path:
    table = ET.Element("Object", {"type": TABLE_TYPE,
                                    "guid": "40000000-0000-4000-8000-000000000003",
                                    "name": "Order"})
    part = ET.SubElement(table, "Part", {"type": "50000000-0000-4000-8000-000000000003"})
    key = ET.SubElement(part, "Key")
    ET.SubElement(key, "Item", {"guid": ATTRIBUTE_IDS["OrderId"]}).text = "OrderId"
    index = ET.SubElement(part, "Index", {"guid": "60000000-0000-4000-8000-000000000001",
                                           "type": "Duplicate", "role": ""})
    ET.SubElement(index, "Member", {"guid": ATTRIBUTE_IDS["CustomerId"]}).text = "CustomerId"
    _write_xml(root / "Table" / "Order.xml", table)

    transaction = ET.Element("Object", {"type": TRANSACTION_TYPE,
                                          "guid": "10000000-0000-4000-8000-000000000003",
                                          "name": "Order"})
    tx_part = ET.SubElement(transaction, "Part", {"type": "20000000-0000-4000-8000-000000000097"})
    level = ET.SubElement(tx_part, "Level", {"Name": "Order", "Guid": "20000000-0000-4000-8000-000000000003",
                                              "Type": "Order"})
    ET.SubElement(level, "Attribute", {"Guid": ATTRIBUTE_IDS["OrderId"], "key": "True"}).text = "OrderId"
    ET.SubElement(level, "Attribute", {"Guid": ATTRIBUTE_IDS["CustomerName"], "key": "False"}).text = "CustomerName"
    transaction_path = root / "Transaction" / "Order.xml"
    _write_xml(transaction_path, transaction)
    return transaction_path


def _assert(condition: bool, message: str) -> None:
    if not condition:
        raise AssertionError(message)


def _test_unique_fk_key_confirmation() -> None:
    with tempfile.TemporaryDirectory(prefix="gx-writability-unique-fk-key-selftest-") as temp:
        root = Path(temp)
        _create_corpus(root)
        transaction_path = _add_order_relation(root)
        transaction_xml = ET.fromstring(transaction_path.read_bytes())
        level = next(node for node in transaction_xml.iter()
                     if node.tag.rsplit("}", 1)[-1].casefold() == "level")
        ET.SubElement(level, "Attribute", {"Guid": ATTRIBUTE_IDS["CustomerId"], "key": "False"}).text = "CustomerId"
        _write_xml(transaction_path, transaction_xml)

        request = operational.analyze_transaction(transaction_path, root,
                                                  front_id="unique-fk-key-front", include_request=True)
        automatic_row = next(item for item in request["levelAttributes"]
                             if item["attributeName"] == "CustomerId")
        _assert(automatic_row["classification"] == "unclassified-relation-pending"
                and automatic_row["writable"] is None
                and automatic_row["reasonCodes"] == ["inferred-fk-key"],
                "a unique inferred FK key must remain pending before human confirmation")
        decision = next(item for item in request["decisionRequest"]["manifestTemplate"]["decisions"]
                        if item["type"] == "resolve-inferred-relation"
                        and item["scope"]["targets"][0]["attribute"]["name"] == "CustomerId")
        manifest = copy.deepcopy(request["decisionRequest"]["manifestTemplate"])
        manifest["decisions"] = [copy.deepcopy(decision)]
        manifest["decisions"][0].update({
            "actor": "synthetic-reviewer", "approvedAt": "2026-10-02T17:00:00Z",
            "approvalReceipt": {"reference": "unique-fk-key-approval", "text": "Approved for synthetic test"},
            "justification": "The exact FK key relation is confirmed in this synthetic fixture.",
        })
        applied = operational.analyze_transaction(
            transaction_path, root, front_id="unique-fk-key-front",
            decision_raw=operational.canonical_bytes(manifest), include_request=True)
        result_row = next(item for item in applied["levelAttributes"]
                          if item["attributeName"] == "CustomerId")
        _assert(applied["decisionResults"][0]["status"] == "applied"
                and result_row["writable"] is None
                and result_row["contextualAnalysis"]["classification"] == "extended-fk-key"
                and result_row["contextualAnalysis"]["writable"] is True
                and result_row["effectiveWritable"] is True
                and result_row["decisionState"] == "applied",
                "a proof-backed unique FK confirmation should produce contextual extended-fk-key without mutating automatic analysis")


def _test_materialized_writability_parity() -> None:
    with tempfile.TemporaryDirectory(prefix="gx-writability-index-parity-selftest-") as temp:
        root = Path(temp)
        corpus = root / "corpus"
        corpus.mkdir()
        _create_corpus(corpus)
        index_path = root / "index.sqlite"
        build = subprocess.run(
            [sys.executable, "-B", str(SCRIPT_DIR / "Build-KbIntelligenceIndex.py"),
             "--source-root", str(corpus), "--output-path", str(index_path)],
            capture_output=True, text=True, check=False,
        )
        _assert(build.returncode == 0,
                f"synthetic index build failed: {build.stderr or build.stdout}")
        parity = subprocess.run(
            ["pwsh", "-NoProfile", "-File",
             str(SCRIPT_DIR / "Test-GeneXusKbIntelligenceWritabilityParity.ps1"),
             "-CorpusFolder", str(corpus), "-IndexPath", str(index_path), "-AsJson"],
            capture_output=True, text=True, check=False,
        )
        _assert(parity.returncode == 0,
                f"synthetic materialized parity failed: {parity.stderr or parity.stdout}")
        report = json.loads(parity.stdout)
        _assert(report.get("status") == "pass" and report.get("transactions") == 1
                and report.get("attributePairs", 0) > 0,
                "parity facade did not report the expected synthetic occurrence comparison")


def _test_new_selection_eligibility() -> None:
    views = [{"associationStatus": "resolved-level-type-and-table-key"}]
    automatic_positive = {
        "key-attribute": "key-attribute",
        "own-physical": "own-physical",
        "own-physical-indexed": "own-physical-indexed",
        "extended-fk-key": "extended-fk-key",
        "extended-subtype-key": "subtype-key",
    }
    for classification, reason_code in automatic_positive.items():
        targets = [{"occurrences": [{
            "classification": classification, "writable": True,
            "reasonCodes": [reason_code], "coverage": "complete-in-model",
        }]}]
        eligible, issues = operational._selection_eligibility(views, targets)
        _assert(eligible, f"automatic positive {classification} should permit target selection: {issues}")

    technical_target = [{"occurrences": [{
        "classification": "formula", "writable": False,
        "reasonCodes": ["formula"], "coverage": "complete-in-model",
    }]}]
    eligible, issues = operational._selection_eligibility(views, technical_target)
    _assert(not eligible and "new-target-contains-nonselectable-occurrence" in issues,
            "direct formula cause must remain a non-selectable target")


def _test_new_applies_transaction_binding_context() -> None:
    with tempfile.TemporaryDirectory(prefix="gx-writability-new-binding-selftest-") as temp:
        root = Path(temp)
        procedure_path = _create_corpus(root)
        _add_competing_customer_table(root)
        transaction_path = root / "Transaction" / "Customer.xml"
        transaction_xml = ET.fromstring(transaction_path.read_bytes())
        level = next(node for node in transaction_xml.iter()
                     if node.tag.rsplit("}", 1)[-1].casefold() == "level")
        level.attrib["Type"] = "UnresolvedType"
        _write_xml(transaction_path, transaction_xml)

        transaction = operational.analyze_transaction(
            transaction_path, root, front_id="synthetic-front", include_request=True,
        )
        binding_choices = [choice for choice in transaction["decisionRequest"]["decisionChoices"]
                           if choice.get("type") == "bind-table-group"]
        _assert(len(binding_choices) == 1,
                "unresolved Transaction association should expose one finite binding choice bundle")
        binding = next(template for template in binding_choices[0]["decisionTemplates"]
                       if template["scope"]["tableBindings"][0]["table"]["guid"] == TABLE_GUID)
        binding["actor"] = "test-user"
        binding["approvedAt"] = "2026-10-02T12:00:00Z"
        binding["approvalReceipt"] = {"reference": "fixture-bind", "text": "Table confirmada"}
        binding["justification"] = "Confirmação sintética da associação física"
        manifest = transaction["decisionRequest"]["manifestTemplate"]
        manifest["decisions"] = [binding]

        procedure = operational.analyze_procedure(procedure_path, root)
        customer_group = next(group for group in procedure["newBlocks"][0]["candidates"]
                              if group["table"]["guid"] == TABLE_GUID)
        _assert(not customer_group["selectable"],
                "an unresolved view must not be selectable before a binding decision")
        applied = operational._apply_decisions(
            operational.canonical_bytes(manifest), [procedure], root, None,
        )
        status = next(item for item in applied["decisionResults"]
                      if item["decisionId"] == binding["decisionId"])
        _assert(status["status"] == "applied",
                f"valid Transaction binding should apply through the New facade: {status}")
        customer_group = next(group for group in procedure["newBlocks"][0]["candidates"]
                              if group["table"]["guid"] == TABLE_GUID)
        _assert(customer_group["selectable"]
                and all(view["associationStatus"] == "resolved-level-type-and-table-key"
                        for view in customer_group["views"]),
                "New analysis must re-evaluate its view after the exact Table binding")

        stale_procedure = operational.analyze_procedure(procedure_path, root)
        stale_group_before = next(group for group in stale_procedure["newBlocks"][0]["candidates"]
                                  if group["table"]["guid"] == TABLE_GUID)
        automatic_association = stale_group_before["views"][0]["associationStatus"]
        original_apply_context = operational._apply_transaction_context_to_new_results
        mutated = False

        def mutate_proof_after_context(*args: Any, **kwargs: Any) -> Any:
            nonlocal mutated
            context_result = original_apply_context(*args, **kwargs)
            if not mutated:
                transaction_path.write_bytes(transaction_path.read_bytes() + b"\n")
                mutated = True
            return context_result

        operational._apply_transaction_context_to_new_results = mutate_proof_after_context
        stale_results = [stale_procedure]
        try:
            stale_applied = operational._apply_decisions(
                operational.canonical_bytes(manifest), stale_results, root, None,
            )
        finally:
            operational._apply_transaction_context_to_new_results = original_apply_context
        stale_status = next(item for item in stale_applied["decisionResults"]
                            if item["decisionId"] == binding["decisionId"])
        restored_group = next(group for group in stale_results[0]["newBlocks"][0]["candidates"]
                              if group["table"]["guid"] == TABLE_GUID)
        restored_occurrence = next(
            occurrence
            for assignment_target in restored_group["assignmentTargets"]
            for occurrence in assignment_target["occurrences"]
            if occurrence["occurrence"]["attribute"]["guid"] == ATTRIBUTE_IDS["CustomerName"]
        )
        _assert(stale_status["status"] == "stale"
                and "proof-changed-during-validation" in stale_status["reasonCodes"],
                "a Table-binding proof changed during combined New analysis must invalidate the decision")
        _assert(restored_group["views"][0]["associationStatus"] == automatic_association
                and restored_occurrence["contextualAnalysis"] is None
                and restored_occurrence["effectiveWritable"] == restored_occurrence["writable"]
                and restored_occurrence["decisionState"] == "stale",
                "invalidated Transaction context must be removed from New results before emitting effectives")


def _test_flat_front_model_overlays() -> None:
    with tempfile.TemporaryDirectory(prefix="gx-writability-flat-front-selftest-") as temp:
        root = Path(temp)
        corpus = root / "corpus"
        delta = root / "front"
        corpus_procedure = _create_corpus(corpus)
        delta.mkdir()

        transaction = ET.fromstring((corpus / "Transaction" / "Customer.xml").read_bytes())
        level = next(node for node in transaction.iter()
                     if node.tag.rsplit("}", 1)[-1].casefold() == "level")
        redundant = next(node for node in level
                         if node.tag.rsplit("}", 1)[-1].casefold() == "attribute"
                         and (node.text or "").strip() == "CustomerName")
        redundant.set("isRedundant", "True")
        flat_transaction = delta / "CustomerDelta.xml"
        _write_xml(flat_transaction, transaction)

        transaction_overlay = root / "transaction-overlay"
        transaction_overlay.mkdir()
        transaction_origins = operational._overlay_model_corpus(corpus, delta, transaction_overlay)
        transaction_overlay_path = "Transaction/CustomerDelta.xml"
        _assert(transaction_origins.get(transaction_overlay_path) == "delta"
                and transaction_origins.source_paths_by_overlay_path.get(transaction_overlay_path)
                == "CustomerDelta.xml",
                "a flat Transaction delta must be indexed by type while retaining its physical front path")
        transaction_result = operational.analyze_transaction(
            transaction_overlay / transaction_overlay_path, corpus, front_id="flat-transaction-front",
            delta_root=delta, model_root=transaction_overlay, root_kinds_by_path=transaction_origins,
            source_roots={"corpus": corpus, "delta": delta}, display_path=flat_transaction)
        redundant_row = next(item for item in transaction_result["levelAttributes"]
                             if item["attributeName"] == "CustomerName")
        _assert(redundant_row["isRedundant"] is True and redundant_row["effectiveWritable"] is False
                and redundant_row["identity"]["transaction"]["path"] == "CustomerDelta.xml"
                and transaction_result["transactionPath"] == str(flat_transaction.resolve()),
                "9-TXW must analyze the flat front Transaction and report its real path and redundant blocker")

        proof_model = operational.automatic._load_writability_model(transaction_overlay)
        operational._apply_overlay_source_paths(proof_model, transaction_origins)
        proof_model.source_roots = {"corpus": corpus, "delta": delta}
        proof_level = next(item for item in proof_model.levels
                           if item.transaction.get("path") == "CustomerDelta.xml")
        proof_files = operational._transaction_proof_files(proof_model, proof_level)
        _assert(any(item["rootKind"] == "delta" and item["path"] == "CustomerDelta.xml"
                    and (delta / item["path"]).is_file() for item in proof_files),
                "9-TXW proof paths for a flat delta must resolve to the original front file")

        formula_attribute = ET.fromstring((corpus / "Attribute" / "CustomerName.xml").read_bytes())
        properties = ET.SubElement(formula_attribute, "Properties")
        formula = ET.SubElement(properties, "Property")
        ET.SubElement(formula, "Name").text = "Formula"
        ET.SubElement(formula, "Value").text = "&ComputedValue"
        _write_xml(delta / "CustomerName.xml", formula_attribute)
        flat_procedure = delta / corpus_procedure.name
        flat_procedure.write_bytes(corpus_procedure.read_bytes())

        procedure_overlay = root / "procedure-overlay"
        procedure_overlay.mkdir()
        procedure_origins = operational._overlay_model_corpus(corpus, delta, procedure_overlay)
        procedure_result = operational.analyze_procedure(
            flat_procedure, corpus, delta, model_root=procedure_overlay,
            root_kinds_by_path=procedure_origins)
        formula_occurrences = [
            occurrence
            for block in procedure_result["newBlocks"]
            for candidate in block["candidates"]
            for target in candidate["assignmentTargets"]
            if target["assignment"].get("attribute", {}).get("guid") == ATTRIBUTE_IDS["CustomerName"]
            for occurrence in target["occurrences"]
        ]
        _assert(formula_occurrences and all(
            item["classification"] == "formula" and item["writable"] is False
            and item["effectiveCanAssignInNew"] is False
            and item["occurrence"]["attribute"]["rootKind"] == "delta"
            and item["occurrence"]["attribute"]["path"] == "CustomerName.xml"
            for item in formula_occurrences),
            "9-PNW must honor a flat formula Attribute delta and preserve its physical source identity")


def main() -> int:
    _test_unique_fk_key_confirmation()
    _test_materialized_writability_parity()
    _test_new_selection_eligibility()
    _test_new_applies_transaction_binding_context()
    _test_flat_front_model_overlays()
    cycle_fixture = [
        {"decisionId": "cycle-a", "dependsOnDecisionIds": ["cycle-b"]},
        {"decisionId": "cycle-b", "dependsOnDecisionIds": ["cycle-a"]},
        {"decisionId": "dependent", "dependsOnDecisionIds": ["cycle-a"]},
        {"decisionId": "independent", "dependsOnDecisionIds": []},
    ]
    ordered, cycle_ids = operational._topological_decisions(cycle_fixture)
    _assert(cycle_ids == {"cycle-a", "cycle-b"},
            "only decisions inside a dependency cycle should be classified as cyclic")
    ordered_ids = [item["decisionId"] for item in ordered]
    _assert(ordered_ids.index("cycle-a") < ordered_ids.index("dependent"),
            "cycle members should be processed before their dependent decisions")
    dependency_fixture = [
        {"decisionId": "root", "dependsOnDecisionIds": []},
        {"decisionId": "middle", "dependsOnDecisionIds": ["root"]},
    ]
    closure = operational._decision_dependency_closure(
        {"dependsOnDecisionIds": ["middle"]}, {"root": "digest-root", "middle": "digest-middle"},
        {item["decisionId"]: item for item in dependency_fixture})
    _assert(closure == [("middle", "digest-middle"), ("root", "digest-root")],
            "decision inventory digests should include the exact transitive predecessor closure")

    with tempfile.TemporaryDirectory(prefix="gx-writability-invalid-cli-selftest-") as temp:
        missing = Path(temp) / "missing"
        command = [sys.executable, "-B", str(Path(operational.__file__).resolve()),
                   "--corpus-root", str(missing), "--procedure-path", str(missing)]
        failure = subprocess.run(command, capture_output=True, text=True, check=False)
        _assert(failure.returncode != 0 and not failure.stdout,
                "operational execution errors must use a nonzero exit and keep diagnostics on stderr")

    source = '"New // /* doubled "" quote EndNew"\n/* New\nEndNew */\nNew\nA = 1\nEndNew\n'
    blocks = operational.extract_new_blocks(source)
    _assert(len(blocks) == 1 and len(blocks[0].assignments) == 1,
            "strings and both comment forms must not create phantom blocks")

    source_with_emoji = "😀\nNew\nA = 1\nEndNew\n"
    block = operational.extract_new_blocks(source_with_emoji)[0]
    _assert(block.start == source_with_emoji.index("New"), "offsets must count Unicode code points")
    _assert(block.assignments[0].start == source_with_emoji.index("A ="),
            "assignment offsets must use the same code-point coordinate system")

    try:
        operational.extract_new_blocks("New\nA = 1\n")
    except operational.OperationalError as exc:
        _assert("unmatched New" in str(exc), "unmatched New must be an explicit extraction error")
    else:
        raise AssertionError("unmatched New must not become new-no-blocks")

    try:
        operational.extract_new_blocks("New\n/* unfinished")
    except operational.OperationalError as exc:
        _assert("unterminated block comment" in str(exc), "bad delimiters must fail closed")
    else:
        raise AssertionError("unterminated block comment must fail closed")

    with tempfile.TemporaryDirectory(prefix="gx-writability-transaction-context-selftest-") as temp:
        root = Path(temp)
        _create_corpus(root)
        transaction_path = root / "Transaction" / "Customer.xml"
        transaction_xml = ET.fromstring(transaction_path.read_bytes())
        level = next(node for node in transaction_xml.iter()
                     if node.tag.rsplit("}", 1)[-1].casefold() == "level")
        level.attrib["Type"] = "UnresolvedType"
        _write_xml(transaction_path, transaction_xml)
        model, contextual_model, automatic_rows, contextual_levels = operational._transaction_snapshot(
            transaction_path, root)
        automatic_descriptive = next(row for row in automatic_rows if row.attribute_name == "CustomerName")
        context_level = next(item for item in contextual_levels if item.guid == LEVEL_GUID)
        table = next(item for item in contextual_model.tables if item.guid == TABLE_GUID)
        binding = {
            "transaction": operational._transaction_identity(context_level.transaction),
            "partType": context_level.part_type,
            "level": operational._level_identity(context_level),
            "table": operational._object_ref("corpus", table.path, "Table", table.guid, table.name),
            "views": [operational._view_identity(context_level)],
        }
        _assert(automatic_descriptive.classification == "unclassified-relation-pending"
                and automatic_descriptive.writable is None,
                "an unresolved Level/Table association should remain pending in automatic analysis")
        operational._apply_table_binding_context(contextual_model, contextual_levels, binding)
        contextual_rows = operational._classify_transaction_context(contextual_model, contextual_levels)
        contextual_descriptive = next(row for row in contextual_rows if row.attribute_name == "CustomerName")
        _assert(contextual_descriptive.classification == "own-physical"
                and contextual_descriptive.writable is True,
                "a validated contextual binding should reanalyze against the selected physical Table")
        _assert(automatic_descriptive.writable is None,
                "contextual binding must not mutate or upgrade the original automatic result")
        transaction_request = operational.analyze_transaction(
            transaction_path, root, front_id="synthetic-front", include_request=True)
        _assert(transaction_request["status"] == "pass"
                and transaction_request["operationalStatus"] == "attention"
                and len(transaction_request["decisionRequest"]["requests"]) == 1,
                "Transaction route should preserve diagnostic pass and expose an eligible binding request")
        manifest = copy.deepcopy(transaction_request["decisionRequest"]["manifestTemplate"])
        manifest["decisions"][0].update({
            "actor": "synthetic-reviewer", "approvedAt": "2026-10-02T15:40:00Z",
            "approvalReceipt": {"reference": "test-approval-1", "text": "Approved for synthetic test"},
            "justification": "The Table primary key matches the Level key.",
        })
        transaction_applied = operational.analyze_transaction(
            transaction_path, root, front_id="synthetic-front",
            decision_raw=operational.canonical_bytes(manifest), include_request=True)
        _assert(transaction_applied["decisionResults"][0]["status"] == "applied",
                "a current, proof-backed bind-table-group decision should apply")
        applied_row = next(item for item in transaction_applied["levelAttributes"]
                           if item["attributeName"] == "CustomerName")
        _assert(applied_row["writable"] is None and applied_row["effectiveWritable"] is True
                and applied_row["decisionState"] == "applied"
                and applied_row["contextualAnalysis"]["classification"] == "own-physical",
                "Transaction façade data should preserve automatic and contextual writability separately")
        pwsh = shutil.which("pwsh")
        _assert(pwsh is not None, "PowerShell 7 is required for the Transaction façade integration check")
        facade_path = Path(operational.__file__).with_name("Test-GeneXusTransactionWritability.ps1")
        request_path = root / "transaction-request.json"
        facade_request = subprocess.run(
            [pwsh, "-NoProfile", "-File", str(facade_path), "-TransactionPath", str(transaction_path),
             "-CorpusFolder", str(root), "-FrontId", "synthetic-front", "-RequestPath", str(request_path),
             "-AsJson"], capture_output=True, text=True, check=False)
        _assert(facade_request.returncode == 0,
                f"Transaction PowerShell request route failed: {facade_request.stderr}")
        facade_request_payload = json.loads(facade_request.stdout)
        _assert(request_path.is_file() and facade_request_payload["operationalStatus"] == "attention",
                "Transaction PowerShell façade should publish the request and preserve diagnostic pass")
        decision_path = root / "transaction-decision.json"
        decision_path.write_bytes(operational.canonical_bytes(manifest))
        facade_applied = subprocess.run(
            [pwsh, "-NoProfile", "-File", str(facade_path), "-TransactionPath", str(transaction_path),
             "-CorpusFolder", str(root), "-FrontId", "synthetic-front", "-DecisionPath", str(decision_path),
             "-AsJson"], capture_output=True, text=True, check=False)
        _assert(facade_applied.returncode == 0,
                f"Transaction PowerShell decision route failed: {facade_applied.stderr}")
        facade_applied_payload = json.loads(facade_applied.stdout)
        facade_applied_row = next(item for item in facade_applied_payload["levelAttributes"]
                                  if item["attributeName"] == "CustomerName")
        _assert(facade_applied_payload["status"] == "pass"
                and facade_applied_payload["decisionResults"][0]["status"] == "applied"
                and facade_applied_row["effectiveWritable"] is True,
                "Transaction PowerShell façade should expose applied receipt-backed contextual analysis")

    with tempfile.TemporaryDirectory(prefix="gx-writability-relation-context-selftest-") as temp:
        root = Path(temp)
        _create_corpus(root)
        order_path = _add_order_relation(root)
        relation_request = operational.analyze_transaction(order_path, root, front_id="relation-front",
                                                           include_request=True)
        target_row = next(item for item in relation_request["levelAttributes"]
                          if item["attributeName"] == "CustomerName")
        _assert(target_row["classification"] == "extended-fk-descriptive"
                and target_row["writable"] is False,
                "an indexed relation to a descriptive Attribute should remain automatically non-writable")
        relation_choices = [item for item in relation_request["decisionRequest"]["requests"]
                            if item["type"] == "reject-inferred-relation"]
        _assert(len(relation_choices) == 1,
                "an exact inferred relation should expose one reject-inferred-relation request")
        relation_manifest = copy.deepcopy(relation_request["decisionRequest"]["manifestTemplate"])
        relation_manifest["decisions"][0].update({
            "actor": "synthetic-reviewer", "approvedAt": "2026-10-02T15:40:00Z",
            "approvalReceipt": {"reference": "relation-approval-1", "text": "Approved for synthetic test"},
            "justification": "The index is not a foreign-key relation in this fixture.",
        })
        relation_applied = operational.analyze_transaction(
            order_path, root, front_id="relation-front",
            decision_raw=operational.canonical_bytes(relation_manifest), include_request=True)
        relation_result = relation_applied["decisionResults"][0]
        relation_row = next(item for item in relation_applied["levelAttributes"]
                            if item["attributeName"] == "CustomerName")
        _assert(relation_result["status"] == "applied"
                and relation_row["writable"] is False
                and relation_row["effectiveWritable"] is True
                and relation_row["contextualAnalysis"]["classification"] == "own-physical",
                f"rejecting one inferred edge should reanalyze context while preserving automatic false: "
                f"decision={relation_result}, row={relation_row}")

    with tempfile.TemporaryDirectory(prefix="gx-writability-relation-resolution-selftest-") as temp:
        root = Path(temp)
        _create_corpus(root)
        _add_competing_customer_table(root)
        order_path = _add_order_relation(root)
        relation_request = operational.analyze_transaction(order_path, root, front_id="resolve-front",
                                                           include_request=True)
        target_row = next(item for item in relation_request["levelAttributes"]
                          if item["attributeName"] == "CustomerName")
        choices = [item for item in relation_request["decisionRequest"]["decisionChoices"]
                   if item["type"] == "resolve-inferred-relation"]
        _assert(target_row["coverage"] == "partial" and len(choices) == 1
                and len(choices[0]["decisionTemplates"]) == 2,
                "an ambiguous inferred relation should expose a finite choice per compatible target Table")
        chosen_template = copy.deepcopy(choices[0]["decisionTemplates"][0])
        chosen_table_guid = chosen_template["scope"]["relations"][0]["targetTable"]["guid"]
        resolve_manifest = copy.deepcopy(relation_request["decisionRequest"]["manifestTemplate"])
        resolve_manifest["decisions"] = [chosen_template]
        resolve_manifest["decisions"][0].update({
            "actor": "synthetic-reviewer", "approvedAt": "2026-10-02T15:40:00Z",
            "approvalReceipt": {"reference": "resolve-approval-1", "text": "Approved for synthetic test"},
            "justification": "The index maps to this physical target Table.",
        })
        resolved = operational.analyze_transaction(
            order_path, root, front_id="resolve-front",
            decision_raw=operational.canonical_bytes(resolve_manifest), include_request=True)
        resolved_row = next(item for item in resolved["levelAttributes"]
                            if item["attributeName"] == "CustomerName")
        _assert(resolved["decisionResults"][0]["status"] == "applied"
                and resolved_row["writable"] is False
                and resolved_row["effectiveWritable"] is False
                and resolved_row["contextualAnalysis"]["coverage"] == "complete-in-model"
                and resolved_row["decisionState"] == "applied"
                and not resolved_row["pendingDecisions"]
                and chosen_table_guid in {"40000000-0000-4000-8000-000000000001",
                                         "40000000-0000-4000-8000-000000000002"},
                f"resolving an ambiguous edge should narrow context without granting writability: "
                f"decision={resolved['decisionResults']}, row={resolved_row}")

    with tempfile.TemporaryDirectory(prefix="gx-writability-transaction-delta-selftest-") as temp:
        root = Path(temp)
        corpus = root / "corpus"
        delta = root / "delta"
        _create_corpus(corpus)
        delta_transaction = delta / "Transaction" / "CustomerDelta.xml"
        delta_transaction.parent.mkdir(parents=True)
        delta_xml = ET.fromstring((corpus / "Transaction" / "Customer.xml").read_bytes())
        level = next(node for node in delta_xml.iter()
                     if node.tag.rsplit("}", 1)[-1].casefold() == "level")
        level.attrib["Type"] = "UnresolvedType"
        _write_xml(delta_transaction, delta_xml)
        pwsh = shutil.which("pwsh")
        facade_path = Path(operational.__file__).with_name("Test-GeneXusTransactionWritability.ps1")
        request_path = root / "delta-transaction-request.json"
        facade_request = subprocess.run(
            [pwsh, "-NoProfile", "-File", str(facade_path), "-TransactionPath", str(delta_transaction),
             "-CorpusFolder", str(corpus), "-DeltaRoot", str(delta), "-FrontId", "delta-front",
             "-RequestPath", str(request_path), "-AsJson"],
            capture_output=True, text=True, check=False)
        _assert(facade_request.returncode == 0,
                f"Transaction delta request route failed: {facade_request.stderr}")
        delta_payload = json.loads(facade_request.stdout)
        template = delta_payload["decisionRequest"]["manifestTemplate"]["decisions"][0]
        _assert(template["scope"]["tableBindings"][0]["transaction"]["rootKind"] == "delta"
                and any(item["rootKind"] == "delta" for item in template["proofFiles"])
                and delta_payload["decisionRequest"]["deltaRoot"] == str(delta.resolve()),
                "Transaction overlay request should identify delta objects and prove their original files")
        manifest = copy.deepcopy(delta_payload["decisionRequest"]["manifestTemplate"])
        manifest["decisions"][0].update({
            "actor": "synthetic-reviewer", "approvedAt": "2026-10-02T15:40:00Z",
            "approvalReceipt": {"reference": "delta-approval-1", "text": "Approved for synthetic test"},
            "justification": "The front Transaction Level maps to the selected physical Table.",
        })
        decision_path = root / "delta-transaction-decision.json"
        decision_path.write_bytes(operational.canonical_bytes(manifest))
        facade_applied = subprocess.run(
            [pwsh, "-NoProfile", "-File", str(facade_path), "-TransactionPath", str(delta_transaction),
             "-CorpusFolder", str(corpus), "-DeltaRoot", str(delta), "-FrontId", "delta-front",
             "-DecisionPath", str(decision_path), "-AsJson"],
            capture_output=True, text=True, check=False)
        _assert(facade_applied.returncode == 0,
                f"Transaction delta decision route failed: {facade_applied.stderr}")
        applied_payload = json.loads(facade_applied.stdout)
        applied_customer = next(item for item in applied_payload["levelAttributes"]
                                if item["attributeName"] == "CustomerName")
        _assert(bool(applied_payload["decisionResults"])
                and applied_payload["decisionResults"][0]["status"] == "applied"
                and applied_customer["effectiveWritable"] is True,
                f"Transaction delta decision should revalidate proof against the external corpus and delta roots: "
                f"{applied_payload}")

    with tempfile.TemporaryDirectory(prefix="gx-writability-transaction-binding-choice-selftest-") as temp:
        root = Path(temp)
        _create_corpus(root)
        transaction_path = root / "Transaction" / "Customer.xml"
        _add_competing_customer_table(root)
        transaction_xml = ET.fromstring(transaction_path.read_bytes())
        level = next(node for node in transaction_xml.iter()
                     if node.tag.rsplit("}", 1)[-1].casefold() == "level")
        level.attrib["Type"] = "UnresolvedType"
        _write_xml(transaction_path, transaction_xml)
        request = operational.analyze_transaction(transaction_path, root, front_id="binding-choice-front",
                                                  include_request=True)
        choices = [item for item in request["decisionRequest"]["decisionChoices"]
                   if item["type"] == "bind-table-group"]
        _assert(len(choices) == 1 and len(choices[0]["decisionTemplates"]) == 2
                and not request["decisionRequest"]["manifestTemplate"]["decisions"],
                "ambiguous physical Table binding must be presented as a choice, not simultaneous approvals")
        binding_manifest = copy.deepcopy(request["decisionRequest"]["manifestTemplate"])
        binding_manifest["decisions"] = [copy.deepcopy(choices[0]["decisionTemplates"][1])]
        binding_manifest["decisions"][0].update({
            "actor": "synthetic-reviewer", "approvedAt": "2026-10-02T15:40:00Z",
            "approvalReceipt": {"reference": "choice-approval-1", "text": "Approved for synthetic test"},
            "justification": "The selected Table is one of the PK-compatible candidates.",
        })
        selected = operational.analyze_transaction(
            transaction_path, root, front_id="binding-choice-front",
            decision_raw=operational.canonical_bytes(binding_manifest), include_request=True)
        selected_row = next(item for item in selected["levelAttributes"]
                            if item["attributeName"] == "CustomerName")
        _assert(selected["decisionResults"][0]["status"] == "applied"
                and selected_row["writable"] is None and selected_row["effectiveWritable"] is True
                and selected_row["contextualAnalysis"]["classification"] == "own-physical",
                "selecting one ambiguous Table should reanalyze only that context and keep auto unchanged")

    with tempfile.TemporaryDirectory(prefix="gx-writability-operational-selftest-") as temp:
        root = Path(temp)
        procedure_path = _create_corpus(root)
        result = operational.analyze_procedure(procedure_path, root)
        evidence_schema_path = Path(operational.__file__).with_name("gx-writability-evidence.schema.json")
        evidence_schema = operational.loads_strict(evidence_schema_path.read_bytes())
        automatic_rows = operational.automatic.build_corpus_writability(
            root, operational.automatic._type_guid(operational.automatic._catalog_types(), "Transaction") or "")
        for row in automatic_rows:
            operational._validate_schema_value(row.evidence_envelope(), evidence_schema, evidence_schema)
        _assert(result["status"] == "pass" and result["operationalStatus"] == "clear",
                "one proven physical Table with unambiguous writable assignments should pass without a human selection")
        _assert(result["newBlocksScanned"] == 1, "one real New block should be found")
        new_block = result["newBlocks"][0]
        _assert(new_block["candidateState"] == "candidate" and len(new_block["candidates"]) == 1,
                "assignments supported by complementary occurrences in one Table should form one candidate")
        _assert([item["name"] for item in new_block["assignments"]] == ["CustomerId", "CustomerName"],
                "all insert-body assignments should be retained; When Duplicate assignments are separate")
        first_ref = new_block["assignments"][0]["assignment"]
        source_text = operational._procedure_source(procedure_path)[2]
        _assert(first_ref["sourceSha256"] == hashlib.sha256(source_text.encode("utf-8")).hexdigest(),
                "assignment identity must include the exact parser Source digest")
        pwsh = shutil.which("pwsh")
        _assert(pwsh is not None, "PowerShell 7 is required for the facade integration check")
        facade_path = Path(operational.__file__).with_name("Test-GeneXusNewWritableTargets.ps1")
        facade = subprocess.run(
            [pwsh, "-NoProfile", "-File", str(facade_path), "-ProcedurePath", str(procedure_path),
             "-CorpusFolder", str(root), "-AsJson"],
            capture_output=True, text=True, check=False)
        _assert(facade.returncode == 0, f"PowerShell façade failed: {facade.stderr}")
        facade_payload = json.loads(facade.stdout)
        _assert(facade_payload["status"] == "pass" and facade_payload["findings"][0]["assignments"][0]["identityStatus"] == "resolved",
                "PowerShell façade should preserve structured operational results")
        readable = subprocess.run(
            [pwsh, "-NoProfile", "-File", str(facade_path), "-ProcedurePath", str(procedure_path),
             "-CorpusFolder", str(root)],
            capture_output=True, text=True, check=False)
        _assert(readable.returncode == 0 and "automatic=True effective=True" in readable.stdout,
                f"human-readable façade should show automatic and effective writability: {readable.stderr}")

    with tempfile.TemporaryDirectory(prefix="gx-writability-decision-selftest-") as temp:
        root = Path(temp)
        corpus = root / "corpus"
        delta = root / "delta"
        procedure_path = _create_corpus(corpus)
        _add_competing_customer_table(corpus)
        delta_procedure = delta / "Procedure" / "InsertCustomer.xml"
        delta_procedure.parent.mkdir(parents=True)
        delta_procedure.write_bytes(procedure_path.read_bytes())
        independent = ET.fromstring(procedure_path.read_bytes())
        independent.set("guid", "70000000-0000-4000-8000-000000000002")
        for node in independent.iter():
            if node.tag.rsplit("}", 1)[-1].casefold() == "source":
                node.text = "&id = 1\n"
        independent_path = delta / "Procedure" / "Independent.xml"
        _write_xml(independent_path, independent)
        for folder in ("Table", "Transaction"):
            source = corpus / folder / f"CustomerCopy.xml"
            target = delta / folder / source.name
            target.parent.mkdir(parents=True, exist_ok=True)
            target.write_bytes(source.read_bytes())
        delta_attribute = delta / "Attribute" / "CustomerName.xml"
        delta_attribute.parent.mkdir(parents=True, exist_ok=True)
        delta_attribute.write_bytes((corpus / "Attribute" / "CustomerName.xml").read_bytes())
        overlay = root / "overlay"
        overlay.mkdir()
        origins = operational._overlay_model_corpus(corpus, delta, overlay)
        _assert(origins["Table/CustomerCopy.xml"] == "delta",
                "overlay must mark a delta replacement as delta provenance")
        current = operational.analyze_procedure(delta_procedure, corpus, delta,
                                                model_root=overlay, root_kinds_by_path=origins)
        sibling = operational.analyze_procedure(independent_path, corpus, delta,
                                                model_root=overlay, root_kinds_by_path=origins)
        block_result = current["newBlocks"][0]
        _assert(len(block_result["candidates"]) == 2,
                "two physically distinct Tables with matching real views must remain separate candidates")
        _assert(all(candidate["selectable"] for candidate in block_result["candidates"]),
                "both complete, technically eligible Table groups should be selectable")
        customer_name_assignment = next(item for item in block_result["assignments"]
                                        if item["name"] == "CustomerName")
        _assert(customer_name_assignment["assignment"]["attribute"]["rootKind"] == "delta",
                "New assignment identity must preserve the selected Attribute's delta provenance")
        request = operational._decision_request([current, sibling], corpus, delta, "synthetic-front")
        manifest = request["manifestTemplate"]
        manifest["decisions"] = request["decisionChoices"][0]["decisionTemplates"]
        decision = manifest["decisions"][0]
        initial_digests = operational._decision_digests(
            decision, "synthetic-front", manifest["ruleVersion"], [block_result],
            corpus, delta, current, {})
        _assert(initial_digests[0] == decision["inventoryDigest"],
                "a freshly generated decision must reproduce its semantic inventory digest")
        decision["actor"] = "test-user"
        decision["approvedAt"] = "2026-10-02T12:00:00Z"
        decision["approvalReceipt"] = {"reference": "fixture-1", "text": "Table escolhida para o fixture"}
        decision["justification"] = "Confirmação sintética da origem física"
        out_of_scope = copy.deepcopy(manifest)
        out_of_scope["decisions"][0]["scope"]["newTargets"][0]["table"]["guid"] = (
            "40000000-0000-4000-8000-000000000099")
        out_of_scope_result = operational._apply_decisions(
            operational.canonical_bytes(out_of_scope), [current, sibling], corpus, delta)
        _assert(out_of_scope_result["decisionResults"][0]["status"] == "out-of-scope",
                "a Table identity outside the current candidate set should be out-of-scope")
        after_out_of_scope = operational._decision_digests(
            decision, "synthetic-front", manifest["ruleVersion"], [block_result],
            corpus, delta, current, {})
        _assert(after_out_of_scope[0] == decision["inventoryDigest"],
                "out-of-scope diagnostics must not alter the semantic inventory of a request")

        cycle_manifest = copy.deepcopy(manifest)
        cycle_decisions = []
        for identifier, dependencies in (("cycle-a", ["cycle-b"]),
                                         ("cycle-b", ["cycle-a"]),
                                         ("cycle-dependent", ["cycle-a"])):
            item = copy.deepcopy(decision)
            item["decisionId"] = identifier
            item["dependsOnDecisionIds"] = dependencies
            cycle_decisions.append(item)
        cycle_manifest["decisions"] = cycle_decisions
        cycle_result = operational._apply_decisions(
            operational.canonical_bytes(cycle_manifest), [current, sibling], corpus, delta)
        _assert([item["status"] for item in cycle_result["decisionResults"]]
                == ["conflicting", "conflicting", "stale"],
                "cycle members should conflict while transitive dependents become stale")
        after_diagnostic_digests = operational._decision_digests(
            decision, "synthetic-front", manifest["ruleVersion"], [block_result],
            corpus, delta, current, {})
        _assert(after_diagnostic_digests[0] == decision["inventoryDigest"],
                "diagnostic decisions must not alter the semantic inventory of a request")

        independent_path.write_bytes(independent_path.read_bytes() + b"\n")
        sibling = operational.analyze_procedure(independent_path, corpus, delta,
                                                model_root=overlay, root_kinds_by_path=origins)
        applied = operational._apply_decisions(operational.canonical_bytes(manifest), [current, sibling], corpus, delta)
        _assert(applied["decisionResults"][0]["status"] == "applied",
                f"a current exact selection with stable proofs and receipt should apply: {applied['decisionResults'][0]}")
        _assert(block_result["selectedTableGuid"] == decision["scope"]["newTargets"][0]["table"]["guid"],
                "selection must bind the New block to the exact chosen physical Table")
        _assert(all(occurrence["effectiveWritable"] == occurrence["writable"]
                    for group in block_result["candidates"] for target in group["assignmentTargets"]
                    for occurrence in target["occurrences"]),
                "Table selection alone must not change automatic writability")
        decision_path = root / "decisions.json"
        decision_path.write_bytes(operational.canonical_bytes(manifest))
        facade_path = Path(operational.__file__).with_name("Test-GeneXusNewWritableTargets.ps1")
        facade_json = subprocess.run(
            [pwsh, "-NoProfile", "-File", str(facade_path), "-FrontFolder", str(delta),
             "-CorpusFolder", str(corpus), "-FrontId", "synthetic-front",
             "-DecisionPath", str(decision_path), "-AsJson"],
            capture_output=True, text=True, check=False)
        _assert(facade_json.returncode == 0, f"decision façade JSON call failed: {facade_json.stderr}")
        facade_decision_payload = json.loads(facade_json.stdout)
        _assert(facade_decision_payload["decisionResults"][0]["status"] == "applied",
                "PowerShell façade should return the applied decision state")
        facade_readable = subprocess.run(
            [pwsh, "-NoProfile", "-File", str(facade_path), "-FrontFolder", str(delta),
             "-CorpusFolder", str(corpus), "-FrontId", "synthetic-front",
             "-DecisionPath", str(decision_path)],
            capture_output=True, text=True, check=False)
        _assert(facade_readable.returncode == 0 and "approvedBy=test-user" in facade_readable.stdout
                and "receipt=fixture-1" in facade_readable.stdout,
                f"human-readable façade should include the approval receipt: {facade_readable.stderr}")

        stale = operational.analyze_procedure(delta_procedure, corpus, delta,
                                              model_root=overlay, root_kinds_by_path=origins)
        sibling = operational.analyze_procedure(independent_path, corpus, delta,
                                                model_root=overlay, root_kinds_by_path=origins)
        request = operational._decision_request([stale, sibling], corpus, delta, "synthetic-front")
        manifest = request["manifestTemplate"]
        manifest["decisions"] = request["decisionChoices"][0]["decisionTemplates"]
        decision = manifest["decisions"][0]
        decision["actor"] = "test-user"
        decision["approvedAt"] = "2026-10-02T12:00:00Z"
        decision["approvalReceipt"] = {"reference": "fixture-2", "text": "Table escolhida para o fixture"}
        decision["justification"] = "Confirmação sintética da origem física"
        table_path = delta / "Table" / "CustomerCopy.xml"
        table_path.write_bytes(table_path.read_bytes() + b"\n")
        stale_overlay = root / "overlay-stale"
        stale_overlay.mkdir()
        stale_origins = operational._overlay_model_corpus(corpus, delta, stale_overlay)
        reevaluated = operational.analyze_procedure(delta_procedure, corpus, delta,
                                                    model_root=stale_overlay, root_kinds_by_path=stale_origins)
        sibling = operational.analyze_procedure(independent_path, corpus, delta,
                                                model_root=stale_overlay, root_kinds_by_path=stale_origins)
        stale_result = operational._apply_decisions(operational.canonical_bytes(manifest),
                                                    [reevaluated, sibling], corpus, delta)
        _assert(stale_result["decisionResults"][0]["status"] == "stale",
                "a changed proof file must invalidate a previously prepared selection")

    with tempfile.TemporaryDirectory(prefix="gx-writability-decision-selftest-") as temp:
        root = Path(temp)
        corpus = root / "corpus"
        delta = root / "delta"
        procedure_path = _create_corpus(corpus)
        _add_competing_customer_table(corpus)
        delta_procedure = delta / "Procedure" / "InsertCustomer.xml"
        delta_procedure.parent.mkdir(parents=True)
        delta_procedure.write_bytes(procedure_path.read_bytes())
        independent = ET.fromstring(procedure_path.read_bytes())
        independent.set("guid", "70000000-0000-4000-8000-000000000002")
        for node in independent.iter():
            if node.tag.rsplit("}", 1)[-1].casefold() == "source":
                node.text = "&id = 1\n"
        independent_path = delta / "Procedure" / "Independent.xml"
        _write_xml(independent_path, independent)
        for folder in ("Table", "Transaction"):
            source = corpus / folder / f"CustomerCopy.xml"
            target = delta / folder / source.name
            target.parent.mkdir(parents=True, exist_ok=True)
            target.write_bytes(source.read_bytes())
        overlay = root / "overlay"
        overlay.mkdir()
        origins = operational._overlay_model_corpus(corpus, delta, overlay)
        _assert(origins["Table/CustomerCopy.xml"] == "delta",
                "overlay must mark a delta replacement as delta provenance")
        current = operational.analyze_procedure(delta_procedure, corpus, delta,
                                                model_root=overlay, root_kinds_by_path=origins)
        sibling = operational.analyze_procedure(independent_path, corpus, delta,
                                                model_root=overlay, root_kinds_by_path=origins)
        block_result = current["newBlocks"][0]
        _assert(len(block_result["candidates"]) == 2,
                "two physically distinct Tables with matching real views must remain separate candidates")
        _assert(all(candidate["selectable"] for candidate in block_result["candidates"]),
                "both complete, technically eligible Table groups should be selectable")
        request = operational._decision_request([current, sibling], corpus, delta, "synthetic-front")
        manifest = request["manifestTemplate"]
        manifest["decisions"] = request["decisionChoices"][0]["decisionTemplates"]
        decision = manifest["decisions"][0]
        decision["actor"] = "test-user"
        decision["approvedAt"] = "2026-10-02T12:00:00Z"
        decision["approvalReceipt"] = {"reference": "fixture-1", "text": "Table escolhida para o fixture"}
        decision["justification"] = "Confirmação sintética da origem física"
        independent_path.write_bytes(independent_path.read_bytes() + b"\n")
        sibling = operational.analyze_procedure(independent_path, corpus, delta,
                                                model_root=overlay, root_kinds_by_path=origins)
        applied = operational._apply_decisions(operational.canonical_bytes(manifest), [current, sibling], corpus, delta)
        _assert(applied["decisionResults"][0]["status"] == "applied",
                "a current exact selection with stable proofs and receipt should apply")
        _assert(block_result["selectedTableGuid"] == decision["scope"]["newTargets"][0]["table"]["guid"],
                "selection must bind the New block to the exact chosen physical Table")
        _assert(all(occurrence["effectiveWritable"] == occurrence["writable"]
                    for group in block_result["candidates"] for target in group["assignmentTargets"]
                    for occurrence in target["occurrences"]),
                "Table selection alone must not change automatic writability")

        stale = operational.analyze_procedure(delta_procedure, corpus, delta,
                                              model_root=overlay, root_kinds_by_path=origins)
        sibling = operational.analyze_procedure(independent_path, corpus, delta,
                                                model_root=overlay, root_kinds_by_path=origins)
        request = operational._decision_request([stale, sibling], corpus, delta, "synthetic-front")
        manifest = request["manifestTemplate"]
        manifest["decisions"] = request["decisionChoices"][0]["decisionTemplates"]
        decision = manifest["decisions"][0]
        decision["actor"] = "test-user"
        decision["approvedAt"] = "2026-10-02T12:00:00Z"
        decision["approvalReceipt"] = {"reference": "fixture-2", "text": "Table escolhida para o fixture"}
        decision["justification"] = "Confirmação sintética da origem física"
        table_path = delta / "Table" / "CustomerCopy.xml"
        table_path.write_bytes(table_path.read_bytes() + b"\n")
        stale_overlay = root / "overlay-stale"
        stale_overlay.mkdir()
        stale_origins = operational._overlay_model_corpus(corpus, delta, stale_overlay)
        reevaluated = operational.analyze_procedure(delta_procedure, corpus, delta,
                                                    model_root=stale_overlay, root_kinds_by_path=stale_origins)
        sibling = operational.analyze_procedure(independent_path, corpus, delta,
                                                model_root=stale_overlay, root_kinds_by_path=stale_origins)
        stale_result = operational._apply_decisions(operational.canonical_bytes(manifest),
                                                    [reevaluated, sibling], corpus, delta)
        _assert(stale_result["decisionResults"][0]["status"] == "stale",
                "a changed proof file must invalidate a previously prepared selection")

    print("OK: Test-GeneXusWritabilityOperationalSelfTest.py")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
