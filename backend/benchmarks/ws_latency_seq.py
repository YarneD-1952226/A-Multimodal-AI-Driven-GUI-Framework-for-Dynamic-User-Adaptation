#!/usr/bin/env python3

"""
Sequential WebSocket latency benchmark for /ws/adapt.

Usage:
  python ws_latency_seq.py --ws ws://localhost:8000/ws/adapt --user user_seq --n 6 --pause 5

Outputs:
  - ws_latency_seq.csv  (i, latency_ms, event_type)
"""
import argparse, json, time, csv
from datetime import datetime
from websockets.sync.client import connect

def make_event(user_id: str, i: int):
    # Deterministic cycling to keep runs comparable across configs
    kinds = ["tap", "miss_tap", "voice", "gesture"]
    ev_type = kinds[i % len(kinds)]
    meta = {}
    source = "touch"
    if ev_type == "voice":
        meta = {"command": "play"}
        source = "voice"
    elif ev_type == "gesture":
        meta = {"gesture_type": "point"}
        source = "gesture"
    return {
        "event_type": ev_type,
        "source": source,
        "timestamp": datetime.utcnow().isoformat() + "Z",
        "user_id": user_id,
        "target_element": "button_play",
        "coordinates": {"x": 100, "y": 200},
        "confidence": 0.95,
        "metadata": meta
    }

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--ws", default="ws://localhost:8000/ws/adapt")
    ap.add_argument("--user", default="user_seq")
    ap.add_argument("--n", type=int, default=6)
    ap.add_argument("--pause", type=float, default=5)
    args = ap.parse_args()

    rows = []
    with connect(args.ws) as ws:
        for i in range(args.n):
            ev = make_event(args.user, i)
            t0 = time.perf_counter()
            ws.send(json.dumps(ev))
            _ = ws.recv()
            dt = (time.perf_counter() - t0) * 1000.0
            rows.append({"i": i, "latency_ms": f"{dt:.2f}", "event_type": ev["event_type"]})
            if args.pause > 0:
                time.sleep(args.pause)

    out = "ws_latency_seq.csv"
    with open(out, "w", newline="") as f:
        w = csv.DictWriter(f, fieldnames=["i","latency_ms","event_type"])
        w.writeheader()
        w.writerows(rows)
    print(f"Wrote {out} with {len(rows)} rows")

if __name__ == "__main__":
    main()
