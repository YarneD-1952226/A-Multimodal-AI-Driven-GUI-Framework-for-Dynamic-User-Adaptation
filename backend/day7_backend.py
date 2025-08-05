from fastapi import BackgroundTasks, FastAPI, HTTPException, WebSocket
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
from typing import Optional, List, Dict
import json
from datetime import datetime
from google import genai
from google.genai import types
import pymongo

app = FastAPI()
client = genai.Client(api_key="AIzaSyAKbdndI2mZCDufsSbJI2Y3qaIlThoVpds")

#MongoDB setup
mongo_client = pymongo.MongoClient("mongodb://localhost:27017/")
db = mongo_client["adaptive_ui"]
profiles_collection = db["profiles"]
logs_collection = db["logs"]
profiles_collection.create_index("user_id", unique=True)

# CORS for Flutter/SwiftUI frontends
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

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
    Analyze this user event: {event.model_dump_json()}
    User profile: {json.dumps(profile)}
    Recent history (last 10 events): {json.dumps(history)}
    Suggest UI adaptations as JSON.
    Focus on accessibility and multimodal fusion (e.g., voice + miss_tap → enlarge + trigger). 
    Ensure actions are in ["increase_size", "reposition_element", "increase_contrast", "switch_mode", "trigger_button", "simplify_layout"].
    Switch modes only entails changing the interaction mode, not the UI layout. eg. "switch_mode": "voice" or "switch_mode": "gesture".
    Also ensure that the adaptations are tailored to the user's specific needs and context. Use the given User profile to make drastic UI changes, atleast increase_contrast and simplify_layout.
    """ #TODO: Config file
    # print(f"Prompt for Gemini: {prompt}")
    # Call Gemini API for intent fusion
    try:
        response = client.models.generate_content(
            model="gemini-2.5-flash", 
            contents=prompt,
            config=types.GenerateContentConfig(
            response_mime_type="application/json",
            response_json_schema={
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
                        "type": ["number", "string"],
                        "description": "Numeric multiplier for size/speed changes or string value for layout changes (e.g., 1.5 for 50% larger). it needs to be positive and a decimal with one digit after the dot.",
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
                        }
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
            },
            temperature=0.2,
            thinking_config=types.ThinkingConfig(thinking_budget=0),
            system_instruction="You are an expert in multimodal AI-driven GUI adaptation. Analyze user events and suggest UI adaptations based on accessibility needs and interaction history.",
            ),
        )
        print(response.text)
        return json.loads(response.text)["adaptations"]
    except Exception as e:
        print(f"Gemini API error: {e}, using mock")
        return mock_fusion(event, profile, history)

# Log adaptation
async def log_adaptation(event: Event, adaptations: List[Dict], background_tasks: BackgroundTasks):
    log_entry = {
        "timestamp": datetime.utcnow().isoformat(),
        "context": event.dict(exclude_none=True),
        "adaptations": adaptations
    }
    background_tasks.add_task(logs_collection.insert_one, log_entry)
    # Optional: Keep jsonl
    with open("adaptation_log.jsonl", "a") as f:
        f.write(json.dumps(log_entry) + "\n")

# Update user history
async def append_event(user_id: str, event_data: str):
    profiles_collection.update_one(
        {"user_id": user_id}, 
        {"$push": {"interaction_history": {"$each": [event_data], "$slice": -10}}}
    )

# Load user profile from MongoDB
async def load_profile(user_id: str) -> Dict:
    profile = profiles_collection.find_one({"user_id": user_id}, {'_id': 0})
    return profile

# Atomic update for interaction history (MongoDB transaction)
async def atomic_update(user_id: str, event_data: Dict):
    def callback(session):
        profiles_collection.update_one(
            {"user_id": user_id},
            {"$push": {"interaction_history": {"$each": [event_data], "$slice": -20}}},
            session=session
        )
    mongo_client.with_transaction(callback)



# Process event endpoint
@app.post("/context")
async def process_event(event: Event, background_tasks: BackgroundTasks):
    profile = await load_profile(event.user_id)
    history = profile.get("interaction_history", [])
    adaptations = smart_intent_fusion(event, profile, history)
    await append_event(event.user_id, event.dict(exclude_none=True), background_tasks)
    await log_adaptation(event, adaptations, background_tasks)
    return {"adaptations": adaptations}

# WebSocket endpoint for real-time adaptation
@app.websocket("/ws/adapt")
async def websocket_adapt(websocket: WebSocket, background_tasks: BackgroundTasks):
    await websocket.accept()
    try:
        while True:
            data = await websocket.receive_json()
            event = Event(**data)
            profile = await load_profile(event.user_id) or {
                "user_id": event.user_id,
                "interaction_history": [],
                "accessibility_needs": {},
                "input_preferences": {},
                "ui_preferences": {}
            }
            history = profile.get("interaction_history", [])
            adaptations = smart_intent_fusion(event, profile, history)
            await append_event(event.user_id, event.model_dump_json())
            await log_adaptation(event, adaptations, background_tasks)
            # print(f"Adaptations: {adaptations}")
            await websocket.send_json({"adaptations": adaptations})
    except Exception as e:
        print(f"WebSocket error: {e}")
    finally:
        await websocket.close()

# Profile management endpoint (manual updates for demo)
@app.post("/profile")
async def set_profile(profile: Dict, background_tasks: BackgroundTasks):
    internal_profile = await load_profile(profile.get("user_id"))
    print(f"Internal profile: {internal_profile}")
    if not internal_profile:
        profiles_collection.insert_one(profile)
        print("Profile created")
        return {"status": "Profile created"}
    else:
        print("Profile updated")
        background_tasks.add_task(profiles_collection.update_one, {"user_id": profile.get("user_id")}, {"$set": profile}, upsert=True)
        return {"status": "Profile update queued"}

# Profile retrieval endpoint
@app.get("/profile/{user_id}")
async def get_profile(user_id: str):
    profile = await load_profile(user_id)
    if not profile:
        raise HTTPException(404, "Profile not found")
    return profile

@app.get("/full_history")
async def get_full_history():
    history = list(profiles_collection.find({}, {'_id': 0, 'interaction_history': 1, 'user_id': 1}))
    formatted_history = [{"user_id": doc["user_id"], "interaction_history": doc.get("interaction_history", [])} for doc in history]
    print(f"Full history: {formatted_history}")
    if not history:
        raise HTTPException(404, "No interaction history found")
    return {"history": formatted_history}

# Modalities configuration endpoint
@app.get("/modalities")
async def get_modalities():
    return {
        "modalities": ["touch", "keyboard", "voice", "gesture"],
        "status": "Active"
    }