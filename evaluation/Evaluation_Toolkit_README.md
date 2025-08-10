# Feasibility/Evaluation Toolkit 

A minimal pipeline to:
1) generate feasibility logs by driving the backend with predefined profiles/events, and
2) aggregate those logs into per-user summaries for Chapter 6.

No pandas/matplotlib required.

---

## TL;DR (3 commands)

```bash
# 1) Create venv (optional) and install deps
python3 -m venv .venv && source .venv/bin/activate
python -m pip install requests websockets jsonschema

# 2) Generate a feasibility log (requires backend on :8000)
python evaluation.py   # writes feasibility_log.jsonl

# 3) Aggregate one or many JSONL logs into JSON + CSV summaries
python extract_profiles.py \
  --glob "feasibility_log.jsonl" \
  --output-json "chapter6_payload.json" \
```

---

## What each script does

### `evaluation.py` (log generator)
- Posts a small set of demo profiles to `POST /profile`.
- Opens a WebSocket to `/ws/adapt`, sends a deterministic event script per profile, and logs each response line-by-line to `feasibility_log.jsonl`.
- Validates responses against a strict JSON schema (action/target/reason/intent + value|mode) via `jsonschema`.
- Classifies each response as:
  - `validated_by_validator` (schema-valid),
  - `combined_agent_suggestions`, or
  - `mock_rule_fallback` (heuristic).
- Prints per-event latency and basic status to stdout.

Configuration inside the file:
- BACKEND_HTTP = http://localhost:8000
- BACKEND_WS = ws://localhost:8000/ws/adapt
- PROFILES = six example profiles (P0–P5) you can edit
- event_script(user_id) = fixed sequence of 7 events per profile

Run:
```bash
python evaluation.py
# Output: feasibility_log.jsonl
```

### `extract_profiles.py` (log aggregator)
- Reads one or more NDJSON files matched by `--glob` (each line = one event record).
- Aggregates per user and emits:
  - A compact JSON payload (`--output-json`) with:
    - overall metrics (latency percentiles, schema-valid%),
    - per-user summaries (counts by event type, latency p50/p90/max, top targets, classification mix, top actions, last N events, and quick recommendations).
  - A CSV summarizing per-user stats for quick scanning.

CLI:
```bash
python extract_profiles.py \
  --glob "logs/*.jsonl" \
  --output-json "chapter6_payload.json" \
  --keep-last-events 10
```

---

## Dependencies

- Python 3.10+
- `requests`, `websockets`, `jsonschema`
- Backend running locally on port 8000 (FastAPI + WS)

Install:
```bash
python -m pip install requests websockets jsonschema
```

---

## Input expectations (per line in `.jsonl`)

Produced by `evaluation.py`:
```json
{
  "run_id": "e3c76dff-f0bd-48a4-ae54-40fa25f260b6",
  "profile_id": "P0",
  "run_index": 1,
  "event_index": 1,
  "event": {
    "event_type": "miss_tap",
    "source": "touch",
    "timestamp": "2025-08-10T10:27:52.592576Z",
    "user_id": "P0",
    "target_element": "lamp",
    "coordinates": {"x": 101, "y": 203},
    "metadata": {"UI_element": "button"}
  },
  "t_send": "2025-08-10T10:27:52.592760Z",
  "t_recv": "2025-08-10T10:28:13.688209Z",
  "latency_ms": 21095.52,
  "response": {
    "adaptations": [
      {"action":"increase_button_border","intent":"improve_tap_accuracy","reason":"...","target":"lamp","value":1.2},
      {"action":"switch_mode","intent":"switch_to_voice_input","reason":"...","target":"lamp","mode":"voice"}
    ]
  },
  "schema_valid": true,
  "classification": "validated_by_validator",
  "backend_config": "MA-SIF balanced + instant rules"
}
```

---

## Outputs

### From `evaluation.py`
- `feasibility_log.jsonl` — newline-delimited JSON with one record per event.

### From `extract_profiles.py`
- JSON (`chapter6_payload.json` by default): includes:
  - files processed, overall totals,
  - overall latency percentiles (p50/p90/max),
  - overall schema-valid percentage,
  - top actions and backend configs,
  - per-user blocks with:
    - event counts by type,
    - miss_tap rate,
    - latency p50/p90/max,
    - top targets and top miss targets,
    - classification mix,
    - top actions,
    - last N events (configurable via `--keep-last-events`),
    - quick recommendations (e.g., voice-first flow, enlarge buttons).
- CSV (`profile_summary.csv` by default) with header:
```
user_id,events_total,miss_tap,tap,voice,gesture,key_press,other,schema_valid_pct,latency_p50_ms,latency_p90_ms,latency_max_ms,top_targets,top_miss_targets,backend_top,validated_pct,combined_pct,mock_pct
```

---

## Usage in Chapter 6 (Feasibility Study)

- Quote per-user summaries (miss_tap rate, latency p50/p90, top actions).
- Include the JSON payload snippet for 1–2 representative users.
- Discuss the quick recommendations as practical guidance (e.g., “Increase button border on top-miss targets; offer voice-first flow”).

---

## Troubleshooting

- Empty outputs:
  - Check your `--glob` pattern; ensure files exist and contain valid JSON lines.
- `evaluation.py` stalls:
  - Verify backend is running on `:8000` with `/profile` (HTTP) and `/ws/adapt` (WS).
- Low schema-valid%:
  - Your backend responses may not match `ADAPTATIONS_SCHEMA` (missing `value` or