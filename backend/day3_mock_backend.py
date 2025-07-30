from fastapi import FastAPI, Request
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
from typing import Optional

app = FastAPI()

# Allow CORS from your Flutter app localhost for demo purposes
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Event schema (simplified)
class Event(BaseModel):
    event_type: str
    source: str
    timestamp: str
    user_id: str
    target_element: Optional[str] = None
    coordinates: Optional[dict] = None
    confidence: Optional[float] = 1.0
    metadata: Optional[dict] = None

@app.post("/context")
async def process_event(event: Event):
    # Simple rule-based adaptation example
    adaptations = []

    if event.event_type == "miss_tap" and event.target_element:
        adaptations.append({
            "action": "increase_size",
            "target": event.target_element,
            "value": 1.5
        })

    if event.event_type == "scroll_miss":
        adaptations.append({
            "action": "adjust_scroll_speed",
            "target": "scrollview",
            "value": 10
        })

    return {"adaptations": adaptations}