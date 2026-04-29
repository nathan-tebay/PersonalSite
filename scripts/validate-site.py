#!/usr/bin/env python3
"""Static checks for the hand-written Tebay.dev site."""

from __future__ import annotations

import re
import sys
from html.parser import HTMLParser
from pathlib import Path
from urllib.parse import urlsplit


ROOT = Path(__file__).resolve().parents[1]
SKIP_DIRS = {".git", ".claude", ".codex", "node_modules"}
LOCAL_ATTRS = {"href", "src", "data-video-src"}


class PageParser(HTMLParser):
    def __init__(self) -> None:
        super().__init__()
        self.ids: list[str] = []
        self.refs: list[tuple[str, str]] = []
        self.imgs: list[dict[str, str]] = []

    def handle_starttag(self, tag: str, attrs: list[tuple[str, str | None]]) -> None:
        attr_map = {name: value or "" for name, value in attrs}
        if "id" in attr_map:
            self.ids.append(attr_map["id"])
        for attr in LOCAL_ATTRS:
            if attr in attr_map:
                self.refs.append((attr, attr_map[attr]))
        if tag == "img":
            self.imgs.append(attr_map)


def iter_files(pattern: str) -> list[Path]:
    files: list[Path] = []
    for path in ROOT.rglob(pattern):
        if any(part in SKIP_DIRS for part in path.relative_to(ROOT).parts):
            continue
        files.append(path)
    return sorted(files)


def is_external(ref: str) -> bool:
    parsed = urlsplit(ref)
    return bool(parsed.scheme) or ref.startswith("#") or ref.startswith("mailto:")


def local_target(page: Path, ref: str) -> Path | None:
    if not ref or is_external(ref):
        return None

    cleaned = ref.split("#", 1)[0].split("?", 1)[0]
    if not cleaned:
        return None
    if cleaned.startswith("/"):
        return ROOT / cleaned.lstrip("/")
    return (page.parent / cleaned).resolve()


def check_html(errors: list[str]) -> None:
    for page in iter_files("*.html"):
        rel_page = page.relative_to(ROOT)
        parser = PageParser()
        parser.feed(page.read_text(encoding="utf-8"))

        seen: set[str] = set()
        for element_id in parser.ids:
            if element_id in seen:
                errors.append(f"{rel_page}: duplicate id '{element_id}'")
            seen.add(element_id)

        for img in parser.imgs:
            if not img.get("alt"):
                errors.append(f"{rel_page}: image missing alt text: {img.get('src', '<unknown>')}")

        for attr, ref in parser.refs:
            target = local_target(page, ref)
            if target is None:
                continue
            try:
                target.relative_to(ROOT)
            except ValueError:
                errors.append(f"{rel_page}: {attr} escapes repo root: {ref}")
                continue
            if not target.exists():
                errors.append(f"{rel_page}: missing {attr} target: {ref}")


def check_css(errors: list[str]) -> None:
    url_re = re.compile(r"url\((['\"]?)(.*?)\1\)")
    for css in iter_files("*.css"):
        rel_css = css.relative_to(ROOT)
        text = css.read_text(encoding="utf-8")
        for match in url_re.finditer(text):
            ref = match.group(2)
            target = local_target(css, ref)
            if target is not None and not target.exists():
                errors.append(f"{rel_css}: missing url() target: {ref}")


def check_js(errors: list[str]) -> None:
    root_path_re = re.compile(r"(fetch|src|href|dataVideoSrc)\s*\(?\s*['\"]/", re.MULTILINE)
    for js in iter_files("*.js"):
        rel_js = js.relative_to(ROOT)
        text = js.read_text(encoding="utf-8")
        if root_path_re.search(text):
            errors.append(f"{rel_js}: root-relative path detected in JavaScript")


def main() -> int:
    errors: list[str] = []
    check_html(errors)
    check_css(errors)
    check_js(errors)

    if errors:
        print("Static validation failed:")
        for error in errors:
            print(f"- {error}")
        return 1

    print("Static validation passed.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
