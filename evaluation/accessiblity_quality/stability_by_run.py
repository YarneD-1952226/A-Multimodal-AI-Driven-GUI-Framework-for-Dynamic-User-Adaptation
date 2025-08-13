#!/usr/bin/env python3
import os, re, json, math, csv, argparse
from pathlib import Path
from typing import List, Dict, Tuple

# -------- Robust key paths --------
KEYS = {
    "profile": [
        ["profile_id"], ["profile"], ["user_profile"], ["user","profile"], ["p"]
    ],
    "event_type": [
        ["event","event_type"], ["event","type"], ["event_type"], ["type"]
    ],
    "event_index": [
        ["event","index"], ["event_index"], ["idx"], ["event","idx"]
    ],
    "run_index": [
        ["run"], ["run_id"], ["run_index"], ["event","run"], ["meta","run"]
    ],
    "actions": [
        ["response","adaptations"], ["response","actions"], ["adaptations"], ["actions"]
    ]
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

def norm_profile(pid: str, filename: str) -> str:
    if isinstance(pid, str) and pid.strip():
        # Canonicalize "p2" -> "P2"
        m = re.fullmatch(r"[pP](\d+)", pid.strip())
        if m: return f"P{m.group(1)}"
        return pid
    # Fallback: infer from filename like profile2.jsonl -> P2
    m = re.search(r"profile\s*([0-9]+)", filename, flags=re.I)
    if m: return f"P{m.group(1)}"
    return "P?"

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
                out.append({"name": name, "params": params, "target": target})
    return out

def jaccard(set_a: set, set_b: set) -> float:
    if not set_a and not set_b:
        return 1.0
    union = set_a | set_b
    inter = set_a & set_b
    if not union:
        return 1.0
    return len(inter) / len(union)

def compute_stability(logdir: str, events_per_run: int = 7) -> Tuple[Dict[str, List[float]], List[int]]:
    # Gather files
    files = []
    for root, _, fnames in os.walk(logdir):
        for f in fnames:
            if f.lower().endswith(".jsonl"):
                files.append(os.path.join(root, f))
    if not files:
        raise SystemExit(f"No .jsonl files found under: {logdir}")

    # Data structure: per profile, per run (0/1), per event_index -> set of (action,target)
    per_prof = {}

    for path in files:
        with open(path, "r", encoding="utf-8") as fh:
            for line in fh:
                line = line.strip()
                if not line: continue
                try:
                    data = json.loads(line)
                except Exception:
                    continue
                profile = get_nested(data, KEYS["profile"])
                profile = norm_profile(profile if isinstance(profile, str) else "", Path(path).name)

                # Event index per run
                ev_idx = get_nested(data, KEYS["event_index"])
                if isinstance(ev_idx, str):
                    try: ev_idx = int(ev_idx)
                    except: ev_idx = None
                if not isinstance(ev_idx, int):
                    ev_idx = None  # will infer via position later

                # Run index
                run_idx = get_nested(data, KEYS["run_index"])
                if isinstance(run_idx, str):
                    try: run_idx = int(run_idx)
                    except: run_idx = None
                if not isinstance(run_idx, int):
                    run_idx = None  # will infer via position later

                # Initialize structures
                per_prof.setdefault(profile, {"rows": [], "bypos": {}})
                per_prof[profile]["rows"].append({
                    "run": run_idx, "ev": ev_idx, "file": path, "data": data
                })

    # Infer run/ev positions if missing: assume chronological order, split by events_per_run
    for p, bundle in per_prof.items():
        rows = bundle["rows"]
        # sort by file order occurrence
        # Keep existing order as they appeared
        # Assign run/ev when missing
        seen = 0
        for i, row in enumerate(rows):
            r = row["run"]
            e = row["ev"]
            if r is None or e is None:
                # infer based on position
                r = seen // events_per_run
                e = seen % events_per_run
                row["run"] = r
                row["ev"] = e
            seen += 1

        # Build bypos index
        bypos = {0:{},1:{}}
        for row in rows:
            r = row["run"]; e = row["ev"]
            if r not in (0,1): continue  # only first two runs
            # Extract action–target pairs
            actions = extract_actions(row["data"])
            at_set = set()
            for a in actions:
                name = (a.get("name") or a.get("action") or "").lower()
                target = a.get("target")
                at_set.add((name, str(target)))
            bypos[r][e] = at_set
        per_prof[p]["bypos"] = bypos

    # Compute Jaccard per event index and mean
    per_prof_scores = {}
    event_indices = list(range(events_per_run))
    for p, bundle in per_prof.items():
        bypos = bundle["bypos"]
        scores = []
        for e in event_indices:
            s0 = bypos.get(0, {}).get(e, set())
            s1 = bypos.get(1, {}).get(e, set())
            scores.append(jaccard(s0, s1))
        per_prof_scores[p] = scores

    return per_prof_scores, event_indices

def write_csv(per_prof_scores: Dict[str, List[float]], event_indices: List[int], out_csv: str):
    with open(out_csv, "w", newline="", encoding="utf-8") as fh:
        w = csv.writer(fh)
        headers = ["profile"] + [f"E{e+1}" for e in event_indices] + ["mean"]
        w.writerow(headers)
        for p in sorted(per_prof_scores.keys()):
            vals = per_prof_scores[p]
            mean = sum(vals)/len(vals) if vals else float("nan")
            w.writerow([p] + [f"{v:.2f}" for v in vals] + [f"{mean:.2f}"])



def main():
    import argparse
    ap = argparse.ArgumentParser()
    ap.add_argument("logdir", help="Directory with .jsonl logs (scanned recursively)")
    ap.add_argument("--events-per-run", type=int, default=5, help="Number of events per run (default 5)")
    ap.add_argument("--csv", default="stability_by_run.csv", help="Output CSV path")
    args = ap.parse_args()

    per_prof_scores, event_indices = compute_stability(args.logdir, args.events_per_run)
    write_csv(per_prof_scores, event_indices, args.csv)
    print(f"Wrote {args.csv}.")

if __name__ == "__main__":
    main()
