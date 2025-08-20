
#!/usr/bin/env python3
import json, os, sys, math, re, argparse
from collections import defaultdict, Counter
from typing import Any, Dict, List, Tuple

# ========== KEY PATHS (adjust here if your logs use different keys) ==========
KEYS = {
    "profile": [
        ["profile_id"], ["profile"], ["user_profile"], ["user", "profile"], ["p"]
    ],
    "event_type": [
        ["event", "event_type"], ["event", "type"], ["event_type"], ["type"], ["evt_type"]
    ],
    "actions": [
        ["response", "actions"], ["actions"], ["adaptations"], ["response", "adaptations"]
    ],
    "latency_s": [
        ["latency_s"], ["latency_ms"], ["t_send"], ["t_recv"]  # we'll compute if possible
    ]
}

# ========== PROFILE NEEDS MAPPING (edit to match your IDs) ==========
PROFILE_NEEDS = {
    "P0": [],
    "P1": ["motor"],
    "P2": ["visual"],
    "P3": ["handsfree"],
    "P4": ["motor", "handsfree"],
    "P5": ["visual", "motor"],
}

# If your logs use descriptive names instead of P0..P5, add aliases here:
PROFILE_ALIASES = {
    "baseline": "P0",
    "motor": "P1",
    "visual": "P2",
    "hands-free": "P3",
    "handsfree": "P3",
    "motor+handsfree": "P4",
    "visual+motor": "P5",
}

# ========== ACTION → CATEGORY MAPPING ==========
def action_to_category(name: str, params: dict) -> str:
    """Return one of: 'motor', 'visual', 'handsfree', or 'other'."""
    n = (name or "").lower()
    if n in {"increase_button_size", "increase_button_border", "increase_slider_size", "adjust_spacing"}:
        return "motor"
    if n in {"increase_font_size", "increase_contrast"}:
        return "visual"
    if n == "switch_mode":
        mode = (params or {}).get("mode", "").lower()
        if mode in {"voice", "gesture"}:
            return "handsfree"
        # If mode is unspecified, treat as handsfree-enabling (conservative in your favour)
        return "handsfree"
    if n == "trigger_button":
        # we classify as handsfree only if used in a voice event (handled at event level)
        return "other"
    return "other"

# ========== ERROR EVENT → ACCEPTABLE CORRECTIVE ACTIONS ==========
# Any intersection between suggested actions and these sets counts as ERA success.
ACCEPTABLE = {
    "miss_tap": {"increase_button_size", "increase_button_border", "adjust_spacing", "switch_mode:voice"},
    "slider_miss": {"increase_slider_size", "adjust_spacing"},
    "voice": {"switch_mode:voice", "trigger_button"},       # confirming/using voice path
    "gesture": {"switch_mode:gesture", "trigger_button"},   # confirming/using gesture path
}

# Normalize likely event synonyms
EVENT_ALIAS = {
    "tap_miss": "miss_tap",
    "miss-tap": "miss_tap",
    "slider_overshoot": "slider_miss",
    "speech": "voice",
}

# ========== CONFLICT RULES FOR DCI ==========
# Minimal but effective:
# - Two different switch_mode targets (voice and gesture) in one response = conflict
# - Duplicate action+target pairs = duplicate
def compute_conflicts_and_duplicates(actions: List[dict]) -> Tuple[int,int]:
    dup_count = 0
    conf_count = 0

    seen = set()
    modes = set()

    for a in actions:
        name = (a.get("name") or a.get("action") or "").lower()
        target = a.get("target") or a.get("target_id") or ""
        params = a.get("params") or {}
        key = (name, str(target), json.dumps(params, sort_keys=True))

        if key in seen:
            dup_count += 1
        else:
            seen.add(key)

        if name == "switch_mode":
            mode = (params or {}).get("mode", "").lower()
            if mode:
                modes.add(mode)

    if len(modes) > 1:
        conf_count += 1

    return conf_count, dup_count

# ========== HELPERS ==========
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

def norm_profile(pid: str) -> str:
    if not pid:
        return "UNK"
    pid_low = pid.lower()
    for alias, canon in PROFILE_ALIASES.items():
        if alias == pid_low:
            return canon
    # if looks like P#, keep it
    if re.fullmatch(r"p[0-9]", pid_low):
        return pid_low.upper()
    return pid

def norm_event_type(t: str) -> str:
    if not t:
        return "UNK"
    t = t.lower()
    if t in EVENT_ALIAS:
        t = EVENT_ALIAS[t]
    return t

def extract_actions(data) -> List[dict]:
    raw = get_nested(data, KEYS["actions"])
    if raw is None:
        return []
    # normalise into list of dicts with keys name/action, params, target
    out = []
    if isinstance(raw, list):
        for item in raw:
            if isinstance(item, str):
                out.append({"name": item, "params": {}, "target": None})
            elif isinstance(item, dict):
                # harmonise keys
                name = item.get("name") or item.get("action")
                params = item.get("params") or {}
                target = item.get("target") or item.get("target_id")
                out.append({"name": name, "params": params, "target": target})
    return out

def extract_latency_s(data) -> float:
    lat = get_nested(data, [["latency_s"]])
    if isinstance(lat, (int,float)):
        return float(lat)
    lat_ms = get_nested(data, [["latency_ms"]])
    if isinstance(lat_ms, (int,float)):
        return float(lat_ms) / 1000.0
    t_send = get_nested(data, [["t_send"]])
    t_recv = get_nested(data, [["t_recv"]])
    if isinstance(t_send, (int,float)) and isinstance(t_recv, (int,float)):
        return float(t_recv) - float(t_send)
    return float("nan")

def acceptable_for_event(event_type: str) -> set:
    return ACCEPTABLE.get(event_type, set())

def action_key_for_accept(a: dict, event_type: str) -> str:
    name = (a.get("name") or a.get("action") or "").lower()
    if name == "switch_mode":
        mode = (a.get("params") or {}).get("mode", "").lower()
        if mode in {"voice", "gesture"}:
            return f"switch_mode:{mode}"
    return name

# ========== MAIN COMPUTATION ==========
def compute_metrics(log_dir: str, paa_topk: int = 0):
    files = []
    for root, _, fnames in os.walk(log_dir):
        for f in fnames:
            if f.lower().endswith(".jsonl"):
                files.append(os.path.join(root, f))
    if not files:
        raise SystemExit(f"No .jsonl files found under: {log_dir}")

    per_profile_actions = defaultdict(int)                 # counts of actions
    per_profile_accessible_actions = defaultdict(int)      # counts in {motor,visual,handsfree}
    per_profile_paa_hits = defaultdict(int)                # PAA numerator
    per_profile_paa_total = defaultdict(int)               # PAA denominator

    per_profile_error_events = defaultdict(int)            # ERA denominator
    per_profile_era_hits = defaultdict(int)                # ERA numerator

    per_profile_meh_hits = defaultdict(int)                # handsfree enablement numerator
    per_profile_total_events = defaultdict(int)            # for MEH denominator

    per_profile_dci_sum = defaultdict(float)               # sum of DCI across responses
    per_profile_dci_n = defaultdict(int)                   # count of responses

    wcag_flags = defaultdict(lambda: {"2.5.5": False, "1.4.3": False, "1.4.4": False})

    # optional: gather global counts
    global_action_total = 0
    global_action_accessible = 0

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

                profile = get_nested(data, KEYS["profile"])
                profile = norm_profile(profile) if isinstance(profile, str) else str(profile or "UNK")
                event_type = get_nested(data, KEYS["event_type"])
                event_type = norm_event_type(event_type if isinstance(event_type, str) else "")

                actions = extract_actions(data)
                latency_s = extract_latency_s(data)

                # For reporting denominators
                per_profile_total_events[profile] += 1
                is_error = event_type in {"miss_tap", "slider_miss"}

                # ----- PAA + category counts -----
                needs = set(PROFILE_NEEDS.get(profile, []))
                for a in actions:
                    name = (a.get("name") or a.get("action") or "").lower()
                    params = a.get("params") or {}
                    cat = action_to_category(name, params)

                    per_profile_actions[profile] += 1
                    global_action_total += 1
                    if cat in {"motor", "visual", "handsfree"}:
                        per_profile_accessible_actions[profile] += 1
                        global_action_accessible += 1

                        per_profile_paa_total[profile] += 1
                        if cat in needs and needs:
                            per_profile_paa_hits[profile] += 1

                        # WCAG policy coverage flags
                        if cat == "motor":
                            wcag_flags[profile]["2.5.5"] = True   # Target Size
                        elif cat == "visual":
                            # We can't distinguish contrast vs font here reliably; mark both as addressed.
                            wcag_flags[profile]["1.4.3"] = True   # Contrast
                            wcag_flags[profile]["1.4.4"] = True   # Resize text
                        elif cat == "handsfree":
                            # no direct WCAG mapping we assert here
                            pass

                # ----- ERA -----
                if is_error or event_type in {"voice", "gesture"}:
                    acc = acceptable_for_event(event_type)
                    if acc:
                        per_profile_error_events[profile] += 1
                        hit = False
                        for a in actions:
                            key = action_key_for_accept(a, event_type)
                            if key in acc:
                                hit = True
                                break
                        if hit:
                            per_profile_era_hits[profile] += 1

                # ----- MEH (only meaningful for handsfree profiles) -----
                meh_hit = False
                for a in actions:
                    name = (a.get("name") or a.get("action") or "").lower()
                    params = a.get("params") or {}
                    if name == "switch_mode":
                        mode = (params.get("mode") or params.get("to") or params.get("modality") or "").lower()
                        if mode in {"voice","gesture"} or event_type in {"voice","gesture"}:
                            meh_hit = True
                    if name == "trigger_button" and event_type == "voice":
                        meh_hit = True
                if meh_hit:
                    per_profile_meh_hits[profile] += 1

                # ----- DCI -----
                conf, dup = compute_conflicts_and_duplicates(actions)
                sugg = max(1, len(actions))  # avoid div0; single suggestion with 1 conflict still penalises
                dci = 1.0 - float(conf + dup) / float(sugg)
                dci = max(0.0, min(1.0, dci))
                per_profile_dci_sum[profile] += dci
                per_profile_dci_n[profile] += 1


    # ----- Optional: restrict PAA to top-K actions per profile -----
    # If paa_topk > 0, we recompute PAA numerator/denominator using only the top-K most frequent actions per profile.
    if paa_topk and paa_topk > 0:
        # First, compute per-profile frequency of actions by name
        freq_by_prof = defaultdict(Counter)
        # We need to recompute by scanning log files again to record action frequencies.
        files2 = []
        for root, _, fnames in os.walk(log_dir):
            for f in fnames:
                if f.lower().endswith(".jsonl"):
                    files2.append(os.path.join(root, f))
        for path in files2:
            with open(path, "r", encoding="utf-8") as fh:
                for line in fh:
                    line = line.strip()
                    if not line:
                        continue
                    try:
                        data = json.loads(line)
                    except Exception:
                        continue
                    profile = get_nested(data, KEYS["profile"])
                    profile = norm_profile(profile) if isinstance(profile, str) else str(profile or "UNK")
                    actions = extract_actions(data)
                    for a in actions:
                        name = (a.get("name") or a.get("action") or "").lower()
                        freq_by_prof[profile][name] += 1

        # Determine top-K action names per profile
        topk_names = {}
        for p, counter in freq_by_prof.items():
            topk_names[p] = {name for name, _ in counter.most_common(paa_topk)}

        # Reset PAA accumulators and rescan using only top-K
        per_profile_paa_hits.clear()
        per_profile_paa_total.clear()
        for path in files2:
            with open(path, "r", encoding="utf-8") as fh:
                for line in fh:
                    line = line.strip()
                    if not line:
                        continue
                    try:
                        data = json.loads(line)
                    except Exception:
                        continue
                    profile = get_nested(data, KEYS["profile"])
                    profile = norm_profile(profile) if isinstance(profile, str) else str(profile or "UNK")
                    actions = extract_actions(data)
                    needs = set(PROFILE_NEEDS.get(profile, []))
                    allowed_names = topk_names.get(profile, set())
                    for a in actions:
                        name = (a.get("name") or a.get("action") or "").lower()
                        params = a.get("params") or {}
                        cat = action_to_category(name, params)
                        if name in allowed_names and cat in {"motor","visual","handsfree"}:
                            per_profile_paa_total[profile] += 1
                            if cat in needs and needs:
                                per_profile_paa_hits[profile] += 1

    # ----- Aggregate results -----
    rows = []
    profiles = sorted(per_profile_total_events.keys())

    for p in profiles:
        paa_total = per_profile_paa_total[p]
        paa_pct = 100.0 * per_profile_paa_hits[p] / paa_total if paa_total else float("nan")

        era_den = per_profile_error_events[p]
        era_pct = 100.0 * per_profile_era_hits[p] / era_den if era_den else float("nan")

        meh_den = per_profile_total_events[p]
        meh_pct = 100.0 * per_profile_meh_hits[p] / meh_den if meh_den else float("nan")

        dci_n = per_profile_dci_n[p]
        dci_mean = per_profile_dci_sum[p] / dci_n if dci_n else float("nan")

        rows.append({
            "profile": p,
            "paa_pct": round(paa_pct, 2) if isinstance(paa_pct, float) else "",
            "era_pct": round(era_pct, 2) if isinstance(era_pct, float) else "",
            "meh_pct": round(meh_pct, 2) if isinstance(meh_pct, float) else "",
            "dci_mean": round(dci_mean, 3) if isinstance(dci_mean, float) else "",
            "actions_total": per_profile_actions[p],
            "actions_accessible": per_profile_accessible_actions[p],
            "wcag_2_5_5": "✓" if wcag_flags[p]["2.5.5"] else "—",
            "wcag_1_4_3": "✓" if wcag_flags[p]["1.4.3"] else "—",
            "wcag_1_4_4": "✓" if wcag_flags[p]["1.4.4"] else "—",
        })

    global_share = 100.0 * global_action_accessible / global_action_total if global_action_total else float("nan")

    return rows, {
        "global_actions_total": global_action_total,
        "global_actions_accessible": global_action_accessible,
        "global_share_accessible_pct": round(global_share, 2) if isinstance(global_share, float) else ""
    }

def write_csv(rows, globals_agg, out_summary, out_by_profile):
    # global summary
    with open(out_summary, "w", encoding="utf-8") as fh:
        fh.write("metric,value\n")
        for k, v in globals_agg.items():
            fh.write(f"{k},{v}\n")

    # per-profile
    headers = ["profile","paa_pct","era_pct","meh_pct","dci_mean","actions_total","actions_accessible","wcag_2_5_5","wcag_1_4_3","wcag_1_4_4"]
    with open(out_by_profile, "w", encoding="utf-8") as fh:
        fh.write(",".join(headers) + "\n")
        for r in rows:
            fh.write(",".join(str(r[h]) for h in headers) + "\n")

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("logdir", help="Directory with .jsonl logs")
    ap.add_argument("--paa-topk", type=int, default=0, help="Restrict PAA to top-K most frequent actions per profile (0 = all)")
    ap.add_argument("--summary-csv", default="metrics_summary.csv")
    ap.add_argument("--by-profile-csv", default="metrics_by_profile.csv")
    args = ap.parse_args()

    rows, globals_agg = compute_metrics(args.logdir, paa_topk=args.paa_topk)
    write_csv(rows, globals_agg, args.summary_csv, args.by_profile_csv)

    print("Done. Wrote:")
    print("  -", args.summary_csv)
    print("  -", args.by_profile_csv)

if __name__ == "__main__":
    main()
