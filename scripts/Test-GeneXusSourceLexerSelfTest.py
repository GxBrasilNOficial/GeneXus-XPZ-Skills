#!/usr/bin/env python3
"""Self-test for the canonical GeneXus Source lexer/mask/classifier (increment 17a)."""

from __future__ import annotations

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

from GeneXusSourceLexer import (  # noqa: E402
    NATIVE_BLOCK_RE,
    OperationalError,
    classify_source_block,
    lex_source,
    mask_gx_source,
    scan_source,
)


def _tokens(source: str) -> list[tuple[str, str, int, int, int]]:
    return [(t.kind, t.value, t.start, t.end, t.line) for t in lex_source(source)]


def _assert(condition: bool, message: str) -> None:
    if not condition:
        raise AssertionError(message)


def main() -> int:
    _assert(_tokens("") == [], "empty source")
    _assert(
        _tokens("procX()")
        == [
            ("identifier", "procX", 0, 5, 1),
            ("punctuation", "(", 5, 6, 1),
            ("punctuation", ")", 6, 7, 1),
        ],
        "direct call tokens",
    )
    _assert(_tokens("'a'") == [("string", "'a'", 0, 3, 1)], "string token")
    _assert(
        _tokens("// c\nprocY()")
        == [
            ("identifier", "procY", 5, 10, 2),
            ("punctuation", "(", 10, 11, 2),
            ("punctuation", ")", 11, 12, 2),
        ],
        "line comment skipped",
    )
    _assert(
        _tokens("/* c */\nprocY()")
        == [
            ("identifier", "procY", 8, 13, 2),
            ("punctuation", "(", 13, 14, 2),
            ("punctuation", ")", 14, 15, 2),
        ],
        "block comment skipped",
    )

    for source, expected in (
        ('"a', "new-extraction-incomplete: unterminated string at offset 0"),
        ("/*", "new-extraction-incomplete: unterminated block comment"),
    ):
        try:
            lex_source(source)
        except OperationalError as exc:
            _assert(str(exc) == expected, f"message for {source!r}: {exc}")
        else:
            raise AssertionError(f"expected OperationalError for {source!r}")

    native = 'csharp x = "\\";'
    try:
        lex_source(native)
    except OperationalError as exc:
        _assert("backslash before quote" in str(exc), f"native message: {exc}")
    else:
        raise AssertionError("native backslash-before-quote must fail closed")

    masked = mask_gx_source("x = 'lit' // c\ncall()")
    _assert(masked.state == "masked", "mask state")
    _assert(masked.masked is not None, "masked text")
    _assert(len(masked.masked) == len("x = 'lit' // c\ncall()"), "mask length")
    _assert("\n" in masked.masked, "mask preserves newline")
    _assert("lit" not in masked.masked, "literal masked")
    _assert("call()" in masked.masked, "code after comment preserved")

    scan = scan_source("x = 'lit' // c\ncall()")
    _assert(scan.status == "ok" and scan.reason == "", "scan status")
    _assert(
        [(span.kind, span.start, span.end, span.line) for span in scan.spans]
        == [("string", 4, 9, 1), ("line-comment", 10, 14, 1)],
        "scan spans",
    )
    multiline = scan_source("x = 'a\nb'")
    _assert(multiline.status == "ok", "multiline scan status")
    _assert(multiline.spans[0].line == 1, "span line is the start line")
    _assert(NATIVE_BLOCK_RE.match("  csharp x") is not None, "native regex match")
    _assert(NATIVE_BLOCK_RE.match("  CSharp x") is not None, "native regex case")
    _assert(NATIVE_BLOCK_RE.match("  csharpX") is None, "native regex word boundary")

    crlf = "a = 'x'\r\nb()"
    crlf_masked = mask_gx_source(crlf)
    _assert(crlf_masked.state == "masked", "CRLF mask state")
    _assert(crlf_masked.masked.count("\r\n") == 1, "CRLF preserved")
    _assert(len(crlf_masked.masked) == len(crlf), "CRLF length")

    _assert(mask_gx_source("csharp\nx=1").state == "native-skip", "native skip")
    failed = mask_gx_source('"a')
    _assert(failed.state == "failed" and failed.masked is None, "failed mask")

    _assert(classify_source_block("<GxMultiForm x='1'/>") == "layout", "layout")
    _assert(classify_source_block("\ufeff  <GxMultiForm x='1'/>") == "layout", "layout with BOM")
    _assert(classify_source_block("Event 'X'\nEndEvent") == "events", "events")
    _assert(classify_source_block("EVENT 'X'\nENDEVENT") == "events", "uppercase events")
    _assert(classify_source_block("Sub Foo\nEndSub") == "events", "sub")
    _assert(classify_source_block("Sub(") == "events", "sub with parenthesis")
    _assert(classify_source_block("Substring('x', 1)") == "code", "substring is not sub")
    _assert(classify_source_block("<foo/>") == "serialized", "serialized")
    _assert(classify_source_block("x=1") == "code", "code")
    _assert(classify_source_block("") == "code", "empty is code")
    _assert(classify_source_block("  \n\t") == "code", "whitespace is code")

    # The mask is 1:1 and lex/mask derive from the same scanner: masking a source
    # must not change its length or line breaks, and only span characters change.
    corpus = ["procX()", "// c\nprocY()", "x = 'a' + procZ()", "Event 'X'\nEndEvent"]
    for source in corpus:
        result = mask_gx_source(source)
        scan = scan_source(source)
        _assert(scan.status == "ok", f"scan status for {source!r}")
        if result.state == "masked":
            _assert(len(result.masked) == len(source), f"1:1 mask for {source!r}")
            _assert(result.masked.count("\n") == source.count("\n"), f"newlines for {source!r}")
            span_chars = {index for span in scan.spans for index in range(span.start, span.end)}
            for index, char in enumerate(source):
                if index in span_chars and char not in "\r\n":
                    _assert(result.masked[index] == " ", f"masked char for {source!r}@{index}")
                else:
                    _assert(result.masked[index] == char, f"preserved char for {source!r}@{index}")
        comment_chars = {
            index
            for span in scan.spans
            if span.kind in ("line-comment", "block-comment")
            for index in range(span.start, span.end)
        }
        for token in lex_source(source):
            _assert(token.start not in comment_chars, f"token inside comment for {source!r}")

    print("OK: Test-GeneXusSourceLexerSelfTest.py")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
