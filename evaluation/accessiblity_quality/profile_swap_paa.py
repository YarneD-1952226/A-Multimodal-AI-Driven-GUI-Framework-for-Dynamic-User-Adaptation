#!/usr/bin/env python3
import os, re, json, math, argparse, csv
from collections import defaultdict, Counter
from typing import List, Dict, Tuple, Optional

# --------- Configurable mappings ---------
PROFILE_NEEDS: Dict[str, List[str]] = {
    "P0": [],
    "P1": ["motor"],
    "P2": ["visual"],
    "P3": ["handsfree"],
    "P4": ["motor","handsfree"],
    "P5": ["visual","motor"],
}

MOTOR_ACTIONS = {"increase_button_size","increase_button_border","increase_slider_size","adjust_spacing"}
VISUAL_ACTIONS = {"increase_font_size","increase_contrast"}
# handsfree relies on params/event_type
HANDSFREE_ACTIONS = {"switch_mode", "trigger_button"}

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

def action_to_category(name: str, params: dict, event_type: str) -> Optional[str]:
    n = (name or "").lower()
    if n in MOTOR_ACTIONS: return "motor"
    if n in VISUAL_ACTIONS: return "visual"
    if n == "switch_mode":
        mode = (params.get("mode") or params.get("to") or params.get("modality") or "").lower()
        if mode in {"voice","gesture"}:
            return "handsfree"
        if event_type in {"voice","gesture"}:
            return "handsfree"
    if n == "trigger_button" and event_type == "voice":
        return "handsfree"
    return None

def scan_logs(logdir: str):
    files = []
    for root, _, fnames in os.walk(logdir):
        for f in fnames:
            if f.lower().endswith(".jsonl"):
                files.append(os.path.join(root, f))
    if not files:
        raise SystemExit(f"No .jsonl files found under: {logdir}")
    return files

def compute_topk_by_profile(files: List[str], paa_topk: int) -> Dict[str, set]:
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
                profile = norm_profile(get_nested(data, KEYS["profile"]), os.path.basename(path))
                acts = extract_actions(data)
                for a in acts:
                    n = (a.get("name") or a.get("action") or "").lower()
                    if not n: continue
                    freq[profile][n] += 1
    topk = {}
    for p,c in freq.items():
        if paa_topk and paa_topk>0:
            topk[p] = {name for name,_ in c.most_common(paa_topk)}
        else:
            topk[p] = set(c.keys())
    return topk

def compute_paa(files: List[str], paa_topk: int = 5) -> Tuple[Dict[str, float], Dict[str, float]]:
    topk = compute_topk_by_profile(files, paa_topk)
    hits = defaultdict(int); tot = defaultdict(int)
    # For swaps: for each profile, keep category sequence to rescore later
    per_profile_categories = defaultdict(list)

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
                needs = set(PROFILE_NEEDS.get(prof, []))
                evtype = norm_event_type(get_nested(data, KEYS["event_type"]))
                acts = extract_actions(data)
                allowed = topk.get(prof, set())
                for a in acts:
                    name = (a.get("name") or a.get("action") or "").lower()
                    cat = action_to_category(name, a.get("params") or {}, evtype)
                    if cat not in {"motor","visual","handsfree"}:
                        continue
                    if paa_topk and name not in allowed:
                        continue
                    tot[prof] += 1
                    if needs and cat in needs:
                        hits[prof] += 1
                    # store for swap rescoring
                    per_profile_categories[prof].append(cat)

    orig_paa = {}
    for p in tot:
        if tot[p] == 0:
            orig_paa[p] = float("nan")
        else:
            orig_paa[p] = 100.0 * hits[p] / tot[p]

    # Swap rescoring: for each p, rescore its categories against needs(q) for q!=p and average
    swap_mean = {}
    profs = sorted(k for k in per_profile_categories.keys() if k != "P0")
    for p in profs:
        cats = per_profile_categories[p]
        if not cats:
            swap_mean[p] = float("nan")
            continue
        vals = []
        for q in profs:
            if q == p: continue
            needs_q = set(PROFILE_NEEDS.get(q, []))
            if not needs_q:
                continue
            hit = sum(1 for c in cats if c in needs_q)
            vals.append(100.0 * hit / len(cats))
        swap_mean[p] = sum(vals)/len(vals) if vals else float("nan")

    return orig_paa, swap_mean

def write_outputs(orig: Dict[str,float], swap: Dict[str,float], out_csv: str):
    rows = []
    for p in ["P1","P2","P3","P4","P5"]:
        o = orig.get(p, float("nan"))
        s = swap.get(p, float("nan"))
        rows.append((p, o, s, None if (math.isnan(o) or math.isnan(s)) else (o - s)))

    # CSV
    with open(out_csv, "w", newline="", encoding="utf-8") as fh:
        w = csv.writer(fh)
        w.writerow(["profile","original_paa_pct","swap_mean_paa_pct","drop_points"])
        for p,o,s,d in rows:
            w.writerow([p,
                        ("" if math.isnan(o) else round(o,2)),
                        ("" if math.isnan(s) else round(s,2)),
                        ("" if d is None else round(d,2))])

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("logdir", help="Directory with .jsonl logs (scanned recursively)")
    ap.add_argument("--paa-topk", type=int, default=5, help="Restrict PAA to top-K actions per profile (default 5, 0 = all)")
    ap.add_argument("--csv", default="profile_swap_paa.csv", help="Output CSV")
    args = ap.parse_args()

    # scan files
    files = []
    for root,_,fnames in os.walk(args.logdir):
        for f in fnames:
            if f.lower().endswith(".jsonl"):
                files.append(os.path.join(root,f))
    if not files:
        raise SystemExit(f"No .jsonl files found under: {args.logdir}")

    orig, swap = compute_paa(files, paa_topk=args.paa_topk)
    write_outputs(orig, swap, args.csv)

    # Print a short summary
    vals = []
    for p in ["P1","P2","P3","P4","P5"]:
        o = orig.get(p, float("nan"))
        s = swap.get(p, float("nan"))
        if not (math.isnan(o) or math.isnan(s)):
            vals.append(o - s)
    avg_drop = (sum(vals)/len(vals)) if vals else float("nan")
    avg_drop_s = "--" if math.isnan(avg_drop) else f"{avg_drop:.2f}"
    print(f"Mean drop (P1--P5): {avg_drop_s} points")

if __name__ == "__main__":
    main()
