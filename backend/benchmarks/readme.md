# SIF Sequential Benchmark Kit

This kit is tailored for a **sequential** FastAPI/WebSocket backend. It sends events **one by one**, classifies responses, and measures round-trip latency.

## Files

- `ws_latency_seq.py` — Measures WebSocket round-trip latency for a deterministic event mix.
- `run_event_suite_seq.py` — Sends a deterministic suite and classifies each response as:
  - `validated_by_validator` — final validator-accepted output
  - `combined_agent_suggestions` — validator failed; combined agent suggestions used
  - `mock_rule_fallback` — all agents failed; rule-based mock used
- `adaptation_schema.json` — JSON schema for the `adaptations` structure.
- `summarize_seq.py` — Aggregates results into `seq_summary.json` and can emit LaTeX tables.

## How to use

1. Start the backend (`sh start_backend_processes.sh`).
2. Run the latency benchmark:
   ```bash
   python ws_latency_seq.py --ws ws://localhost:8000/ws/adapt --user user_seq --n 6 --pause 1
3. Run the event suite:
    ```bash
    python run_event_suite_seq.py --ws ws://localhost:8000/ws/adapt --user user_seq --rounds 10
4. Summarize:
    ```bash
    python summarize_seq.py
## Comparing validator configurations
To compare SIF vs. MA-SIF settings (e.g., validator thinking_budget/model/timeout):
- Run the above sequence once with your default sif_config.json.
- Tweak the validator (e.g., higher thinking_budget, switch to gemini-2.5-flash), restart the backend, and run again.
- Keep the same --user to preserve a realistic profile/history.

Then compare the `seq_summary.json` files.

## Notes
- Classification is heuristic-based:
    * If any adaptation contains key agent → combined_agent_suggestions.
    * Else if any reason matches the mock-fusion strings in your backend → mock_rule_fallback.
    * Else → validated_by_validator.
- Schema validation is done per-response using `adaptation_schema.json`.
