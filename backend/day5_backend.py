from fastapi import FastAPI, WebSocket, Request
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
from typing import Optional, List, Dict
import json
from datetime import datetime
import requests
from google import genai
from google.genai import types

app = FastAPI()
client = genai.Client(api_key="AIzaSyAKbdndI2mZCDufsSbJI2Y3qaIlThoVpds")

# CORS for Flutter/React/SwiftUI frontends
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# In-memory storage for user profiles and history (manual updates for demo)
USER_PROFILES = {
    "user_123": {
        "user_id": "user_123",
        "accessibility_needs": {"motor_impaired": False, "visual_impaired": True, "hands_free_preferred": False},
        "input_preferences": {"preferred_modality": "voice"},
        "ui_preferences": {"font_size": 16, "contrast_mode": "normal", "button_size": 1.0},
        "interaction_history": []
    }
}
ADAPTATION_LOG = []

# Event schema (matches JSON contract)
class Event(BaseModel):
    event_type: str
    source: str
    timestamp: str
    user_id: str
    target_element: Optional[str] = None
    coordinates: Optional[Dict] = None
    confidence: Optional[float] = 1.0
    metadata: Optional[Dict] = None

# Mock fusion (fallback for failed API calls)
def mock_fusion(event: Event, profile: Dict, history: List[Dict]) -> List[Dict]:
    adaptations = []
    if event.event_type == "miss_tap" and event.target_element:
        adaptations.append({
            "action": "increase_size",
            "target": event.target_element,
            "value": 1.5,
            "reason": f"Miss-tap detected on {event.target_element}"
        })
    if event.event_type == "scroll_miss":
        adaptations.append({
            "action": "adjust_scroll_speed",
            "target": "scrollview",
            "value": 0.015,
            "reason": "Scroll miss detected, slowing scroll speed"
        })
    miss_tap_count = sum(1 for h in history[-10:] if h.get("event_type") == "miss_tap")
    if profile.get("accessibility_needs", {}).get("motor_impaired") and miss_tap_count >= 2:
        adaptations.append({
            "action": "switch_mode",
            "mode": "voice",
            "reason": f"User with motor impairment has {miss_tap_count} miss-taps in recent history"
        })
    if event.event_type == "voice" and event.metadata.get("command") == "play":
        adaptations.append({
            "action": "trigger_button",
            "target": "button_play",
            "reason": "Voice command 'play' detected"
        })
        if any(h.get("event_type") == "miss_tap" for h in history[-5:]):
            adaptations.append({
                "action": "increase_size",
                "target": "button_play",
                "value": 1.8,
                "reason": "Voice 'play' with recent miss-tap, enlarging button"
            })
    if event.event_type == "gesture" and event.metadata.get("gesture_type") == "point" and any(
        h.get("event_type") == "voice" and h.get("metadata", {}).get("command") == "info" for h in history[-3:]
    ):
        adaptations.append({
            "action": "trigger_button",
            "target": "button_info",
            "reason": "Point gesture combined with recent voice 'info' command"
        })
        adaptations.append({
            "action": "increase_contrast",
            "target": "button_info",
            "mode": "high",
            "reason": "Enhancing visibility for pointed info button"
        })
    target_counts = {}
    for h in history:
        target = h.get("target_element")
        if target:
            target_counts[target] = target_counts.get(target, 0) + 1
    if event.target_element and target_counts.get(event.target_element, 0) > 3:
        adaptations.append({
            "action": "reposition_element",
            "target": event.target_element,
            "offset": {"x": 30, "y": -10},
            "reason": f"Frequent interactions ({target_counts[event.target_element]}) with {event.target_element}"
        })
    if profile.get("accessibility_needs", {}).get("hands_free_preferred") and event.source in ["voice", "gesture"]:
        adaptations.append({
            "action": "simplify_layout",
            "target": "card_list",
            "value": "reduced",
            "reason": "Hands-free user detected, simplifying card list layout"
        })
    return adaptations

# Smart Intent Fusion (Gemini LLM integration for reasoning and intent inference)
def smart_intent_fusion(event: Event, profile: Dict, history: List[Dict]) -> List[Dict]:
    prompt = f"""
    Analyze this user event: {json.dumps(event.dict())}
    User profile: {json.dumps(profile)}
    Recent history (last 10 events): {json.dumps(history[-10:])}
    Suggest UI adaptations as JSON.
    Focus on accessibility and multimodal fusion (e.g., voice + miss_tap → enlarge + trigger). 
    Ensure actions are in ["increase_size", "reposition_element", "increase_contrast", "adjust_scroll_speed", "switch_mode", "trigger_button", "simplify_layout"].
    """
    # Call Gemini API for intent fusion
    try:
        response = client.models.generate_content(
            model="gemini-2.5-flash", 
            contents=prompt,
            config=types.GenerateContentConfig(
                response_mime_type="application/json",
                response_json_schema={ #TODO: Create a pydantic model for this schema -> send to frontend?
                    "type": "object",
                    "properties": {
                        "adaptations": {
                            "type": "array",
                            "items": {
                                "type": "object",
                                "properties": {
                                    "action": {"type": "string"},
                                    "target": {"type": "string"},
                                    "value": {"type": ["number", "string"], "nullable": True},
                                    "mode": {"type": "string", "nullable": True},
                                    "reason": {"type": "string"}
                                },
                                "required": ["action", "target", "reason"]
                            }
                        }
                    },
                    "required": ["adaptations"]
                },
                thinking_config=types.ThinkingConfig(thinking_budget=0),  # Disables thinking
                system_instruction="You are an expert in multimodal AI-driven GUI adaptation. Analyze user events and suggest UI adaptations based on accessibility needs and interaction history.",
            ),
        )
        print(response.text)
        return json.loads(response.text)["adaptations"]
    except Exception as e:
        print(f"Gemini API error: {e}, using mock")
        return mock_fusion(event, profile, history)

# Update user profile and history
async def update_user_profile(event: Event):
    profile = USER_PROFILES.get(event.user_id, {
        "user_id": event.user_id,
        "accessibility_needs": {"motor_impaired": False, "visual_impaired": False, "hands_free_preferred": False},
        "input_preferences": {"preferred_modality": "touch"},
        "ui_preferences": {"font_size": 16, "contrast_mode": "normal", "button_size": 1.0},
        "interaction_history": []
    })
    profile["interaction_history"].append(event.dict(exclude_none=True))
    USER_PROFILES[event.user_id] = profile

# Log adaptation
async def log_adaptation(event: Event, adaptations: List[Dict]):
    log_entry = {
        "timestamp": datetime.utcnow().isoformat(),
        "context": event.dict(exclude_none=True),
        "adaptations": adaptations
    }
    ADAPTATION_LOG.append(log_entry)
    with open("adaptation_log.jsonl", "a") as f:
        f.write(json.dumps(log_entry) + "\n")

# HTTP endpoint for context processing
@app.post("/context")
async def process_event(event: Event):
    await update_user_profile(event)
    profile = USER_PROFILES.get(event.user_id, {})
    adaptations = smart_intent_fusion(event, profile, profile.get("interaction_history", []))
    await log_adaptation(event, adaptations)
    return {"adaptations": adaptations}

# WebSocket endpoint for real-time adaptations
@app.websocket("/ws/adapt")
async def websocket_adapt(websocket: WebSocket):
    await websocket.accept()
    try:
        while True:
            data = await websocket.receive_json()
            event = Event(**data)
            await update_user_profile(event)
            profile = USER_PROFILES.get(event.user_id, {})
            adaptations = smart_intent_fusion(event, profile, profile.get("interaction_history", []))
            await log_adaptation(event, adaptations)
            await websocket.send_json({"adaptations": adaptations})
    except Exception as e:
        print(f"WebSocket error: {e}")
    finally:
        await websocket.close()

# Profile management endpoint (manual updates for demo)
@app.get("/profile/{user_id}")
async def get_profile(user_id: str):
    return USER_PROFILES.get(user_id, {"error": "Profile not found"})

@app.post("/profile")
async def update_profile(profile: Dict):
    USER_PROFILES[profile["user_id"]] = profile
    return {"status": "Profile updated"}

# Modalities configuration endpoint
@app.get("/modalities")
async def get_modalities():
    return {
        "modalities": ["touch", "keyboard", "voice", "gesture"],
        "status": "Active"
    }