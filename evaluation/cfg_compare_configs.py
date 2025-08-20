#!/usr/bin/env python3
# -*- coding: utf-8 -*-
import os, json, csv, argparse, math
from statistics import mean, median
from typing import Dict, List, Tuple, Optional, Any
from collections import defaultdict, Counter

# --- Category mapping for PAA (used only if per-user paa_pct absent in payload) ---
MOTOR = {"increase_button_size","increase_button_border","increase_slider_size","adjust_spacing"}
VISUAL = {"increase_font_size","increase_contrast"}
HANDSFREE = {"switch_mode","trigger_button"}  # treat as hands-free when mode detail not present

PROFILE_NEEDS: Dict[str, List[str]] = {
    "P0": [],
    "P1": ["motor"],
    "P2": ["visual"],
    "P3": ["handsfree"],
    "P4": ["motor","handsfree"],
    "P5": ["visual","motor"],
}

# --- Acceptable corrective actions for ERA ---
ACCEPTABLE = {
    "miss_tap": {"increase_button_size", "increase_button_border", "adjust_spacing", "switch_mode:voice"},
    "slider_miss": {"increase_slider_size", "adjust_spacing"},
    "voice": {"switch_mode:voice", "trigger_button"},
    "gesture": {"switch_mode:gesture", "trigger_button"},
}

# --- Robust extraction helpers for JSONL ---
KEYS = {
    "profile": [["profile_id"],["profile"],["user_profile"],["user","profile"],["p"]],
    "event_type": [["event","event_type"],["event","type"],["event_type"],["type"],["evt_type"]],
    "actions": [["response","adaptations"],["response","actions"],["adaptations"],["actions"]],
}

def get_nested(d: dict, paths: List[List[str]]):
    for p in paths:
        cur = d; ok = True
        for k in p:
            if not isinstance(cur, dict) or k not in cur:
                ok = False; break
            cur = cur[k]
        if ok: return cur
    return None

def norm_profile(pid: Optional[str], fname: str) -> str:
    if isinstance(pid, str) and pid.strip():
        s = pid.strip()
        if s.upper().startswith("P") and s[1:].isdigit():
            return "P"+s[1:]
        if s.isdigit():
            return "P"+s
        return s
    # fallback: try to parse from filename like 'profile2.jsonl'
    import re
    m = re.search(r"profile\s*([0-9]+)", fname, flags=re.I)
    return f"P{m.group(1)}" if m else "P?"

def norm_event_type(t: Optional[str]) -> str:
    if not t: return "UNK"
    s = str(t).lower().replace("-","_").replace(" ","_").strip()
    if "miss" in s and "tap" in s: return "miss_tap"
    if "slider" in s and ("miss" in s or "overshoot" in s): return "slider_miss"
    if "voice" in s or "speech" in s or "asr" in s: return "voice"
    if "gesture" in s or "point" in s: return "gesture"
    return s

def extract_actions(data: dict) -> List[dict]:
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

def acceptable_hit(event_type: str, acts: List[dict]) -> bool:
    acc = ACCEPTABLE.get(event_type, set())
    for a in acts:
        name = (a.get("name") or a.get("action") or "").lower()
        if name == "switch_mode":
            mode = (a.get("params") or {}).get("mode") or ""
            mode = str(mode).lower()
            key = f"switch_mode:{mode}" if mode in {"voice","gesture"} else None
            if key and key in acc: return True
            # if mode not present, infer from event_type if mapping exists
            if f"switch_mode:{event_type}" in acc: return True
        else:
            if name in acc: return True
    return False

def dci_for_event(acts: List[dict]) -> float:
    """DCI proxy: 1 - duplicates/suggestions (conflicts rare in your action set)."""
    if not acts: return 0.0
    seen = set(); dups = 0
    for a in acts:
        key = ((a.get("name") or a.get("action") or "").lower(), str(a.get("target")))
        if key in seen: dups += 1
        else: seen.add(key)
    return 1.0 - (dups/len(acts))

def action_category(name: str) -> Optional[str]:
    n = name.lower()
    if n in MOTOR: return "motor"
    if n in VISUAL: return "visual"
    if n in HANDSFREE: return "handsfree"
    return None

def compute_paa_from_top_actions(top_actions: Dict[str,int], profile_id: str) -> Tuple[int,int,float]:
    needs = set(PROFILE_NEEDS.get(profile_id, []))
    if not isinstance(top_actions, dict):
        return 0, 0, float("nan")
    total = 0; hits = 0
    for act, cnt in top_actions.items():
        cat = action_category(str(act))
        if cat in {"motor","visual","handsfree"}:
            c = int(cnt)
            total += c
            if needs and cat in needs:
                hits += c
    return hits, total, (100.0*hits/total) if total>0 else float("nan")

# --- Payload readers ---
def load_payload(path: str) -> dict:
    with open(path, "r", encoding="utf-8") as fh:
        payload = json.load(fh)
    # Attach absolute paths for JSONL files based on payload location
    base = os.path.dirname(os.path.abspath(path))
    payload["_abs_files"] = [os.path.abspath(os.path.join(base, f)) for f in payload.get("files", [])]
    return payload

def overall_from_payload(payload: dict) -> dict:
    ov = payload.get("overall", {})
    res = {
        "p50": (ov.get("latency_ms", {}).get("p50") or float("nan"))/1000.0 if ov.get("latency_ms") else float("nan"),
        "schema_pct": float(ov.get("schema_valid_pct")) if ov.get("schema_valid_pct") is not None else float("nan"),
        "PAA": float(ov.get("paa_pct")) if ov.get("paa_pct") is not None else None,  # may be absent
        "ERA": float(ov.get("era_pct")) if ov.get("era_pct") is not None else None,
        "DCI": float(ov.get("dci_mean")) if ov.get("dci_mean") is not None else None,
        "n": int(ov.get("events_total")) if ov.get("events_total") is not None else None,
    }
    return res

def per_profile_from_payload(payload: dict) -> Dict[str, dict]:
    rows = {}
    for u in payload.get("per_user", []):
        pid = u.get("user_id") or (u.get("profile_ids") or ["P?"])[0]
        p50 = u.get("latency_ms",{}).get("p50")
        p50 = (p50/1000.0) if isinstance(p50,(int,float)) else float("nan")
        schema = float(u.get("schema_valid_pct")) if u.get("schema_valid_pct") is not None else float("nan")
        paa = u.get("paa_pct")
        if paa is None:
            _,_,paa = compute_paa_from_top_actions(u.get("top_actions", {}), pid)
        rows[pid] = {
            "p50": p50,
            "schema_pct": schema,
            "PAA": float(paa) if paa is not None else float("nan"),
            "ERA": None, "DCI": None,  # will fill from JSONL
            "n": int(u.get("events_total")) if u.get("events_total") is not None else None
        }
    return rows

# --- Compute ERA & DCI from JSONL listed in payload ---
def era_dci_from_jsonl(files: List[str]) -> Tuple[Dict[str, dict], dict]:
    per = defaultdict(lambda: {"era_hits":0, "n":0, "dci_sum":0.0, "dci_n":0})
    overall = {"era_hits":0, "n":0, "dci_sum":0.0, "dci_n":0}
    for path in files:
        try:
            with open(path, "r", encoding="utf-8") as fh:
                for line in fh:
                    line = line.strip()
                    if not line: continue
                    try:
                        data = json.loads(line)
                    except Exception:
                        continue
                    p = norm_profile(get_nested(data, KEYS["profile"]), os.path.basename(path))
                    evtype = norm_event_type(get_nested(data, KEYS["event_type"]))
                    acts = extract_actions(data)
                    # ERA
                    hit = acceptable_hit(evtype, acts)
                    per[p]["era_hits"] += (1 if hit else 0)
                    per[p]["n"] += 1
                    overall["era_hits"] += (1 if hit else 0)
                    overall["n"] += 1
                    # DCI
                    dci = dci_for_event(acts)
                    per[p]["dci_sum"] += dci; per[p]["dci_n"] += 1
                    overall["dci_sum"] += dci; overall["dci_n"] += 1
        except FileNotFoundError:
            continue
    # Finalize percentages/means
    per_out = {}
    for pid, v in per.items():
        era_pct = (100.0*v["era_hits"]/v["n"]) if v["n"] else float("nan")
        dci_mean = (v["dci_sum"]/v["dci_n"]) if v["dci_n"] else float("nan")
        per_out[pid] = {"ERA": era_pct, "DCI": dci_mean, "n": v["n"]}
    ov_out = {
        "ERA": (100.0*overall["era_hits"]/overall["n"]) if overall["n"] else float("nan"),
        "DCI": (overall["dci_sum"]/overall["dci_n"]) if overall["dci_n"] else float("nan"),
        "n": overall["n"]
    }
    return per_out, ov_out

# --- Formatting helpers ---
def fmt(x: Optional[float]) -> str:
    if x is None or (isinstance(x,float) and math.isnan(x)): return "--"
    return f"{x:.2f}"

def fnum(x: Optional[float]) -> str:
    if x is None or (isinstance(x,float) and math.isnan(x)): return ""
    return f"{x:.2f}"

# --- Main procedure ---
def main():
    ap = argparse.ArgumentParser(description="Compare two configs: PAA & Schema from payloads; ERA & DCI from JSONL files.")
    ap.add_argument("--payload-a", required=True, help="chapter6_payload.json for config A")
    ap.add_argument("--payload-b", required=True, help="chapter6_payload.json for config B")
    ap.add_argument("--name-a", default="Config A", help="Display name for config A")
    ap.add_argument("--name-b", default="Config B", help="Display name for config B")
    ap.add_argument("--prefix", default="cfg_merge_payload_logs", help="Output file prefix")
    args = ap.parse_args()

    pa = load_payload(args.payload_a)
    pb = load_payload(args.payload_b)

    # From payload: p50, schema, PAA (overall and per-profile)
    ova = overall_from_payload(pa)
    ovb = overall_from_payload(pb)
    rowsa = per_profile_from_payload(pa)
    rowsb = per_profile_from_payload(pb)

    # From JSONL: ERA and DCI (overall and per-profile)
    per_a, ov_era_dci_a = era_dci_from_jsonl(pa["_abs_files"])
    per_b, ov_era_dci_b = era_dci_from_jsonl(pb["_abs_files"])

    # Merge per-profile ERA/DCI into rows
    for pid, v in rowsa.items():
        if pid in per_a:
            v["ERA"] = per_a[pid]["ERA"]
            v["DCI"] = per_a[pid]["DCI"]
    for pid, v in rowsb.items():
        if pid in per_b:
            v["ERA"] = per_b[pid]["ERA"]
            v["DCI"] = per_b[pid]["DCI"]

    # Merge overall ERA/DCI into overall (payload fields take precedence for p50/schema/PAA only)
    ova["ERA"] = ov_era_dci_a["ERA"]
    ova["DCI"] = ov_era_dci_a["DCI"]
    ovb["ERA"] = ov_era_dci_b["ERA"]
    ovb["DCI"] = ov_era_dci_b["DCI"]

    # CSV overall
    with open(f"{args.prefix}_overall.csv","w",newline="",encoding="utf-8") as fh:
        w = csv.writer(fh)
        w.writerow(["config","p50_s","schema_valid_pct","paa_pct","era_pct","dci_mean","events"])
        w.writerow([args.name_a, fmt(ova["p50"]), fmt(ova["schema_pct"]), fmt(ova["PAA"]), fmt(ova["ERA"]), fmt(ova["DCI"]), ova["n"] or ""])
        w.writerow([args.name_b, fmt(ovb["p50"]), fmt(ovb["schema_pct"]), fmt(ovb["PAA"]), fmt(ovb["ERA"]), fmt(ovb["DCI"]), ovb["n"] or ""])

    # LaTeX overall
    lines = []
    lines += [r"\begin{table}[ht]", r"\centering",
              r"\caption{Config comparison (p50 from payload; Schema \& PAA from payload; ERA \& DCI from logs).}",
              r"\label{tab:cfg-merge-overall}",
              r"\begin{tabular}{lrrrrr}",
              r"\toprule",
              r"\textbf{Config} & \textbf{p50 (s)} & \textbf{Schema-valid (\%)} & \textbf{PAA (\%)} & \textbf{ERA (\%)} & \textbf{DCI} \\",
              r"\midrule",
              f"{args.name_a} & {fmt(ova['p50'])} & {fmt(ova['schema_pct'])} & {fmt(ova['PAA'])} & {fmt(ova['ERA'])} & {fmt(ova['DCI'])} \\\\",
              f"{args.name_b} & {fmt(ovb['p50'])} & {fmt(ovb['schema_pct'])} & {fmt(ovb['PAA'])} & {fmt(ovb['ERA'])} & {fmt(ovb['DCI'])} \\\\",
              r"\bottomrule", r"\end{tabular}", r"\end{table}"]
    with open(f"{args.prefix}_overall.tex","w",encoding="utf-8") as fh:
        fh.write("\n".join(lines))

    # CSV per-profile
    with open(f"{args.prefix}_by_profile.csv","w",newline="",encoding="utf-8") as fh:
        w = csv.writer(fh)
        w.writerow(["profile","config","p50_s","schema_valid_pct","paa_pct","era_pct","dci_mean","events"])
        for pid in sorted(set(rowsa.keys()) | set(rowsb.keys())):
            if pid in rowsa:
                ra = rowsa[pid]
                w.writerow([pid, args.name_a, f"{ra['p50']:.2f}" if ra['p50']==ra['p50'] else "",
                                        f"{ra['schema_pct']:.2f}" if ra['schema_pct']==ra['schema_pct'] else "",
                                        f"{ra['PAA']:.2f}" if ra['PAA']==ra['PAA'] else "",
                                        f"{ra['ERA']:.2f}" if ra['ERA'] is not None and ra['ERA']==ra['ERA'] else "",
                                        f"{ra['DCI']:.2f}" if ra['DCI'] is not None and ra['DCI']==ra['DCI'] else "",
                                        ra["n"] or ""])
            if pid in rowsb:
                rb = rowsb[pid]
                w.writerow([pid, args.name_b, f"{rb['p50']:.2f}" if rb['p50']==rb['p50'] else "",
                                        f"{rb['schema_pct']:.2f}" if rb['schema_pct']==rb['schema_pct'] else "",
                                        f"{rb['PAA']:.2f}" if rb['PAA']==rb['PAA'] else "",
                                        f"{rb['ERA']:.2f}" if rb['ERA'] is not None and rb['ERA']==rb['ERA'] else "",
                                        f"{rb['DCI']:.2f}" if rb['DCI'] is not None and rb['DCI']==rb['DCI'] else "",
                                        rb["n"] or ""])

    # LaTeX per-profile
    lines2 = []
    lines2 += [r"\begin{table}[ht]", r"\centering",
               r"\caption{Per-profile comparison (Schema \& PAA from payload; ERA \& DCI from logs).}",
               r"\label{tab:cfg-merge-profiles}",
               r"\begin{tabular}{l l r r r r r}",
               r"\toprule",
               r"\textbf{Profile} & \textbf{Config} & \textbf{p50 (s)} & \textbf{Schema (\%)} & \textbf{PAA (\%)} & \textbf{ERA (\%)} & \textbf{DCI} \\",
               r"\midrule"]
    for pid in sorted(set(rowsa.keys()) | set(rowsb.keys())):
        if pid in rowsa:
            ra = rowsa[pid]
            lines2.append(f"{pid} & {args.name_a} & {fmt(ra['p50'])} & {fmt(ra['schema_pct'])} & {fmt(ra['PAA'])} & {fmt(ra['ERA'])} & {fmt(ra['DCI'])} \\\\")
        if pid in rowsb:
            rb = rowsb[pid]
            lines2.append(f"{pid} & {args.name_b} & {fmt(rb['p50'])} & {fmt(rb['schema_pct'])} & {fmt(rb['PAA'])} & {fmt(rb['ERA'])} & {fmt(rb['DCI'])} \\\\")
    lines2 += [r"\bottomrule", r"\end{tabular}", r"\end{table}"]
    with open(f"{args.prefix}_by_profile.tex","w",encoding="utf-8") as fh:
        fh.write("\n".join(lines2))

    print(f"Wrote {args.prefix}_overall.csv/.tex and {args.prefix}_by_profile.csv/.tex")

if __name__ == "__main__":
    main()
