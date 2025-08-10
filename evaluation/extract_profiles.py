"""
extract_profiles_events.py

Reads one or more JSONL files that contain PER-EVENT records like:
{
  "run_id": "...", "profile_id": "P0", "run_index": 1, "event_index": 1,
  "event": {...}, "t_send": "...", "t_recv": "...",
  "latency_ms": 21095.52,
  "response": {"adaptations":[...]},
  "schema_valid": true,
  "classification": "validated_by_validator",
  "backend_config": "MA-SIF balanced + instant rules"
}

It aggregates per user (from event.user_id or profile_id) and writes:
- A JSON payload for Chapter 6 (compact, paste-able)
- A CSV summary for quick scanning

Run:
python extract_profiles_events.py \
  --glob "/mnt/data/profile*.jsonl" \
  --output-json "/mnt/data/chapter6_payload.json" \
  --output-csv "/mnt/data/profile_summary.csv"
"""

import argparse
import glob
import json
import math
from collections import Counter
from datetime import datetime
from pathlib import Path

def parse_args():
    ap = argparse.ArgumentParser(description="Aggregate profile*.jsonl event logs into Chapter 6 payload + CSV.")
    ap.add_argument("--glob", required=True, help="Glob pattern to JSONL files, e.g. '/mnt/data/profile*.jsonl'")
    ap.add_argument("--output-json", default="chapter6_payload.json", help="Output JSON path")
    ap.add_argument("--output-csv", default="profile_summary.csv", help="Output CSV path")
    ap.add_argument("--keep-last-events", type=int, default=10, help="How many recent events to include per user in JSON payload")
    return ap.parse_args()

def percentile(values, p):
    """Return the pth percentile (0-100) with linear interpolation."""
    if not values:
        return None
    x = sorted(values)
    if len(x) == 1:
        return float(x[0])
    k = (p / 100.0) * (len(x) - 1)
    f = math.floor(k)
    c = math.ceil(k)
    if f == c:
        return float(x[int(k)])
    d0 = x[f] * (c - k)
    d1 = x[c] * (k - f)
    return float(d0 + d1)

def coerce_float(v):
    try:
        return float(v)
    except Exception:
        return None

def safe_get(d, *keys, default=None):
    cur = d
    for k in keys:
        if not isinstance(cur, dict) or k not in cur:
            return default
        cur = cur[k]
    return cur

def main():
    args = parse_args()
    files = sorted(glob.glob(args.glob))
    if not files:
        print(f"No files matched: {args.glob}")
        # Still create empty outputs for transparency
        Path(args.output_json).write_text(json.dumps({"files": [], "overall": {}, "per_user": []}, indent=2))
        Path(args.output_csv).write_text("user_id,events_total,miss_tap,tap,voice,gesture,key_press,other,schema_valid_pct,latency_p50_ms,latency_p90_ms,latency_max_ms,top_targets,top_miss_targets,backend_top,validated_pct,combined_pct,mock_pct\n")
        return

    # Aggregate structures
    users = {}
    overall_latencies = []
    overall_schema_valid = []
    overall_class = Counter()
    overall_backend_cfg = Counter()
    overall_actions = Counter()

    def ensure_user(uid):
        if uid not in users:
            users[uid] = {
                "user_id": uid,
                "profile_ids": set(),
                "run_ids": set(),
                "events": [],  # minimal info; we keep last N
                "counts": Counter(),        # event_type counts
                "targets": Counter(),       # target_element counts
                "miss_targets": Counter(),  # targets for miss_tap
                "schema_valid_count": 0,
                "schema_total": 0,
                "classifications": Counter(),
                "backend_configs": Counter(),
                "latencies": [],
                "actions": Counter(),
                "action_targets": Counter(),  # (action,target)
            }
        return users[uid]

    # Read & aggregate
    seen_lines = 0
    parsed_lines = 0
    for fp in files:
        with open(fp, "r", encoding="utf-8") as f:
            for line in f:
                seen_lines += 1
                line = line.strip()
                if not line:
                    continue
                try:
                    rec = json.loads(line)
                except Exception:
                    continue

                parsed_lines += 1
                event = rec.get("event", {})
                user_id = event.get("user_id") or rec.get("profile_id") or "unknown"

                u = ensure_user(user_id)
                if rec.get("profile_id"):
                    u["profile_ids"].add(rec["profile_id"])
                if rec.get("run_id"):
                    u["run_ids"].add(rec["run_id"])

                ev_type = event.get("event_type", "unknown")
                target = event.get("target_element") or "unknown"

                # counts
                u["counts"][ev_type] += 1
                u["targets"][target] += 1
                if ev_type == "miss_tap":
                    u["miss_targets"][target] += 1

                # schema valid
                schema_valid = rec.get("schema_valid", None)
                if schema_valid is not None:
                    u["schema_total"] += 1
                    overall_schema_valid.append(1 if schema_valid else 0)
                    if schema_valid:
                        u["schema_valid_count"] += 1

                # classification
                cls = rec.get("classification", None)
                if cls:
                    u["classifications"][cls] += 1
                    overall_class[cls] += 1

                # backend config
                bc = rec.get("backend_config", None)
                if bc:
                    u["backend_configs"][bc] += 1
                    overall_backend_cfg[bc] += 1

                # latency
                lat = coerce_float(rec.get("latency_ms"))
                if lat is None:
                    # fallback from timestamps
                    t_send = rec.get("t_send")
                    t_recv = rec.get("t_recv")
                    try:
                        if t_send and t_recv:
                            a = datetime.fromisoformat(t_send.replace("Z", "+00:00"))
                            b = datetime.fromisoformat(t_recv.replace("Z", "+00:00"))
                            lat = (b - a).total_seconds() * 1000.0
                    except Exception:
                        lat = None
                if lat is not None:
                    u["latencies"].append(lat)
                    overall_latencies.append(lat)

                # actions from response
                adaps = safe_get(rec, "response", "adaptations", default=[])
                if isinstance(adaps, list):
                    for a in adaps:
                        action = a.get("action", "unknown_action")
                        u["actions"][action] += 1
                        overall_actions[action] += 1
                        tgt = a.get("target", "all")
                        u["action_targets"][(action, tgt)] += 1

                # Minimal event log (for last N events)
                u["events"].append({
                    "run_id": rec.get("run_id"),
                    "run_index": rec.get("run_index"),
                    "event_index": rec.get("event_index"),
                    "t_send": rec.get("t_send"),
                    "t_recv": rec.get("t_recv"),
                    "latency_ms": lat,
                    "schema_valid": schema_valid,
                    "classification": cls,
                    "backend_config": bc,
                    "event_type": ev_type,
                    "target_element": target,
                    "adaptations_count": len(adaps) if isinstance(adaps, list) else 0
                })

    # Build per-user summaries
    per_user = []
    for uid, u in users.items():
        total_events = sum(u["counts"].values())
        miss_taps = u["counts"].get("miss_tap", 0)
        taps = u["counts"].get("tap", 0)
        voice = u["counts"].get("voice", 0)
        gesture = u["counts"].get("gesture", 0)
        key_press = u["counts"].get("key_press", 0)
        other = total_events - (miss_taps + taps + voice + gesture + key_press)

        miss_rate = (miss_taps / total_events) if total_events else 0.0
        schema_valid_pct = (u["schema_valid_count"] / u["schema_total"] * 100.0) if u["schema_total"] else None

        p50 = percentile(u["latencies"], 50)
        p90 = percentile(u["latencies"], 90)
        pmax = max(u["latencies"]) if u["latencies"] else None

        top_targets = ", ".join([f"{k}:{v}" for k, v in u["targets"].most_common(3)])
        top_miss_targets = ", ".join([f"{k}:{v}" for k, v in u["miss_targets"].most_common(3)])
        backend_top = u["backend_configs"].most_common(1)[0][0] if u["backend_configs"] else None

        total_cls = sum(u["classifications"].values()) or 1
        validated_pct = (u["classifications"].get("validated_by_validator", 0) / total_cls) * 100.0
        combined_pct = (u["classifications"].get("combined_agent_suggestions", 0) / total_cls) * 100.0
        mock_pct = (u["classifications"].get("mock_rule_fallback", 0) / total_cls) * 100.0

        # Keep only the last N events
        last_events = u["events"][-args.keep_last_events:] if u["events"] else []

        # Quick recommendations (nice for Chapter 6 narrative)
        recs = []
        if miss_rate >= 0.15 or miss_taps >= 3:
            recs.append("Increase button size/border and spacing on top-miss targets")
        if voice >= 2 and gesture == 0:
            recs.append("Offer voice-first flow (switch_mode: voice)")
        if gesture >= 2 and voice == 0:
            recs.append("Offer gesture-first flow (switch_mode: gesture)")
        if schema_valid_pct is not None and schema_valid_pct < 80:
            recs.append("Raise validator thinking budget or relax JSON schema")
        if p50 and p50 > 12000:
            recs.append("Use lighter agent config or async apply for non-critical actions")

        per_user.append({
            "user_id": uid,
            "profile_ids": sorted(u["profile_ids"]),
            "run_ids": sorted(u["run_ids"]),
            "events_total": total_events,
            "events_by_type": dict(u["counts"]),
            "miss_tap_rate": round(miss_rate, 4),
            "schema_valid_pct": round(schema_valid_pct, 2) if schema_valid_pct is not None else None,
            "latency_ms": {
                "p50": round(p50, 2) if p50 is not None else None,
                "p90": round(p90, 2) if p90 is not None else None,
                "max": round(pmax, 2) if pmax is not None else None,
            },
            "top_targets": top_targets,
            "top_miss_targets": top_miss_targets,
            "backend_top": backend_top,
            "classification_pct": {
                "validated_by_validator": round(validated_pct, 2),
                "combined_agent_suggestions": round(combined_pct, 2),
                "mock_rule_fallback": round(mock_pct, 2),
            },
            "top_actions": dict(u["actions"].most_common(5)),
            "last_events": last_events,
            "recommendations": recs
        })

    # Overall summary
    overall_latencies = [l for u in users.values() for l in u["latencies"]]
    overall_schema_valid = []
    for u in users.values():
        overall_schema_valid.extend([1]*u["schema_valid_count"] + [0]*(u["schema_total"]-u["schema_valid_count"]))

    # classification + backend + actions
    overall_class = Counter()
    overall_backend_cfg = Counter()
    overall_actions = Counter()
    for u in users.values():
        overall_class.update(u["classifications"])
        overall_backend_cfg.update(u["backend_configs"])
        overall_actions.update(u["actions"])

    overall = {}
    overall["files"] = files
    overall["events_total"] = sum(sum(u["counts"].values()) for u in users.values())
    overall["users_total"] = len(users)

    overall["latency_ms"] = {
        "p50": round(percentile(overall_latencies, 50), 2) if overall_latencies else None,
        "p90": round(percentile(overall_latencies, 90), 2) if overall_latencies else None,
        "max": round(max(overall_latencies), 2) if overall_latencies else None,
    }
    if overall_schema_valid:
        overall["schema_valid_pct"] = round(sum(overall_schema_valid) / len(overall_schema_valid) * 100.0, 2)
    else:
        overall["schema_valid_pct"] = None

    total_cls_overall = sum(overall_class.values()) or 1
    overall["classification_pct"] = {
        k: round(v / total_cls_overall * 100.0, 2) for k, v in overall_class.items()
    }
    overall["backend_configs"] = dict(overall_backend_cfg.most_common())
    overall["top_actions"] = dict(overall_actions.most_common(10))

    payload = {
        "files": files,
        "overall": overall,
        "per_user": per_user
    }

    # Write JSON
    Path(args.output_json).write_text(json.dumps(payload, indent=2))

    # Write CSV
    headers = [
        "user_id","events_total","miss_tap","tap","voice","gesture","key_press","other",
        "schema_valid_pct","latency_p50_ms","latency_p90_ms","latency_max_ms",
        "top_targets","top_miss_targets","backend_top",
        "validated_pct","combined_pct","mock_pct"
    ]
    rows = [",".join(headers)]
    for u in per_user:
        counts = u["events_by_type"]
        miss_tap = counts.get("miss_tap", 0)
        tap = counts.get("tap", 0)
        voice = counts.get("voice", 0)
        gesture = counts.get("gesture", 0)
        key_press = counts.get("key_press", 0)
        other = u["events_total"] - (miss_tap + tap + voice + gesture + key_press)

        def esc(s):
            if s is None:
                return ""
            t = str(s)
            if "," in t:
                return f"\"{t}\""
            return t

        row = [
            u["user_id"],
            str(u["events_total"]),
            str(miss_tap),
            str(tap),
            str(voice),
            str(gesture),
            str(key_press),
            str(other),
            "" if u["schema_valid_pct"] is None else f"{u['schema_valid_pct']:.2f}",
            "" if u["latency_ms"]["p50"] is None else f"{u['latency_ms']['p50']:.2f}",
            "" if u["latency_ms"]["p90"] is None else f"{u['latency_ms']['p90']:.2f}",
            "" if u["latency_ms"]["max"] is None else f"{u['latency_ms']['max']:.2f}",
            esc(u["top_targets"]),
            esc(u["top_miss_targets"]),
            esc(u["backend_top"]),
            f"{u['classification_pct']['validated_by_validator']:.2f}",
            f"{u['classification_pct']['combined_agent_suggestions']:.2f}",
            f"{u['classification_pct']['mock_rule_fallback']:.2f}",
        ]
        rows.append(",".join(row))

    Path(args.output_csv).write_text("\n".join(rows))

if __name__ == "__main__":
    main()