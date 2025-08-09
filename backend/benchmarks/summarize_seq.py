#!/usr/bin/env python3

"""
Summarize sequential benchmarks into a compact JSON + optional LaTeX tables.

Assumes you ran:
  - ws_latency_seq.py           -> ws_latency_seq.csv
  - run_event_suite_seq.py      -> event_suite_seq.csv

Usage:
  python summarize_seq.py

Outputs:
  - seq_summary.json
  - (optional) latex tables printed to stdout if --latex is passed
"""
import csv, json, statistics as stats, argparse, os

def load_ws(path="ws_latency_seq.csv"):
    vals = []
    if os.path.exists(path):
        with open(path, "r") as f:
            r = csv.DictReader(f)
            for row in r:
                try:
                    vals.append(float(row["latency_ms"]))
                except:
                    pass
    return vals

def load_suite(path="event_suite_seq.csv"):
    rows = []
    if os.path.exists(path):
        with open(path, "r") as f:
            r = csv.DictReader(f)
            for row in r:
                rows.append(row)
    return rows

def pctl(xs, p):
    if not xs:
        return None
    xs2 = sorted(xs)
    idx = int(round((p/100.0) * (len(xs2)-1)))
    return xs2[idx]

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--latex", action="store_true")
    args = ap.parse_args()

    ws_vals = load_ws()
    suite = load_suite()

    # WS stats
    ws_p50 = round(stats.median(ws_vals), 2) if ws_vals else None
    ws_p90 = round(pctl(ws_vals, 90), 2) if ws_vals else None
    ws_max = round(max(ws_vals), 2) if ws_vals else None

    # Suite stats
    latencies = [float(r["latency_ms"]) for r in suite] if suite else []
    cls_counts = {}
    schema_valid = 0
    for r in suite:
        cls = r["classification"]
        cls_counts[cls] = cls_counts.get(cls, 0) + 1
        schema_valid += 1 if r.get("schema_valid") in ("1", 1) else 0

    total = len(suite)
    validated_pct = round(100.0 * cls_counts.get("validated_by_validator", 0) / total, 2) if total else None
    combined_pct  = round(100.0 * cls_counts.get("combined_agent_suggestions", 0) / total, 2) if total else None
    mock_pct      = round(100.0 * cls_counts.get("mock_rule_fallback", 0) / total, 2) if total else None
    schema_pct    = round(100.0 * (schema_valid / total), 2) if total else None

    summary = {
        "ws_latency_ms": {"p50": ws_p50, "p90": ws_p90, "max": ws_max},
        "event_suite": {
            "n": total,
            "latency_ms": {
                "p50": round(stats.median(latencies), 2) if latencies else None,
                "p90": round(pctl(latencies, 90), 2) if latencies else None,
                "max": round(max(latencies), 2) if latencies else None
            },
            "classification_pct": {
                "validated_by_validator": validated_pct,
                "combined_agent_suggestions": combined_pct,
                "mock_rule_fallback": mock_pct
            },
            "schema_valid_pct": schema_pct
        }
    }

    with open("seq_summary.json", "w") as f:
        json.dump(summary, f, indent=2)
    print(json.dumps(summary, indent=2))

    if args.latex:
        # Table 1: WS latency
        print("\n% LaTeX table: WebSocket Latency (Sequential)\n")
        print(r"\begin{tabular}{lccc}")
        print(r"\toprule")
        print(r"Metric & p50 (ms) & p90 (ms) & max (ms) \\")
        print(r"\midrule")
        print(f"WebSocket round-trip & {ws_p50 or '--'} & {ws_p90 or '--'} & {ws_max or '--'} \\\\")
        print(r"\bottomrule")
        print(r"\end{tabular}")

        # Table 2: Event suite
        print("\n% LaTeX table: Event Suite Results (Sequential)\n")
        print(r"\begin{tabular}{lcccc}")
        print(r"\toprule")
        print(r"N & Validated (\%) & Combined (\%) & Mock (\%) & Schema Pass (\%) \\")
        print(r"\midrule")
        print(f"{total or 0} & {validated_pct or 0} & {combined_pct or 0} & {mock_pct or 0} & {schema_pct or 0} \\\\")
        print(r"\bottomrule")
        print(r"\end{tabular}")

if __name__ == "__main__":
    main()
