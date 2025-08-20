#!/usr/bin/env python3
import argparse, json, time, csv
from datetime import datetime
from websockets.sync.client import connect
from websockets.exceptions import ConnectionClosedError

MOCK_REASONS = [
    "Miss-tap detected, increasing target size",
    "Motor impairment detected, enlarging all elements",
    "Visual impairment detected, increasing contrast",
    "Voice input detected, switching to voice mode"
]

def classify(adaptations):
    if isinstance(adaptations, list):
        for a in adaptations:
            if isinstance(a, dict) and "agent" in a:
                return "combined_agent_suggestions"
        for a in adaptations:
            if isinstance(a, dict) and any(sig in a.get("reason","") for sig in MOCK_REASONS):
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
    try:
        from jsonschema import validate
        validate(instance={"adaptations": payload}, schema=schema)
        return True
    except Exception:
        return False

def open_ws(url, args):
    pi = None if args.ping_interval <= 0 else args.ping_interval
    pt = None if args.ping_timeout  <= 0 else args.ping_timeout
    return connect(
        url,
        open_timeout=args.open_timeout,
        close_timeout=args.close_timeout,
        ping_interval=pi,
        ping_timeout=pt,
        max_size=None,   # no cap
    )

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--ws", default="ws://localhost:8000/ws/adapt")
    ap.add_argument("--user", default="user_seq")
    ap.add_argument("--rounds", type=int, default=10)
    ap.add_argument("--pause", type=float, default=5.0, help="sleep between events (s)")
    ap.add_argument("--schema", default="adaptation_schema.json")
    # keepalive / timeouts (set <=0 to disable pings)
    ap.add_argument("--ping-interval", type=float, default=0.0, help="seconds; <=0 disables keepalive pings")
    ap.add_argument("--ping-timeout",  type=float, default=0.0, help="seconds; <=0 disables keepalive timeouts")
    ap.add_argument("--open-timeout",  type=float, default=30.0)
    ap.add_argument("--close-timeout", type=float, default=120.0)
    args = ap.parse_args()

    with open(args.schema, "r") as f:
        schema = json.load(f)

    rows = []
    ws = open_ws(args.ws, args)
    try:
        for i in range(args.rounds):
            ev = make_event(args.user, i)
            while True:
                t0 = time.perf_counter()
                try:
                    ws.send(json.dumps(ev))
                    raw = ws.recv()
                    dt = (time.perf_counter() - t0) * 1000.0
                    break
                except ConnectionClosedError:
                    # reconnect and retry this same event
                    try:
                        ws = open_ws(args.ws, args)
                        time.sleep(0.2)
                        continue
                    except Exception:
                        time.sleep(0.5)
                        continue

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
    finally:
        try:
            ws.close()
        except Exception:
            pass

    out = "event_suite_seq.csv"
    with open(out, "w", newline="") as f:
        w = csv.DictWriter(f, fieldnames=["idx","event_type","latency_ms","classification","schema_valid"])
        w.writeheader(); w.writerows(rows)
    print(f"Wrote {out} with {len(rows)} rows")

if __name__ == "__main__":
    main()
