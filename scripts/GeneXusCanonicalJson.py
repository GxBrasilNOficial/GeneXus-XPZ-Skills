#!/usr/bin/env python3
"""Strict shared JSON decoding and canonical UTF-8 serialization."""

from __future__ import annotations

import json
import unicodedata
from typing import Any


class CanonicalJsonError(ValueError):
    pass


def _reject_duplicate_pairs(pairs: list[tuple[str, Any]]) -> dict[str, Any]:
    result: dict[str, Any] = {}
    for key, value in pairs:
        if key in result:
            raise CanonicalJsonError(f"duplicate JSON key: {key!r}")
        result[key] = value
    return result


def _reject_float(value: str) -> None:
    raise CanonicalJsonError(f"floating-point JSON value is not allowed: {value}")


def _reject_constant(value: str) -> None:
    raise CanonicalJsonError(f"non-standard JSON constant is not allowed: {value}")


def _normalize(value: Any, path: str = "$" ) -> Any:
    if isinstance(value, str):
        return unicodedata.normalize("NFC", value)
    if value is None or isinstance(value, bool) or isinstance(value, int):
        return value
    if isinstance(value, float):
        raise CanonicalJsonError(f"floating-point value is not allowed at {path}")
    if isinstance(value, list):
        return [_normalize(item, f"{path}[{index}]") for index, item in enumerate(value)]
    if isinstance(value, dict):
        normalized: dict[str, Any] = {}
        original_keys: dict[str, str] = {}
        for key, item in value.items():
            if not isinstance(key, str):
                raise CanonicalJsonError(f"non-string object key at {path}")
            normalized_key = unicodedata.normalize("NFC", key)
            if normalized_key in normalized:
                prior = original_keys[normalized_key]
                raise CanonicalJsonError(
                    f"JSON keys collide after NFC normalization at {path}: {prior!r} and {key!r}"
                )
            original_keys[normalized_key] = key
            normalized[normalized_key] = _normalize(item, f"{path}.{normalized_key}")
        return normalized
    raise CanonicalJsonError(f"unsupported JSON value at {path}: {type(value).__name__}")


def loads_strict(raw: bytes | str) -> Any:
    """Decode UTF-8 JSON, rejecting BOM, duplicate keys, floats, and invalid constants."""
    if isinstance(raw, bytes):
        if raw.startswith(b"\xef\xbb\xbf"):
            raise CanonicalJsonError("UTF-8 BOM is not allowed")
        try:
            text = raw.decode("utf-8", errors="strict")
        except UnicodeDecodeError as exc:
            raise CanonicalJsonError(f"JSON is not strict UTF-8: {exc}") from exc
    elif isinstance(raw, str):
        text = raw
        if text.startswith("\ufeff"):
            raise CanonicalJsonError("UTF-8 BOM is not allowed")
    else:
        raise CanonicalJsonError("JSON input must be bytes or str")
    try:
        value = json.loads(
            text,
            object_pairs_hook=_reject_duplicate_pairs,
            parse_float=_reject_float,
            parse_constant=_reject_constant,
        )
    except CanonicalJsonError:
        raise
    except (json.JSONDecodeError, RecursionError) as exc:
        raise CanonicalJsonError(f"invalid JSON: {exc}") from exc
    return _normalize(value)


def canonical_bytes(value: Any) -> bytes:
    """Serialize normalized JSON with ordinal keys, compact separators, UTF-8, and LF."""
    normalized = _normalize(value)
    try:
        text = json.dumps(
            normalized,
            ensure_ascii=False,
            sort_keys=True,
            separators=(",", ":"),
            allow_nan=False,
        )
        return text.encode("utf-8", errors="strict") + b"\n"
    except (TypeError, UnicodeEncodeError, ValueError) as exc:
        raise CanonicalJsonError(f"cannot serialize canonical JSON: {exc}") from exc


def canonical_text(value: Any) -> str:
    return canonical_bytes(value).decode("utf-8", errors="strict")
