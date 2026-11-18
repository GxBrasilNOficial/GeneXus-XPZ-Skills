#!/usr/bin/env python3
"""Canonical GeneXus Source lexer/mask/classification for KbIntelligence.

Owns the single scanner used by ``scan_source``, ``lex_source`` and
``mask_gx_source`` so the three share one state machine (no drift).
``Token`` and ``OperationalError`` live here and are re-exported by
``GeneXusWritabilityOperational``, which keeps the
``DecisionIssue(OperationalError)`` hierarchy intact.

Behavioral parity with the previous ``lex_source`` in
``GeneXusWritabilityOperational`` is byte-identical: tokens,
``OperationalError`` messages, ``csharp``/``java`` native lines and the
backslash-before-quote rule.
"""

from __future__ import annotations

import re
from dataclasses import dataclass

IDENTIFIER_START = re.compile(r"[^\W\d]", re.UNICODE)
NATIVE_BLOCK_RE = re.compile(r"[ \t]*(?:csharp|java)(?=[ \t\r\n]|$)", re.IGNORECASE)


class OperationalError(ValueError):
    pass


@dataclass(frozen=True)
class Token:
    kind: str
    value: str
    start: int
    end: int
    line: int


@dataclass(frozen=True)
class ScanSpan:
    """String or comment span, with the line where the span starts."""

    kind: str  # "string" | "line-comment" | "block-comment"
    start: int
    end: int
    line: int


@dataclass(frozen=True)
class ScanResult:
    spans: tuple[ScanSpan, ...]
    status: str  # "ok" | "unterminated-string" | "unterminated-block-comment" | "native-backslash-quote"
    reason: str


@dataclass(frozen=True)
class MaskResult:
    masked: str | None
    state: str  # "masked" | "native-skip" | "failed"
    reason: str


def _identifier_start(char: str) -> bool:
    return char == "_" or bool(IDENTIFIER_START.fullmatch(char))


def _identifier_continue(char: str) -> bool:
    return char == "_" or char.isalnum()


def _is_native_block_line(source: str, line_start: int) -> bool:
    return NATIVE_BLOCK_RE.match(source, line_start) is not None


def _has_native_block_line(source: str) -> bool:
    for line in source.split("\n"):
        if NATIVE_BLOCK_RE.match(line):
            return True
    return False


def _scan(source: str) -> tuple[list[Token], list[ScanSpan], str, str]:
    """Single scanner: tokens plus mask spans (strings and comments).

    Returns ``(tokens, spans, status, reason)`` where status is one of
    ``ok``, ``unterminated-block-comment``, ``native-backslash-quote``,
    ``unterminated-string``.  ``reason`` is the exact ``OperationalError``
    message used by ``lex_source``.
    """
    tokens: list[Token] = []
    spans: list[ScanSpan] = []
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
            start = i
            start_line = line
            end = i + 2
            while end < length and source[end] not in "\r\n":
                end += 1
            spans.append(ScanSpan("line-comment", start, end, start_line))
            i = end
            continue
        if source.startswith("/*", i):
            start = i
            start_line = line
            end = source.find("*/", i + 2)
            if end < 0:
                return tokens, spans, "unterminated-block-comment", (
                    "new-extraction-incomplete: unterminated block comment")
            line += source.count("\n", i, end + 2)
            last_lf = source.rfind("\n", i, end + 2)
            if last_lf >= 0:
                line_start = last_lf + 1
            spans.append(ScanSpan("block-comment", start, end + 2, start_line))
            i = end + 2
            continue
        if char in ('"', "'"):
            quote = char
            start = i
            start_line = line
            native = _is_native_block_line(source, line_start)
            i += 1
            closed = False
            while i < length:
                if native and source[i] == "\\" and i + 1 < length and source[i + 1] == quote:
                    return tokens, spans, "native-backslash-quote", (
                        "new-extraction-incomplete: backslash before quote on a native block line is not analyzed")
                if source[i] == quote:
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
                return tokens, spans, "unterminated-string", (
                    f"new-extraction-incomplete: unterminated string at offset {start}")
            tokens.append(Token("string", source[start:i], start, i, line))
            spans.append(ScanSpan("string", start, i, start_line))
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
    return tokens, spans, "ok", ""


def scan_source(source: str) -> ScanResult:
    """Return string/comment spans, status and reason from the shared scanner."""
    _tokens, spans, status, reason = _scan(source)
    return ScanResult(tuple(spans), status, reason)


def lex_source(source: str) -> list[Token]:
    r"""Lex code tokens while ignoring GeneXus string literals and comments.

    Double-slash and C-style block comments are ignored.  Inside a literal a
    backslash is an ordinary character and the first matching quote closes the
    literal; a doubled quote does not embed a quote.  Lines that start with a
    native block keyword (csharp or java) are not analyzed; a backslash before a
    quote on such a line is rejected, fail-closed.  Unterminated literals and
    unterminated block comments are rejected; newlines inside a literal are
    still accepted.
    """
    tokens, _spans, status, reason = _scan(source)
    if status != "ok":
        raise OperationalError(reason)
    return tokens


def mask_gx_source(source: str) -> MaskResult:
    """Mask string literals and comments 1:1, preserving length and line breaks.

    Returns ``MaskResult`` with:
    - ``masked``: same-length text with literal/comment characters replaced by
      spaces (``\r`` and ``\n`` preserved); ``None`` when failed.
    - ``state``: ``masked``, ``native-skip`` (block contains a ``csharp``/``java``
      native line; ``masked`` is the original text) or ``failed``.
    - ``reason``: human-readable cause for ``failed`` (empty otherwise).
    """
    if _has_native_block_line(source):
        return MaskResult(source, "native-skip", "native-block-line")
    _tokens, spans, status, reason = _scan(source)
    if status != "ok":
        return MaskResult(None, "failed", reason)
    masked = list(source)
    for span in spans:
        for j in range(span.start, span.end):
            if masked[j] not in ("\r", "\n"):
                masked[j] = " "
    return MaskResult("".join(masked), "masked", "")


def classify_source_block(text: str) -> str:
    """Classify a Source body as ``code``, ``events``, ``layout`` or ``serialized``.

    Mirrors ``Get-SourceBlockKind`` in ``Search-GeneXusXmlSourceBlock.ps1`` for the
    common cases: layout when the trimmed body starts with ``<GxMultiForm``,
    serialized when it starts with ``<``, events when a line starts with
    ``Event``/``Sub``, code otherwise.
    """
    s = text
    if s.startswith("\ufeff"):
        s = s[1:]
    trimmed = s.lstrip(" \t\r\n\f\v")
    if trimmed.lower().startswith("<gxmultiform"):
        return "layout"
    if trimmed.startswith("<"):
        return "serialized"
    if re.search(r"^\s*(?:Event|Sub)\b", s, re.IGNORECASE | re.MULTILINE):
        return "events"
    return "code"


__all__ = [
    "NATIVE_BLOCK_RE",
    "MaskResult",
    "OperationalError",
    "ScanResult",
    "ScanSpan",
    "Token",
    "classify_source_block",
    "lex_source",
    "mask_gx_source",
    "scan_source",
]
