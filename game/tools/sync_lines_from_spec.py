#!/usr/bin/env python3
"""Pull canonical RU/EN line texts from docs/levels/slice-01-spec.md into game/data/lines/lines_ru_en.yaml.

The spec (section 4 and 7.3) is the canon of the slice texts (spec v1.1, section 4 header).
This tool copies the texts; per-line metadata already in the YAML (speaker, emotion, style,
params, audio) is preserved. New IDs found in the spec are added with defaults
(speaker CLARA, style thought) and reported, so a programmer can check speaker/emotion.

Usage:
    python3 game/tools/sync_lines_from_spec.py           # rewrite the YAML
    python3 game/tools/sync_lines_from_spec.py --dry-run # only print what would change
"""
from __future__ import annotations

import argparse
import re
import sys
from pathlib import Path

import yaml

ROOT = Path(__file__).resolve().parents[2]
SPEC = ROOT / "docs" / "levels" / "slice-01-spec.md"
LINES = ROOT / "game" / "data" / "lines" / "lines_ru_en.yaml"
ID_RE = re.compile(r"^`?\**((?:DLG|FB|LOGIC|HINT)-[A-Z0-9-]+)\**`?$")
RU_RE = re.compile(r"^«(.*)»(?:\s*\(.*\))?$", re.S)
EN_RE = re.compile(r'^"(.*)"(?:\s*\(.*\))?$', re.S)
FIELD_ORDER = ("line_id", "speaker_id", "emotion", "style", "status", "params",
               "template_ru", "template_en", "text_ru", "text_en", "audio_ru", "audio_en", "note")
HEADER = """\
# Все реплики, мысли, подсказки, показ логики и реакции на ошибку (решение №11).
# Поля: line_id, speaker_id, emotion, style (speech / thought / letter), status, text_ru, text_en, audio_ru, audio_en.
# status: approved (сценарист, spec v1.1), test, draft, needed.
# text_en: null → в сборке на EN показывается RU с пометкой [EN]. text_ru: null → [TEXT NEEDED: <id>].
#
# КАНОН ТЕКСТОВ — docs/levels/slice-01-spec.md, разделы 4 и 7.3. Тексты сюда переносит
#   python3 game/tools/sync_lines_from_spec.py
# Здесь правьте только служебные поля (говорящий, эмоция, стиль, аудио, template_ru/en для реплик-шаблонов,
# где значения зависят от уровня) — тексты text_ru/text_en перезапишутся из спецификации.
"""


def section(text: str, start: str, end: str) -> str:
    a = text.index(start)
    b = text.index(end, a)
    return text[a:b]


def parse_rows(block: str) -> dict[str, tuple[str, str]]:
    found: dict[str, tuple[str, str]] = {}
    for raw in block.splitlines():
        if not raw.startswith("|"):
            continue
        cells = [c.strip() for c in raw.strip().strip("|").split("|")]
        line_id = None
        for c in cells:
            m = ID_RE.match(c)
            if m:
                line_id = m.group(1)
                break
        if not line_id:
            continue
        ru = en = None
        for i, c in enumerate(cells):
            m = RU_RE.match(c)
            if m and ru is None:
                ru = m.group(1)
                for c2 in cells[i + 1:]:
                    m2 = EN_RE.match(c2)
                    if m2:
                        en = m2.group(1)
                        break
                break
        if ru is not None:
            found[line_id] = (ru, en)
    return found


def parse_letter(block: str) -> tuple[str, str]:
    """DLG-INTRO-001: two-column table RU | EN right after its heading."""
    start = block.index("**DLG-INTRO-001**")
    ru_lines, en_lines = [], []
    for raw in block[start:].splitlines()[1:]:
        if raw.startswith("| RU") or raw.startswith("|---"):
            continue
        if not raw.startswith("|"):
            if ru_lines:
                break
            continue
        cells = [c.strip() for c in raw.strip().strip("|").split("|")]
        if len(cells) >= 2:
            ru_lines.append(cells[0])
            en_lines.append(cells[1])
    return "\n".join(ru_lines), "\n".join(en_lines)


def dump_entry(entry: dict) -> str:
    ordered = {k: entry[k] for k in FIELD_ORDER if k in entry}
    ordered.update({k: v for k, v in entry.items() if k not in ordered})
    text = yaml.safe_dump([ordered], allow_unicode=True, sort_keys=False, width=1000)
    return text


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--dry-run", action="store_true")
    args = ap.parse_args()
    spec = SPEC.read_text(encoding="utf-8")
    sec4 = section(spec, "## 4. Диалоги и реплики среза", "## 5. Головоломки среза")
    sec73 = section(spec, "### 7.3. Подсказки", "## 8. Данные для программиста")
    texts = parse_rows(sec4)
    texts.update(parse_rows(sec73))
    texts["DLG-INTRO-001"] = parse_letter(sec4)

    data = yaml.safe_load(LINES.read_text(encoding="utf-8"))
    entries = data["lines"]
    index = {e["line_id"]: e for e in entries}
    changed, added = [], []
    for line_id, (ru, en) in texts.items():
        e = index.get(line_id)
        if e is None:
            e = {"line_id": line_id, "speaker_id": "CLARA", "style": "thought", "status": "approved",
                 "text_ru": ru, "text_en": en, "audio_ru": None, "audio_en": None}
            entries.append(e)
            index[line_id] = e
            added.append(line_id)
            continue
        if e.get("text_ru") != ru or e.get("text_en") != en:
            changed.append(line_id)
        e["text_ru"], e["text_en"] = ru, en
        e["status"] = "approved"
        e.pop("note", None)  # notes were "text needed" reminders; the text is now canonical
    missing = sorted(set(index) - set(texts))
    print(f"spec: {len(texts)} lines; changed {len(changed)}, added {len(added)}; "
          f"in YAML but not in spec: {len(missing)}")
    if added:
        print("added (check speaker/style):", ", ".join(added))
    if missing:
        print("not in spec (kept as is):", ", ".join(missing))
    if args.dry_run:
        return 0
    out = [HEADER, "lines:\n"]
    for e in entries:
        out.append("  " + dump_entry(e).replace("\n", "\n  ").rstrip() + "\n")
    LINES.write_text("".join(out), encoding="utf-8")
    print(f"wrote {LINES.relative_to(ROOT)}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
