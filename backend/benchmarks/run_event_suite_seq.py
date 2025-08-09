#!/usr/bin/env python3

"""
Sequential event suite runner + classifier.

Sends a deterministic sequence of events to /ws/adapt and classifies the response per-event as:
  - validated_by_validator
  - combined_agent_suggestions (validator failed)
  - mock_rule_fallback (all agents failed, mock_fusion)

It also validates JSON schema per response.

Usage:
  python run_event_suite_seq.py --ws ws://localhost:8000/ws/adapt --user user_seq --rounds 10

Outputs:
  - event_suite_seq.csv with columns:
      idx, event_type, latency_ms, classification, schema_valid
"""
import argparse, json, time, csv
from datetime import datetime
from websockets.sync.client import connect

# Heuristic signatures for mock_fusion reasons (from backend.py)
MOCK_REASONS = [
    "Miss-tap detected, increasing target size",
    "Motor impairment detected, enlarging all elements",
    "Visual impairment detected, increasing contrast",
    "Voice input detected, switching to voice mode"
]

def classify(adaptations):
    """
    Classification rules:
      - If any adaptation has key 'agent' -> combined_agent_suggestions (validator failed)
      - Else if any 'reason' matches the mock fusion signatures -> mock_rule_fallback
      - Else -> validated_by_validator
    """
    if isinstance(adaptations, list):
        for a in adaptations:
            if isinstance(a, dict) and "agent" in a:
                return "combined_agent_suggestions"
        for a in adaptations:
            if isinstance(a, dict):
                reason = a.get("reason","")
                if any(sig in reason for sig in MOCK_REASONS):
                    return "mock_rule_fallback"
    return "validated_by_validator"

def make_event(user_id, i):
    kinds = ["tap", "miss_tap", "voice", "gesture"]
    ev_type = kinds[i % len(kinds)]
    meta, src = {}, "touch"
    if ev_type == "voice":
        meta, src = {"command":"play"}, "voice"
    elif ev_type == "gesture":
        meta, src = {"gesture_type":"point"}, "gesture"
    return {
        "event_type": ev_type,
        "source": src,
        "timestamp": datetime.utcnow().isoformat()+"Z",
        "user_id": user_id,
        "target_element": "button_play",
        "coordinates": {"x": 120, "y": 240},
        "confidence": 0.95,
        "metadata": meta
    }

def validate_schema(payload, schema):
    # very light schema check
    try:
        from jsonschema import validate, ValidationError
        validate(instance={"adaptations": payload}, schema=schema)
        return True
    except Exception:
        return False

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--ws", default="ws://localhost:8000/ws/adapt")
    ap.add_argument("--user", default="user_seq")
    ap.add_argument("--rounds", type=int, default=10)
    ap.add_argument("--pause", type=float, default=5, help="sleep between events (s)")
    ap.add_argument("--schema", default="adaptation_schema.json")
    args = ap.parse_args()

    with open(args.schema, "r") as f:
        schema = json.load(f)

    rows = []
    with connect(args.ws) as ws:
        for i in range(args.rounds):
            ev = make_event(args.user, i)
            t0 = time.perf_counter()
            ws.send(json.dumps(ev))
            raw = ws.recv()
            dt = (time.perf_counter() - t0) * 1000.0
            try:
                resp = json.loads(raw)
                adaps = resp.get("adaptations", [])
            except Exception:
                adaps = []
            cls = classify(adaps)
            valid = validate_schema(adaps, schema)
            rows.append({
                "idx": i,
                "event_type": ev["event_type"],
                "latency_ms": f"{dt:.2f}",
                "classification": cls,
                "schema_valid": 1 if valid else 0
            })
            if args.pause > 0:
                time.sleep(args.pause)

    out = "event_suite_seq.csv"
    with open(out, "w", newline="") as f:
        w = csv.DictWriter(f, fieldnames=["idx","event_type","latency_ms","classification","schema_valid"])
        w.writeheader(); w.writerows(rows)
    print(f"Wrote {out} with {len(rows)} rows")

if __name__ == "__main__":
    main()
