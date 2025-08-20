#!/usr/bin/env python3
import os, re, json, argparse, csv
from collections import defaultdict, Counter

KEYS = {
    "profile": [["profile_id"], ["profile"], ["user_profile"], ["user","profile"], ["p"]],
    "event_type": [["event","event_type"], ["event","type"], ["event_type"], ["type"], ["evt_type"]],
}

def get_nested(d, paths):
    for p in paths:
        cur = d; ok = True
        for k in p:
            if not isinstance(cur, dict) or k not in cur:
                ok = False; break
            cur = cur[k]
        if ok: return cur
    return None

def norm_profile(pid, fname):
    if isinstance(pid, str) and pid.strip():
        m = re.fullmatch(r"[pP](\d+)", pid.strip())
        if m: return f"P{m.group(1)}"
        return pid
    m = re.search(r"profile\s*([0-9]+)", fname, flags=re.I)
    if m: return f"P{m.group(1)}"
    return "P?"

def norm_event_type(t):
    if not t: return "UNK"
    s = str(t).lower().replace("-", "_").replace(" ", "_").strip()
    if "miss" in s and "tap" in s: return "miss_tap"
    if "slider" in s and ("miss" in s or "overshoot" in s): return "slider_miss"
    if "voice" in s or "speech" in s or "asr" in s: return "voice"
    if "gesture" in s or "point" in s: return "gesture"
    return s

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("logdir")
    ap.add_argument("--csv", default="event_counts_by_profile.csv")
    args = ap.parse_args()

    files = []
    for root,_,fnames in os.walk(args.logdir):
        for f in fnames:
            if f.lower().endswith(".jsonl"):
                files.append(os.path.join(root,f))
    if not files:
        raise SystemExit(f"No .jsonl files found under: {args.logdir}")

    counts = defaultdict(Counter)
    for path in files:
        with open(path, "r", encoding="utf-8") as fh:
            for line in fh:
                line=line.strip()
                if not line: continue
                try:
                    data = json.loads(line)
                except Exception:
                    continue
                p = norm_profile(get_nested(data, KEYS["profile"]), os.path.basename(path))
                ev = norm_event_type(get_nested(data, KEYS["event_type"]))
                counts[p][ev] += 1
                counts[p]["ALL"] += 1

    with open(args.csv, "w", newline="", encoding="utf-8") as fh:
        w = csv.writer(fh)
        w.writerow(["profile","miss_tap","slider_miss","voice","gesture","ALL"])
        for p in sorted(counts.keys()):
            c = counts[p]
            w.writerow([p, c.get("miss_tap",0), c.get("slider_miss",0), c.get("voice",0), c.get("gesture",0), c.get("ALL",0)])
    print("Wrote", args.csv)

if __name__ == "__main__":
    main()
