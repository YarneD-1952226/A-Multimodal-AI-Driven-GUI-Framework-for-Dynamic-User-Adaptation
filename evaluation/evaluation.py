import json, time, uuid, datetime as dt
import requests
from websockets.sync.client import connect
from jsonschema import validate, ValidationError

BACKEND_HTTP = "http://localhost:8000"
BACKEND_WS   = "ws://localhost:8000/ws/adapt"

# --- Adaptations schema (strict: action/target/reason/intent + value|mode) ---
ADAPTATIONS_SCHEMA = {
                "type": "object",
                "properties": {
                "adaptations": {
                    "type": "array",
                    "items": {
                    "type": "object",
                    "properties": {
                        "action": {
                        "type": "string",
                        "description": "The type of UI adaptation to perform",
                        },
                        "target": {
                        "type": "string",
                        "description": "The UI element or component to apply the adaptation to, 'all' is also an option, if targeting all elements",
                        },
                        "value": {
                        "type": "number",
                        "description": "Numeric multiplier for size changes (e.g., 1.5 for 50% larger)"
                        },
                        "mode": {
                        "type": "string",
                        "description": "Interaction mode or visual mode to switch to (e.g., 'voice', 'gesture', 'high' for contrast)",
                        },
                        "reason": {
                        "type": "string",
                        "description": "Human-readable explanation of why this adaptation was suggested based on the user event and context"
                        },
                        "intent": {
                        "type": "string",
                        "description": "The inferred user intent, what did you think the user's intent was based on the user input event?"
                        },
                    },
                    "required": ["action", "target", "reason", "intent"],
                    "oneOf": [
                        {"required": ["value"]},
                        {"required": ["mode"]}
                    ]
                    }
                }
                },
                "required": ["adaptations"]
            }

# --- Profiles you’ll iterate (replace with your six from the plan) ---
PROFILES = [
  {"user_id":"P0","accessibility_needs":{},"input_preferences":{},"ui_preferences":{"font_size":16,"contrast_mode":"normal","button_size":1.0}},
  {"user_id":"P1","accessibility_needs":{"motor_impaired":True},"input_preferences":{"preferred_modality":"keyboard"},"ui_preferences":{"button_size":1.0}},
  {"user_id":"P2","accessibility_needs":{"visual_impaired":True},"input_preferences":{},"ui_preferences":{"font_size":18,"contrast_mode":"normal"}},
  {"user_id":"P3","accessibility_needs":{"hands_free_preferred":True},"input_preferences":{"preferred_modality":"voice"},"ui_preferences":{}},
  {"user_id":"P4","accessibility_needs":{"motor_impaired":True,"hands_free_preferred":True},"input_preferences":{"preferred_modality":"voice"},"ui_preferences":{"button_size":1.2}},
  {"user_id":"P5","accessibility_needs":{"visual_impaired":True,"motor_impaired":True},"input_preferences":{"preferred_modality":"voice"},"ui_preferences":{"font_size":18,"contrast_mode":"normal","button_size":1.2}},
]

# --- Deterministic event script (repeat per profile) ---
def event_script(user_id):
  iso = lambda: dt.datetime.utcnow().isoformat() + "Z"
  return [
    {"event_type":"miss_tap","source":"touch","timestamp":iso(),"user_id":user_id,"target_element":"lamp","coordinates":{"x":101,"y":203}, "metadata":{"UI_element": "button"}},
    {"event_type":"voice","source":"voice","target_element":"lamp","timestamp":iso(),"user_id":user_id,"confidence":0.9,"metadata":{"command":"turn_on", "UI_element": "button"}},
    {"event_type":"gesture","source":"gesture","timestamp":iso(),"user_id":user_id,"target_element":"lamp","metadata":{"gesture_type":"point", "UI_element": "button"}},
    {"event_type":"slider_miss","source":"touch","timestamp":iso(),"user_id":user_id,"target_element":"thermostat","metadata":{"overshoot":True, "UI_element": "slider"}},
    {"event_type":"miss_tap","source":"touch","timestamp":iso(),"user_id":user_id,"target_element":"lock","coordinates":{"x":98,"y":200}, "metadata":{"UI_element": "button"}},
    {"event_type":"voice","source":"voice","target_element":"lock","timestamp":iso(),"confidence":0.9,"user_id":user_id,"metadata":{"command":"unlock", "UI_element": "button"}},
    {"event_type":"voice","source":"voice","target_element":"thermostat","timestamp":iso(),"confidence":0.9,"user_id":user_id,"metadata":{"command":"adjust", "UI_element": "slider"}},
  ]

def classify_response(resp_json):
  # Best-effort classification; adjust if your backend tags responses.
  try:
    validate(resp_json, ADAPTATIONS_SCHEMA)
    schema_valid = True
  except ValidationError:
    schema_valid = False

  cls = "validated_by_validator"
  ad = resp_json.get("adaptations", [])
  # Heuristics:
  if any("agent" in a for a in ad):
    cls = "combined_agent_suggestions"  # validator likely failed and raw agent outputs were returned
  # crude mock fallback cue:
  if ad and any("Miss-tap detected" in (a.get("reason","")) for a in ad) and not any("validator" in a.get("agent","") for a in ad):
    # this string mirrors common mock reasons; customize for your mock_fusion text
    cls = "mock_rule_fallback" if not schema_valid else cls
  return schema_valid, cls

def post_profile(p):
  r = requests.post(f"{BACKEND_HTTP}/profile", json=p, timeout=10)
  r.raise_for_status()
  return r.json()

def run_profile(p, runs=2, jsonl_path="feasibility_log.jsonl"):
  # Create/update profile
  meta = post_profile(p)
  print(f"[{p['user_id']}] profile status:", meta.get("status","ok"))

  ws = connect(BACKEND_WS)
  with open(jsonl_path,"a") as f:
    for r in range(1, runs+1):
      for idx, ev in enumerate(event_script(p["user_id"]), start=1):
        send_ts = time.perf_counter()
        send_iso = dt.datetime.utcnow().isoformat()+"Z"
        ws.send(json.dumps(ev))
        raw = ws.recv()
        recv_ts = time.perf_counter()
        recv_iso = dt.datetime.utcnow().isoformat()+"Z"
        latency_ms = round((recv_ts - send_ts)*1000, 2)

        try:
          resp = json.loads(raw)
        except Exception as e:
          resp = {"parse_error": str(e), "raw": raw}

        schema_valid, classification = (False, "unknown")
        if isinstance(resp, dict):
          schema_valid, classification = classify_response(resp)

        row = {
          "run_id": str(uuid.uuid4()),
          "profile_id": p["user_id"],
          "run_index": r,
          "event_index": idx,
          "event": ev,
          "t_send": send_iso,
          "t_recv": recv_iso,
          "latency_ms": latency_ms,
          "response": resp,
          "schema_valid": schema_valid,
          "classification": classification,
          "backend_config": "MA-SIF balanced + instant rules"
        }
        f.write(json.dumps(row) + "\n")
        print(f"[{p['user_id']} r{r} e{idx}] {latency_ms}ms | valid={schema_valid} | {classification}")
  ws.close()

if __name__ == "__main__":
  for p in PROFILES:
    run_profile(p)
