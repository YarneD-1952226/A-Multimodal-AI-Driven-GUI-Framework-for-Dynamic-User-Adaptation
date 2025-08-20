#!/usr/bin/env python3
import os, sys, json, math, argparse
from collections import defaultdict
from typing import List, Tuple

EVENT_ALIAS = {
    "tap_miss": "miss_tap",
    "miss-tap": "miss_tap",
    "slider_overshoot": "slider_miss",
    "speech": "voice",
}

def norm_event_type(t: str) -> str:
    if not t:
        return "UNK"
    s = t.lower().replace("-", "_").replace(" ", "_").strip()
    s = EVENT_ALIAS.get(s, s)
    if "miss" in s and "tap" in s:
        return "miss_tap"
    if "slider" in s and ("miss" in s or "overshoot" in s):
        return "slider_miss"
    if "voice" in s or "speech" in s or "asr" in s:
        return "voice"
    if "gesture" in s or "point" in s:
        return "gesture"
    return s

ACCEPTABLE = {
    "miss_tap": {"increase_button_size", "increase_button_border", "adjust_spacing", "switch_mode:voice"},
    "slider_miss": {"increase_slider_size", "adjust_spacing"},
    "voice": {"switch_mode:voice", "trigger_button"},
    "gesture": {"switch_mode:gesture", "trigger_button"},
}

NOTES = {
    "miss_tap": "motor fixes prevalent",
    "slider_miss": "slider size/spacing",
    "voice": "mode confirmation",
    "gesture": "mode confirmation",
}

KEYS = {
    "event_type": [
        ["event", "event_type"], ["event", "type"], ["event_type"], ["type"], ["evt_type"]
    ],
    "actions": [
        ["response", "adaptations"], ["response", "actions"], ["adaptations"], ["actions"]
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

def extract_actions(data: dict):
    raw = get_nested(data, KEYS["actions"])
    if raw is None:
        return []
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

def action_key_for_accept(a: dict, event_type: str) -> str:
    # Map an action to a key that matches ACCEPTABLE[event]
    name = (a.get("name") or a.get("action") or "").lower()
    if name == "switch_mode":
        params = a.get("params") or {}
        mode = (params.get("mode") or params.get("to") or params.get("modality") or "").lower()
        if mode in {"voice", "gesture"}:
            return f"switch_mode:{mode}"
        if event_type in {"voice", "gesture"}:
            return f"switch_mode:{event_type}"
    return name

def wilson_ci(k: int, n: int, z: float = 1.96):
    if n == 0:
        return (float("nan"), float("nan"))
    phat = k / n
    z2 = z * z
    denom = 1 + z2 / n
    center = (phat + z2/(2*n)) / denom
    half = (z * ((phat*(1 - phat) + z2/(4*n))/n)**0.5) / denom
    lo, hi = center - half, center + half
    return (max(0.0, lo), min(1.0, hi))

def compute_era_by_event(logdir: str):
    files = []
    for root, _, fnames in os.walk(logdir):
        for f in fnames:
            if f.lower().endswith(".jsonl"):
                files.append(os.path.join(root, f))
    if not files:
        raise SystemExit(f"No .jsonl files found under: {logdir}")

    counts = {k: 0 for k in ["miss_tap", "slider_miss", "voice", "gesture"]}
    hits   = {k: 0 for k in ["miss_tap", "slider_miss", "voice", "gesture"]}

    for path in files:
        with open(path, "r", encoding="utf-8") as fh:
            for line in fh:
                line = line.strip()
                if not line:
                    continue
                try:
                    data = json.loads(line)
                except Exception:
                    continue
                ev = get_nested(data, KEYS["event_type"])
                ev = norm_event_type(ev if isinstance(ev, str) else "")
                if ev not in counts:
                    continue
                counts[ev] += 1
                actions = extract_actions(data)
                acc = ACCEPTABLE.get(ev, set())
                ok = False
                for a in actions:
                    key = action_key_for_accept(a, ev)
                    if key in acc:
                        ok = True
                        break
                if ok:
                    hits[ev] += 1

    rows = []
    for ev in ["miss_tap", "slider_miss", "voice", "gesture"]:
        n = counts[ev]
        k = hits[ev]
        era = (k / n * 100.0) if n else float("nan")
        lo, hi = wilson_ci(k, n)
        ci_str = "--" if n == 0 else f"[{lo*100:.2f}, {hi*100:.2f}]"
        rows.append((ev, n, None if math.isnan(era) else round(era, 2), ci_str))
    return rows

def write_csv(rows, out_csv: str):
    import csv
    with open(out_csv, "w", newline="", encoding="utf-8") as fh:
        w = csv.writer(fh)
        w.writerow(["event", "count", "era_pct", "ci_95", "notes"])
        for ev, cnt, era, ci in rows:
            w.writerow([ev, cnt, era, ci, NOTES.get(ev, "")])

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("logdir", help="Directory with .jsonl logs (scanned recursively)")
    ap.add_argument("--csv", default="era_by_event.csv", help="Output CSV path")
    args = ap.parse_args()

    rows = compute_era_by_event(args.logdir)
    write_csv(rows, args.csv)

    print("ERA by event type:")
    for ev, cnt, era, ci in rows:
        era_str = "--" if era is None else f"{era:.2f}%"
        print(f"  {ev:12s} count={cnt:3d}  ERA={era_str:>6}  CI95={ci}")

if __name__ == "__main__":
    main()
