#!/usr/bin/env python3
"""Compara o casador de chamada direta com a alternância legada."""

from __future__ import annotations

import importlib.util
import sys
from pathlib import Path
from typing import Any


def _load_engine() -> Any:
    engine_path = Path(__file__).resolve().parent / "Build-KbIntelligenceIndex.py"
    spec = importlib.util.spec_from_file_location(
        "kb_intelligence_direct_call_matcher_selftest",
        engine_path,
    )
    if spec is None or spec.loader is None or spec.name is None:
        raise SystemExit(f"Unable to load index engine: {engine_path}")
    module = importlib.util.module_from_spec(spec)
    # Python 3.14 resolve dataclass no módulo já registrado.
    sys.modules[spec.name] = module
    try:
        spec.loader.exec_module(module)
    except Exception:
        sys.modules.pop(spec.name, None)
        raise
    return module


def _spans(pattern: Any, text: str) -> list[tuple[str, int]]:
    return [(match.group("name"), match.start("name")) for match in pattern.finditer(text)]


def _assert_same(matcher: Any, legacy: Any, text: str) -> None:
    got = _spans(matcher, text)
    expected = _spans(legacy, text)
    if got != expected:
        raise AssertionError(f"{text!r}: {got!r} != {expected!r}")


def main() -> int:
    engine = _load_engine()
    if engine.direct_call_pattern(set()) is not None:
        raise AssertionError("conjunto vazio deve devolver None")

    odd_names = {"Proc-Extra", "KProcFake"}
    odd = engine.direct_call_pattern(odd_names)
    legacy_odd = engine._legacy_direct_call_pattern(odd_names)
    if not isinstance(odd, type(legacy_odd)):
        raise AssertionError("nome fora de [A-Za-z_][A-Za-z0-9_]* deve devolver a alternância inteira")
    _assert_same(odd, legacy_odd, "Proc-Extra()\nKProcFake()")

    names = {"IProcFake", "SProcFake", "KProcFake", "PPrefixFake", "PPrefixFakeExtra"}
    matcher = engine.direct_call_pattern(names)
    if not isinstance(matcher, engine._IdentifierDirectCallMatcher):
        raise AssertionError("nomes ASCII devem usar o casador por token")
    legacy = engine._legacy_direct_call_pattern(names)

    samples = (
        "IProcFake()",
        "\u0130ProcFake()",
        "\u0131ProcFake()",
        "SProcFake()",
        "\u017fProcFake()",
        "KProcFake()",
        "\u212aProcFake()",
        "PPrefixFakeExtra()\nPPrefixFake()",
        "call \u212aProcFake() and KProcFake()",
    )
    for text in samples:
        _assert_same(matcher, legacy, text)

    sequence = (
        "\u0130ProcFake()",
        "IProcFake()",
        "\u0131ProcFake()",
        "IProcFake()",
        "\u017fProcFake()",
        "SProcFake()",
        "\u212aProcFake()",
        "KProcFake()",
    )
    for text in sequence:
        _assert_same(matcher, legacy, text)

    fresh = engine.direct_call_pattern(names)
    _assert_same(fresh, legacy, "KProcFake()")
    if fresh._alternation is not None:
        raise AssertionError("chamada ASCII não compila a alternância")
    _assert_same(fresh, legacy, "\u212aProcFake()")
    compiled = fresh._alternation
    if compiled is None:
        raise AssertionError("a primeira chamada com U+212A deve compilar a alternância")
    _assert_same(fresh, legacy, "IProcFake()")
    _assert_same(fresh, legacy, "\u0130ProcFake()")
    if fresh._alternation is not compiled:
        raise AssertionError("a alternância deve ser compilada uma vez e reutilizada")

    print("OK: Test-KbIntelligenceDirectCallMatcherSelfTest.py")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
