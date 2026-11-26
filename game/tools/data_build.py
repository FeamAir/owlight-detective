#!/usr/bin/env python3
"""Convert game/data/**/*.yaml into game/content/game_data.json and validate it.

Usage:
    python3 game/tools/data_build.py            # build + validate, exit 1 on errors
    python3 game/tools/data_build.py --check    # validate only, do not write JSON

Authoring format: docs/levels/slice-01-spec.md, section 8.
Godot has no YAML parser, so the game reads the JSON produced here.
"""
from __future__ import annotations

import argparse
import itertools
import json
import sys
from pathlib import Path

import yaml

GAME_DIR = Path(__file__).resolve().parent.parent
DATA_DIR = GAME_DIR / "data"
OUT_FILE = GAME_DIR / "content" / "game_data.json"
LEVELS = ("easy", "normal", "hard")


class Report:
    def __init__(self) -> None:
        self.errors: list[str] = []
        self.warnings: list[str] = []

    def err(self, msg: str) -> None:
        self.errors.append(msg)

    def warn(self, msg: str) -> None:
        self.warnings.append(msg)


def load_yaml(rel: str):
    path = DATA_DIR / rel
    with path.open(encoding="utf-8") as fh:
        return yaml.safe_load(fh)


def by_id(items: list[dict], key: str, where: str, rep: Report) -> dict:
    out: dict = {}
    for it in items or []:
        ident = it.get(key)
        if ident is None:
            rep.err(f"{where}: entry without '{key}': {it}")
            continue
        if ident in out:
            rep.err(f"{where}: duplicate id {ident}")
        out[ident] = it
    return out


def load_all(rep: Report) -> dict:
    slice_ = load_yaml("slices/slice_01.yaml")["slice"]
    nb = load_yaml("world/notebook.yaml")
    values_test = load_yaml("values/test.yaml") or {}
    values_release = load_yaml("values/release.yaml") or {}
    data = {
        "meta": {"format": 1, "source": "game/data (YAML)", "generator": "game/tools/data_build.py"},
        "slice": slice_,
        "locations": by_id(load_yaml("world/locations.yaml")["locations"], "id", "locations", rep),
        "viewpoints": by_id(load_yaml("world/viewpoints.yaml")["viewpoints"], "id", "viewpoints", rep),
        "hotspots": by_id(load_yaml("world/hotspots.yaml")["hotspots"], "id", "hotspots", rep),
        "items": by_id(load_yaml("world/items.yaml")["items"], "id", "items", rep),
        "clues": by_id(nb.get("clues"), "id", "clues", rep),
        "documents": by_id(nb.get("documents"), "id", "documents", rep),
        "snapshots": by_id(nb.get("snapshots"), "id", "snapshots", rep),
        "codes": by_id(nb.get("codes"), "id", "codes", rep),
        "questions": by_id(nb.get("questions"), "id", "questions", rep),
        "goals": by_id(nb.get("goals"), "id", "goals", rep),
        "people": by_id(nb.get("people"), "id", "people", rep),
        "gates": by_id(load_yaml("world/gates.yaml")["gates"], "id", "gates", rep),
        "events": by_id(load_yaml("world/events.yaml")["events"], "id", "events", rep),
        "signs": by_id(load_yaml("world/signs.yaml")["signs"], "id", "signs", rep),
        "progression": load_yaml("progression.yaml"),
        "lines": by_id(load_yaml("lines/lines_ru_en.yaml")["lines"], "line_id", "lines", rep),
        "speakers": by_id(load_yaml("people/speakers.yaml")["speakers"], "id", "speakers", rep),
        "strings": load_yaml("ui/strings.yaml")["strings"],
        "values": {"test": values_test, "release": values_release},
        "difficulty_profile": load_yaml("difficulty_profile.yaml"),
        "layouts": load_yaml("puzzles/layouts.yaml") or {},
    }
    data["nodes"] = by_id(data["progression"]["nodes"], "id", "progression.nodes", rep)
    return data


# ---------------------------------------------------------------- reference checks

def check_line(d: dict, rep: Report, line_id, where: str) -> None:
    if line_id is None:
        return
    if line_id not in d["lines"]:
        rep.err(f"{where}: unknown line {line_id}")


def check_string(d: dict, rep: Report, key, where: str) -> None:
    if key is None:
        return
    if key not in d["strings"]:
        rep.err(f"{where}: unknown UI string key '{key}'")


def known_entity(d: dict, ident: str) -> bool:
    for coll in ("items", "clues", "documents", "snapshots", "gates", "questions", "goals"):
        if ident in d[coll]:
            return True
    return ident in d["nodes"]


def check_condition_flag(d: dict, rep: Report, flag: str, where: str) -> None:
    """Flags: seen.<x>, solved.<PZ>, has.<IT>, ev.<EV>, vp.<VP>, line.<DLG>, difficulty.<lvl>."""
    if not isinstance(flag, str) or "." not in flag:
        rep.err(f"{where}: malformed flag '{flag}'")
        return
    kind, ident = flag.split(".", 1)
    if kind == "solved" and ident not in d["nodes"]:
        rep.err(f"{where}: solved.{ident} — unknown puzzle")
    elif kind == "has" and ident not in d["items"]:
        rep.err(f"{where}: has.{ident} — unknown item")
    elif kind == "vp" and ident not in d["viewpoints"]:
        rep.err(f"{where}: vp.{ident} — unknown viewpoint")
    elif kind == "line" and ident not in d["lines"]:
        rep.err(f"{where}: line.{ident} — unknown line")
    elif kind == "ev" and ident not in d["events"]:
        rep.err(f"{where}: ev.{ident} — unknown event")
    elif kind == "difficulty" and ident not in LEVELS:
        rep.err(f"{where}: difficulty.{ident} — unknown level")
    elif kind not in ("seen", "solved", "has", "vp", "line", "ev", "difficulty"):
        rep.err(f"{where}: unknown flag kind '{kind}'")


def check_condition(d: dict, rep: Report, cond, where: str) -> None:
    if cond is None:
        return
    if isinstance(cond, str):
        check_condition_flag(d, rep, cond, where)
    elif isinstance(cond, dict):
        for key in ("flag", "not_flag"):
            if key in cond:
                check_condition_flag(d, rep, cond[key], where)


def check_effects(d: dict, rep: Report, eff: dict | None, where: str) -> None:
    if not eff:
        return
    check_line(d, rep, eff.get("line"), where)
    check_line(d, rep, eff.get("line_once"), where)
    for ln in eff.get("lines", []) or []:
        check_line(d, rep, ln, where)
    for g in eff.get("give", []) or []:
        if not known_entity(d, g):
            rep.err(f"{where}: give unknown entity {g}")
    q = eff.get("question")
    if q is not None:
        qid = q["id"] if isinstance(q, dict) else q
        if qid not in d["questions"]:
            rep.err(f"{where}: unknown question {qid}")
    snap = eff.get("autosnap")
    if isinstance(snap, dict):
        for lvl, sid in snap.items():
            if not isinstance(sid, str) or sid not in d["snapshots"]:
                rep.err(f"{where}: autosnap.{lvl} must be a snapshot ID, got {sid!r}")
    code = eff.get("autocode")
    if isinstance(code, dict):
        for lvl, cid in code.items():
            if cid not in d["codes"]:
                rep.err(f"{where}: unknown code {cid}")
    if "open_puzzle" in eff and eff["open_puzzle"] not in d["nodes"]:
        rep.err(f"{where}: unknown puzzle {eff['open_puzzle']}")
    if "puzzle" in eff and eff["puzzle"] not in d["nodes"]:
        rep.err(f"{where}: unknown puzzle {eff['puzzle']}")
    if "doc" in eff and eff["doc"] not in d["documents"]:
        rep.err(f"{where}: unknown document {eff['doc']}")
    tut = eff.get("tutorial_if")
    if tut:
        check_string(d, rep, tut.get("ui"), where)
        check_condition(d, rep, tut, where)


def check_references(d: dict, rep: Report) -> None:
    for vid, vp in d["viewpoints"].items():
        w = f"viewpoint {vid}"
        if vp.get("location") not in d["locations"]:
            rep.err(f"{w}: unknown location {vp.get('location')}")
        check_line(d, rep, vp.get("first_entry_line"), w)
        check_string(d, rep, f"vp.{vid}", w)
        for ex in vp.get("exits", []):
            if ex["to"] not in d["viewpoints"]:
                rep.err(f"{w}: exit to unknown viewpoint {ex['to']}")
            if "gate" in ex and ex["gate"] not in d["gates"]:
                rep.err(f"{w}: exit gate unknown {ex['gate']}")
            check_line(d, rep, ex.get("first_use_line"), w)
            if ex.get("on_locked", {}).get("open_puzzle") not in (None, *d["nodes"].keys()):
                rep.err(f"{w}: on_locked puzzle unknown")
        for hs in vp.get("hotspots", []):
            if hs not in d["hotspots"]:
                rep.err(f"{w}: unknown hotspot {hs}")
            elif d["hotspots"][hs].get("vp") != vid:
                rep.err(f"{w}: hotspot {hs} belongs to {d['hotspots'][hs].get('vp')}")
        eo = vp.get("on_enter_once_when")
        if eo:
            check_condition(d, rep, eo, w)
            check_line(d, rep, eo.get("line"), w)
        for ov in vp.get("overlays", []) or []:
            sign = ov.get("sign")
            if sign:
                pz, _, key = sign["from"].partition(".")
                if pz not in d["values"]["test"]:
                    rep.err(f"{w}: overlay {ov['id']} reads unknown values '{pz}'")
    for hid, hs in d["hotspots"].items():
        w = f"hotspot {hid}"
        if hs.get("vp") not in d["viewpoints"]:
            rep.err(f"{w}: unknown vp {hs.get('vp')}")
        elif hid not in d["viewpoints"][hs["vp"]].get("hotspots", []):
            rep.err(f"{w}: not listed in viewpoint {hs['vp']}")
        pos = hs.get("pos", {})
        for k in ("yaw", "pitch", "size_deg"):
            if not isinstance(pos.get(k), (int, float)):
                rep.err(f"{w}: pos.{k} missing")
        act = hs.get("action", {})
        check_effects(d, rep, act, w)
        for st in act.get("states", []) or []:
            check_condition(d, rep, st.get("when"), w)
            check_effects(d, rep, st, w)
        check_effects(d, rep, hs.get("on_first"), w)
        if "only_if" in hs:
            check_condition(d, rep, hs["only_if"], w)
        if act.get("kind") == "locked":
            check_line(d, rep, act.get("line"), w)
            if act.get("gate") not in d["gates"]:
                rep.err(f"{w}: unknown gate {act.get('gate')}")
    boundary = {b["hotspot"]: b for b in d["slice"].get("boundary_exits", [])}
    for hid, b in boundary.items():
        if hid not in d["hotspots"]:
            rep.err(f"slice.boundary_exits: unknown hotspot {hid}")
        check_line(d, rep, b.get("line"), "slice.boundary_exits")
    end = d["slice"]["end"]
    check_line(d, rep, end.get("line_on_enter"), "slice.end")
    check_line(d, rep, end["confirm_if_unsolved"].get("line"), "slice.end")
    for sp in d["slice"].get("debug", {}).get("start_points", []):
        check_string(d, rep, sp.get("label_key"), "slice.debug.start_points")
        if sp["vp"] not in d["viewpoints"]:
            rep.err(f"slice.debug.start_points: unknown vp {sp['vp']}")
        for pz in sp.get("solved", []):
            if pz not in d["nodes"]:
                rep.err(f"slice.debug.start_points: unknown puzzle {pz}")
    for iid, it in d["items"].items():
        check_string(d, rep, it.get("name_key"), f"item {iid}")
        check_string(d, rep, it.get("desc_key"), f"item {iid}")
    for coll, key in (("clues", "text"), ("questions", "text"), ("goals", "text"),
                      ("documents", "title"), ("snapshots", "title"), ("codes", "title"), ("people", "name_key")):
        for ident, ent in d[coll].items():
            check_string(d, rep, ent.get(key), f"{coll} {ident}")
    for ident, doc in d["documents"].items():
        if "text_by_level" in doc:
            for lvl in LEVELS:
                check_string(d, rep, f"{doc['text_by_level']}.{lvl}", f"document {ident}")
        check_line(d, rep, doc.get("line"), f"document {ident}")
    for gid, g in d["goals"].items():
        check_condition_flag(d, rep, g["opens_on"], f"goal {gid}")
        check_condition_flag(d, rep, g["closes_on"], f"goal {gid}")
    for pid, p in d["people"].items():
        for ln in p.get("facts", []):
            check_line(d, rep, ln, f"people {pid}")
    for eid, ev in d["events"].items():
        w = f"event {eid}"
        for fr in ev.get("frames", []) or []:
            for ln in fr.get("lines", []):
                check_line(d, rep, ln, w)
            for g in fr.get("give", []) or []:
                if g not in d["items"]:
                    rep.err(f"{w}: unknown item {g}")
        for ln in ev.get("lines", []) or []:
            check_line(d, rep, ln, w)
        for st in ev.get("steps", []) or []:
            check_string(d, rep, st, w)
        for g in ev.get("give_at_start", []) or []:
            if g not in d["items"]:
                rep.err(f"{w}: unknown item {g}")
        if ev.get("next") and ev["next"] not in d["events"]:
            rep.err(f"{w}: unknown next event {ev['next']}")
    for nid, n in d["nodes"].items():
        w = f"node {nid}"
        check_line(d, rep, n.get("logic_line"), w)
        check_line(d, rep, n.get("on_solved_line"), w)
        nav = n.get("nav", {})
        for k in ("area", "precise"):
            for ln in nav.get(k, []):
                check_line(d, rep, ln, w)
        for k in ("ready", "missing"):
            check_line(d, rep, nav.get(k), w)
        fb = n.get("feedback", {})
        for lvl in ("easy", "normal"):
            for ln in fb.get(lvl, []) or []:
                check_line(d, rep, ln, w)
        for rule in n.get("feedback_rules", []) or []:
            for lvl in ("easy", "normal"):
                check_line(d, rep, rule.get(lvl), w)
        for u in n.get("unlocks", []):
            if not known_entity(d, u):
                rep.err(f"{w}: unlocks unknown {u}")
        if n.get("hotspot") and n["hotspot"] not in d["hotspots"]:
            rep.err(f"{w}: unknown hotspot {n['hotspot']}")
        if n.get("kind") == "puzzle" and n.get("location") not in d["locations"]:
            rep.err(f"{w}: unknown location {n.get('location')}")
        if n.get("screen") not in (None, "code_lock", "clock_lock", "search", "tracks", "compare"):
            rep.err(f"{w}: unknown screen {n.get('screen')}")
        if n.get("on_solved_snap") and n["on_solved_snap"] not in d["snapshots"]:
            rep.err(f"{w}: unknown snapshot {n['on_solved_snap']}")
    for sid, sp in d["speakers"].items():
        check_string(d, rep, sp.get("name_key"), f"speaker {sid}")
    for lid, ln in d["lines"].items():
        if ln.get("speaker_id") not in d["speakers"]:
            rep.err(f"line {lid}: unknown speaker {ln.get('speaker_id')}")
        for f in ("text_ru", "text_en", "audio_ru", "audio_en"):
            if f not in ln:
                rep.err(f"line {lid}: missing field {f} (решение №11: у каждой реплики ID, RU/EN, аудио)")
        if ln.get("text_ru") is None:
            rep.warn(f"line {lid}: text_ru is empty (status {ln.get('status')}) — будет [TEXT NEEDED]")
        elif ln.get("text_en") is None:
            pass  # counted in summary
    for sign in d["signs"]:
        check_string(d, rep, f"sign.{sign}", "signs")


# ---------------------------------------------------------------- values

def check_gate01_values(d: dict, rep: Report) -> None:
    """Constraints from test-set-01 PZ-GATE-01 'Ограничения для подбора'."""
    for profile, vals in d["values"].items():
        pz = (vals or {}).get("PZ-GATE-01")
        if not pz:
            if profile == "test":
                rep.err("values/test.yaml: PZ-GATE-01 missing")
            continue
        fountain = pz.get("fountain_order", [])
        for lvl in LEVELS:
            v = pz.get(lvl)
            w = f"values/{profile}.yaml PZ-GATE-01.{lvl}"
            if not v:
                rep.err(f"{w}: missing")
                continue
            levels = v["levels"]
            pillars = v["pillars"]
            code = str(v["code"])
            if sorted(levels.values()) != sorted(set(levels.values())):
                rep.err(f"{w}: water levels must all differ")
            if any(not 1 <= lv <= 9 for lv in levels.values()):
                rep.err(f"{w}: water levels must be 1..9")
            for s in pillars:
                if s not in levels:
                    rep.err(f"{w}: pillar sign '{s}' has no bowl")
            expected = "".join(str(levels[s]) for s in pillars if s in levels)
            if expected != code:
                rep.err(f"{w}: code {code} != levels in pillar order {expected}")
            numbers = "".join(str(d["signs"][s]["number"]) for s in pillars)
            if numbers == code:
                rep.err(f"{w}: code equals sign numbers in pillar order")
            fountain_code = "".join(str(levels[s]) for s in fountain if s in levels)[: len(code)]
            if fountain_code == code:
                rep.err(f"{w}: code equals fountain clockwise order")
            for s, lv in levels.items():
                if d["signs"][s]["number"] == lv:
                    rep.err(f"{w}: level of {s} equals its sign number")
            for s in pillars:
                if s not in d["signs"]:
                    rep.err(f"{w}: unknown sign {s}")


def _merged(per: dict, lvl: str) -> dict:
    """values(id, level) as in GameData.values: 'all' + non-level keys + the level block."""
    out: dict = {}
    out.update(per.get("all") or {})
    for k, val in per.items():
        if k not in LEVELS and k != "all":
            out[k] = val
    out.update(per.get(lvl) or {})
    return out


def _hm(s: str) -> int:
    h, m = str(s).split(":")
    return int(h) * 60 + int(m)


def check_puzzle_values(d: dict, rep: Report) -> None:
    """GATE-03, PIER-01, ALLEY-01, GATE-02: answers derivable from the values, texts and zones present."""
    vals = d["values"]["test"] or {}
    feedback_rules = {nid: {r.get("when") for r in (n.get("feedback_rules") or [])} for nid, n in d["nodes"].items()}
    # --- GATE-03: departure + journey = target on every level; logic words; canon text on normal
    per = vals.get("PZ-GATE-03") or {}
    for lvl in LEVELS:
        v = _merged(per, lvl)
        w = f"values/test.yaml PZ-GATE-03.{lvl}"
        dur = sum(v["legs_min"]) if "legs_min" in v else int(v.get("duration_min", 0))
        if (_hm(v["departure"]) + dur) % 720 != _hm(v["target_time"]) % 720:
            rep.err(f"{w}: departure + journey != target_time")
        if 60 % int(v.get("snap_minutes", 1)) or _hm(v["target_time"]) % int(v.get("snap_minutes", 1)):
            rep.err(f"{w}: target_time not reachable with snap_minutes")
        for lang in ("ru", "en"):
            words = (v.get("logic_words") or {}).get(lang) or {}
            if set(words) != {"departure", "duration", "arrival"}:
                rep.err(f"{w}: logic_words.{lang} needs departure, duration, arrival")
    ln = d["lines"].get("LOGIC-GATE-03", {})
    nv = _merged(per, "normal")
    for lang in ("ru", "en"):
        tpl = ln.get(f"template_{lang}")
        if tpl:
            filled = tpl
            for k, val in ((nv.get("logic_words") or {}).get(lang) or {}).items():
                filled = filled.replace("{%s}" % k, val)
            if filled != ln.get(f"text_{lang}"):
                rep.err(f"LOGIC-GATE-03: template_{lang} with normal values differs from the canon text")
    # --- PIER-01: every target has a zone; zones >= 48 dp; reaction rules known
    per = vals.get("PZ-PIER-01") or {}
    lay = (d.get("layouts") or {}).get("PZ-PIER-01") or {}
    strip = float((lay.get("scene") or {}).get("strip_px", 170))
    rules = feedback_rules.get("PZ-PIER-01", set())
    for o in lay.get("objects", []):
        for r in [o.get("rule")] + list((o.get("rule_if_selected") or {}).values()) + list((o.get("rule_if_found") or {}).values()):
            if r and r not in rules:
                rep.err(f"layouts PZ-PIER-01 {o['id']}: rule {r} not in progression feedback_rules")
        if o.get("target"):
            x, y, ww, hh = o["rect"]
            if ww * 1600 < 95 or hh * (720 - strip) < 95:
                rep.err(f"layouts PZ-PIER-01 {o['id']}: touch zone < 48 dp ({ww * 1600:.0f}×{hh * (720 - strip):.0f})")
    for lvl in LEVELS:
        v = _merged(per, lvl)
        for t in v.get("targets", []):
            if not any(o.get("target") == t and lvl in o.get("levels", LEVELS) for o in lay.get("objects", [])):
                rep.err(f"values PZ-PIER-01.{lvl}: target {t} has no zone in layouts.yaml")
        for t in v.get("described", []):
            if t not in v.get("targets", []):
                rep.err(f"values PZ-PIER-01.{lvl}: described {t} is not a target")
            check_string(d, rep, f"pz.pier01.desc.{t}", f"PZ-PIER-01.{lvl}")
    # --- ALLEY-01: two fresh human chains in different directions; answer matches chain dirs
    per = vals.get("PZ-ALLEY-01") or {}
    for lvl in LEVELS:
        v = _merged(per, lvl)
        w = f"values/test.yaml PZ-ALLEY-01.{lvl}"
        chains = {c["id"]: c for c in v.get("chains", [])}
        ans = v.get("answer") or {}
        if set(ans.get("fresh", [])) != set(chains):
            rep.err(f"{w}: answer.fresh must be exactly the chains")
        if len({c.get("dir") for c in chains.values()}) != 2:
            rep.err(f"{w}: the two chains must go in different directions")
        for cid, c in chains.items():
            if (ans.get("dir") or {}).get(cid) != c.get("dir"):
                rep.err(f"{w}: answer.dir.{cid} != chain dir")
    # --- GATE-02: answer ids exist; fragment texts are verbatim lines of the level's documents
    per = vals.get("PZ-GATE-02") or {}
    for lvl in LEVELS:
        v = _merged(per, lvl)
        w = f"values/test.yaml PZ-GATE-02.{lvl}"
        segs = {s["id"] for s in (v.get("tape") or {}).get("segments", [])}
        ans = v.get("answer") or {}
        for r in ans.get("rain", []):
            if r not in segs:
                rep.err(f"{w}: answer.rain {r} is not a tape segment")
        for it in ans.get("items_any", []):
            if it not in v.get("notes", []):
                rep.err(f"{w}: answer.items_any {it} is not in notes")
        concls = [str(c)[0] for c in v.get("conclusions", [])]
        if str(ans.get("conclusion", ""))[:1] not in concls:
            rep.err(f"{w}: answer.conclusion not among conclusions")
        for c in concls:
            check_string(d, rep, f"pz.gate02.concl.{c}", w)
        for doc_key, ids in (("doc.pier_notes", v.get("notes", [])),
                             ("doc.weather_log", v.get("journal", []) if v.get("journal_in_pool", True) else [])):
            doc = d["strings"].get(f"{doc_key}.{lvl}") or {}
            for fid in ids:
                fs = d["strings"].get(f"frag.{fid}")
                if not fs:
                    rep.err(f"{w}: no UI string frag.{fid}")
                    continue
                for lang in ("ru", "en"):
                    if fs.get(lang) not in (doc.get(lang) or ""):
                        rep.err(f"{w}: frag.{fid}.{lang} is not a verbatim part of {doc_key}.{lvl}")


def collect_codes(values: dict) -> dict:
    """{level: [(puzzle, code)]} for every value named 'code' or 'target_time'."""
    out: dict = {lvl: [] for lvl in LEVELS}
    for pz, per in (values or {}).items():
        if not isinstance(per, dict):
            continue
        for lvl in LEVELS:
            v = per.get(lvl)
            if isinstance(v, dict):
                for key in ("code", "target_time"):
                    if key in v:
                        out[lvl].append((pz, str(v[key]).replace(":", "")))
    return out


def check_codes_unique(d: dict, rep: Report) -> None:
    for profile, vals in d["values"].items():
        for lvl, codes in collect_codes(vals).items():
            seen: dict = {}
            for pz, code in codes:
                if code in seen:
                    rep.err(f"values/{profile}.yaml: code {code} repeats in {seen[code]} and {pz} ({lvl})")
                seen[code] = pz


# ---------------------------------------------------------------- graph

def requirements_met(node: dict, solved: set, items: set, gates: set) -> bool:
    req = node.get("requires") or {}
    for dep in req.get("all_of", []) or []:
        if dep.startswith("GT-"):
            if dep not in gates:
                return False
        elif dep not in solved:
            return False
    for it in req.get("items", []) or []:
        if it not in items:
            return False
    return True


def apply_solve(d: dict, node_id: str, solved: frozenset, items: frozenset, gates: frozenset):
    node = d["nodes"][node_id]
    s, i, g = set(solved), set(items), set(gates)
    s.add(node_id)
    for u in node.get("unlocks", []) or []:
        if u.startswith("GT-"):
            g.add(u)
        elif u in d["items"]:
            i.add(u)
    for iid, it in d["items"].items():
        if node_id in (it.get("consumed_by") or []):
            i.discard(iid)
    return frozenset(s), frozenset(i), frozenset(g)


def check_graph(d: dict, rep: Report) -> dict:
    """Explore every order of solving. Report dead ends and front sizes (каркас 7.6)."""
    start_items = set(d["events"]["EV-INTRO"].get("give_at_start", []))
    for fr in d["events"]["EV-INTRO"].get("frames", []):
        start_items.update(fr.get("give", []) or [])
    puzzles = [n for n, v in d["nodes"].items() if v.get("kind") == "puzzle"]
    start = (frozenset(), frozenset(start_items), frozenset())
    seen = {start}
    stack = [start]
    max_front = 0
    dead = []
    end_node = d["nodes"].get("SLICE-END")
    while stack:
        st = stack.pop()
        solved, items, gates = st
        front = [p for p in puzzles if p not in solved and requirements_met(d["nodes"][p], solved, items, gates)]
        end_ready = end_node is not None and requirements_met(end_node, solved, items, gates)
        max_front = max(max_front, len(front) + (1 if end_ready else 0))
        if not front and len(solved) < len(puzzles):
            dead.append(sorted(solved))
        for p in front:
            nxt = apply_solve(d, p, solved, items, gates)
            if nxt not in seen:
                seen.add(nxt)
                stack.append(nxt)
    if dead:
        rep.err(f"graph: dead ends (unsolvable puzzles remain) after solving {dead[:3]}")
    finals = [s for s in seen if len(s[0]) == len(puzzles)]
    if not finals:
        rep.err("graph: not all puzzles can be solved")
    if end_node is not None and not any(requirements_met(end_node, *s) for s in seen):
        rep.err("graph: slice end is unreachable")
    fronts = d["progression"].get("checks", {}).get("fronts", {})
    if fronts.get("max") and max_front > fronts["max"]:
        rep.warn(f"graph: front of {max_front} tasks exceeds max {fronts['max']}")
    return {"states": len(seen), "max_front": max_front}


# ---------------------------------------------------------------- main

def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--check", action="store_true", help="validate only")
    ap.add_argument("--quiet", action="store_true")
    args = ap.parse_args()

    rep = Report()
    try:
        d = load_all(rep)
    except (OSError, yaml.YAMLError, KeyError) as exc:
        print(f"ERROR: cannot load data: {exc}", file=sys.stderr)
        return 1
    check_references(d, rep)
    check_gate01_values(d, rep)
    check_puzzle_values(d, rep)
    check_codes_unique(d, rep)
    graph = check_graph(d, rep)

    lines = d["lines"].values()
    no_en = sum(1 for ln in lines if ln.get("text_en") is None)
    no_ru = sum(1 for ln in lines if ln.get("text_ru") is None)
    if not args.quiet:
        print(f"data: {len(d['lines'])} lines ({no_ru} without RU, {no_en} without EN), "
              f"{len(d['strings'])} UI strings, {len(d['viewpoints'])} viewpoints, "
              f"{len(d['hotspots'])} hotspots, {len(d['nodes'])} progression nodes; "
              f"graph: {graph['states']} states, max front {graph['max_front']}")
        for w in rep.warnings:
            print(f"warning: {w}")
    for e in rep.errors:
        print(f"ERROR: {e}", file=sys.stderr)
    if rep.errors:
        print(f"{len(rep.errors)} error(s); JSON not written", file=sys.stderr)
        return 1
    if not args.check:
        del d["nodes"]  # GDScript builds its own index from progression.nodes
        OUT_FILE.parent.mkdir(parents=True, exist_ok=True)
        OUT_FILE.write_text(json.dumps(d, ensure_ascii=False, indent=1), encoding="utf-8")
        if not args.quiet:
            print(f"wrote {OUT_FILE.relative_to(GAME_DIR.parent)}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
