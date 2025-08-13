#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import os, re, json, math, argparse, csv
from collections import defaultdict, Counter
from typing import List, Dict, Tuple, Optional, Set

# --------- Profile -> needs ---------
PROFILE_NEEDS: Dict[str, List[str]] = {
    "P0": [],
    "P1": ["motor"],
    "P2": ["visual"],
    "P3": ["handsfree"],
    "P4": ["motor","handsfree"],
    "P5": ["visual","motor"],
}

# --------- Acceptable corrective sets per event ---------
ACCEPTABLE = {
    "miss_tap": {"increase_button_size", "increase_button_border", "adjust_spacing", "switch_mode:voice"},
    "slider_miss": {"increase_slider_size", "adjust_spacing"},
    "voice": {"switch_mode:voice", "trigger_button"},
    "gesture": {"switch_mode:gesture", "trigger_button"},
}

# Categories for PAA
MOTOR_ACTIONS = {"increase_button_size","increase_button_border","increase_slider_size","adjust_spacing"}
VISUAL_ACTIONS = {"increase_font_size","increase_contrast"}

# --------- Robust JSON key paths ---------
KEYS = {
    "profile": [
        ["profile_id"], ["profile"], ["user_profile"], ["user","profile"], ["p"]
    ],
    "event_type": [
        ["event","event_type"], ["event","type"], ["event_type"], ["type"], ["evt_type"]
    ],
    "actions": [
        ["response","adaptations"], ["response","actions"], ["adaptations"], ["actions"]
    ],
}

def get_nested(d: dict, paths: List[List[str]]):
    for p in paths:
        cur = d
        ok = True
        for k in p:
            if not isinstance(cur, dict) or k not in cur:
                ok = False
                break
            cur = cur[k]
        if ok:
            return cur
    return None

def norm_profile(pid: Optional[str], filename: str) -> str:
    if isinstance(pid, str) and pid.strip():
        m = re.fullmatch(r"[pP](\d+)", pid.strip())
        if m: return f"P{m.group(1)}"
        return pid
    m = re.search(r"profile\s*([0-9]+)", filename, flags=re.I)
    if m: return f"P{m.group(1)}"
    return "P?"

def norm_event_type(t: Optional[str]) -> str:
    if not t: return "UNK"
    s = str(t).lower().replace("-", "_").replace(" ", "_").strip()
    if "miss" in s and "tap" in s: return "miss_tap"
    if "slider" in s and ("miss" in s or "overshoot" in s): return "slider_miss"
    if "voice" in s or "speech" in s or "asr" in s: return "voice"
    if "gesture" in s or "point" in s: return "gesture"
    return s

def extract_actions(data: dict):
    raw = get_nested(data, KEYS["actions"])
    if raw is None: return []
    out = []
    if isinstance(raw, list):
        for item in raw:
            if isinstance(item, str):
                out.append({"name": item, "params": {}, "target": None})
            elif isinstance(item, dict):
                name = item.get("name") or item.get("action")
                params = item.get("params") or {}
                target = item.get("target") or item.get("target_id")
                if "mode" in item and "mode" not in params:
                    params["mode"] = item["mode"]
                out.append({"name": name, "params": params, "target": target})
    return out

# --------- Rule baselines ---------
def rule_actions(event_type: str, variant: str = "minimal"):
    ev = event_type
    if variant == "maximal":
        if ev in ACCEPTABLE:
            names = set()
            for a in ACCEPTABLE[ev]:
                if a.startswith("switch_mode:"):
                    names.add("switch_mode")
                else:
                    names.add(a)
            return names
        return set()
    return {
        "miss_tap": {"increase_button_size"},
        "slider_miss": {"increase_slider_size"},
        "voice": {"switch_mode"},
        "gesture": {"switch_mode"},
    }.get(ev, set())

# --------- Metrics ---------
def jaccard(a, b):
    if not a and not b:
        return 1.0
    u = a | b
    i = a & b
    return 0.0 if not u else len(i)/len(u)

def action_to_category(name: str, params: dict, event_type: str):
    n = (name or "").lower()
    if n in MOTOR_ACTIONS: return "motor"
    if n in VISUAL_ACTIONS: return "visual"
    if n == "switch_mode":
        mode = (params.get("mode") or params.get("to") or params.get("modality") or "").lower()
        if mode in {"voice","gesture"}: return "handsfree"
        if event_type in {"voice","gesture"}: return "handsfree"
    if n == "trigger_button" and event_type == "voice":
        return "handsfree"
    return None

def compute(logdir: str, variant: str = "minimal", paa_topk: int = 5):
    files = []
    for root,_,fnames in os.walk(logdir):
        for f in fnames:
            if f.lower().endswith(".jsonl"):
                files.append(os.path.join(root,f))
    if not files:
        raise SystemExit(f"No .jsonl files found under: {logdir}")

    freq = defaultdict(Counter)
    for path in files:
        with open(path, "r", encoding="utf-8") as fh:
            for line in fh:
                line=line.strip()
                if not line: continue
                try:
                    data = json.loads(line)
                except Exception:
                    continue
                prof = norm_profile(get_nested(data, KEYS["profile"]), os.path.basename(path))
                for a in extract_actions(data):
                    n = (a.get("name") or a.get("action") or "").lower()
                    if n: freq[prof][n] += 1
    topk = {}
    for p,c in freq.items():
        if paa_topk and paa_topk>0:
            topk[p] = {name for name,_ in c.most_common(paa_topk)}
        else:
            topk[p] = set(c.keys())

    per_prof = defaultdict(lambda: {"jacc": [], "exact": 0, "n": 0,
                                    "paa_hits": 0, "paa_tot": 0})
    overall = {"jacc": [], "exact": 0, "n": 0}

    for path in files:
        with open(path, "r", encoding="utf-8") as fh:
            for line in fh:
                line=line.strip()
                if not line: continue
                try:
                    data = json.loads(line)
                except Exception:
                    continue
                prof = norm_profile(get_nested(data, KEYS["profile"]), os.path.basename(path))
                evtype = norm_event_type(get_nested(data, KEYS["event_type"]))
                acts = extract_actions(data)
                llm_set = { (a.get("name") or a.get("action") or "").lower() for a in acts if (a.get("name") or a.get("action")) }
                rule_set = set(rule_actions(evtype, variant=variant))

                j = jaccard(llm_set, rule_set)
                ex = 1 if llm_set == rule_set else 0

                per_prof[prof]["jacc"].append(j)
                per_prof[prof]["exact"] += ex
                per_prof[prof]["n"] += 1
                overall["jacc"].append(j)
                overall["exact"] += ex
                overall["n"] += 1

                needs = set(PROFILE_NEEDS.get(prof, []))
                allowed = topk.get(prof, set())
                for name in rule_set:
                    params = {}
                    cat = action_to_category(name, params, evtype)
                    if cat not in {"motor","visual","handsfree"}:
                        continue
                    if paa_topk and name not in allowed:
                        continue
                    per_prof[prof]["paa_tot"] += 1
                    if needs and cat in needs:
                        per_prof[prof]["paa_hits"] += 1

    prof_rows = []
    for p in sorted(per_prof.keys()):
        d = per_prof[p]
        n = max(1, d["n"])
        mean_j = sum(d["jacc"])/n
        exact_rate = d["exact"]/n
        paa = (100.0 * d["paa_hits"]/d["paa_tot"]) if d["paa_tot"] else float("nan")
        prof_rows.append((p, mean_j, exact_rate, paa, d["paa_hits"], d["paa_tot"], n))

    overall_row = {
        "mean_jacc": sum(overall["jacc"])/max(1, overall["n"]),
        "exact_rate": overall["exact"]/max(1, overall["n"]),
        "events": overall["n"]
    }
    return prof_rows, overall_row

def write_outputs(rows, overall_row, csv_path, variant: str):
    with open(csv_path, "w", newline="", encoding="utf-8") as fh:
        w = csv.writer(fh)
        w.writerow(["profile","mean_jaccard","exact_match_rate","rule_paa_pct","rule_paa_hits","rule_paa_total","events"])
        for p, mj, ex, paa, hit, tot, n in rows:
            w.writerow([p, f"{mj:.3f}", f"{ex:.3f}", ("" if math.isnan(paa) else f"{paa:.2f}"), hit, tot, n])
        w.writerow(["ALL", f"{overall_row['mean_jacc']:.3f}", f"{overall_row['exact_rate']:.3f}", "", "", "", overall_row["events"]])



def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("logdir", help="Directory with .jsonl logs (scanned recursively)")
    ap.add_argument("--variant", choices=["minimal","maximal"], default="minimal",
                    help="Rule baseline variant: minimal (one canonical fix) or maximal (all acceptable fixes)")
    ap.add_argument("--paa-topk", type=int, default=5, help="Top-K action mask for PAA style (default 5, 0 = all)")
    ap.add_argument("--csv", default="rule_vs_llm.csv", help="Output CSV")
    args = ap.parse_args()

    rows, overall = compute(args.logdir, variant=args.variant, paa_topk=args.paa_topk)
    write_outputs(rows, overall, args.csv, args.variant)

    print(f"Overall mean Jaccard: {overall['mean_jacc']:.3f}, exact-match rate: {overall['exact_rate']:.3f} over {overall['events']} events.")
    print(f"Wrote {args.csv}.")

if __name__ == "__main__":
    main()
