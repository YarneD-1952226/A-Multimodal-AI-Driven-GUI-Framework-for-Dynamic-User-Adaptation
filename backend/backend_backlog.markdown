# Project Backlog for AI-Driven GUI Framework Demo

This backlog documents all implementation and testing steps completed for the **AI Backend Logic** and **Flutter Debug App** to demonstrate **Smart Intent Fusion** for the thesis demo on July 31, 2025. The focus is on a FastAPI backend with WebSocket, simulated LLM reasoning (to be replaced with Gemini API), and a Flutter app for sending events and displaying user-friendly adaptations.

## Day 1: July 29, 2025

### Step 1: Initial Backend Implementation
- **Objective**: Create a FastAPI backend with WebSocket for real-time event processing, in-memory user profiles, and simulated **Smart Intent Fusion**.
- **Implementation**:
  - Developed `backend.py` with:
    - WebSocket endpoint (`/ws/adapt`) for real-time event processing.
    - HTTP endpoint (`/context`) for event submission.
    - In-memory storage for user profiles and interaction history (skipped MongoDB for simplicity).
    - `smart_intent_fusion` function simulating LLM reasoning with rules for adaptations (e.g., `increase_size` for miss-tap, `switch_mode` for motor-impaired users).
    - Logging to `adaptation_log.jsonl`.
    - JSON contract-compliant `Event` model for multimodal inputs (touch, voice, gesture).
  - Added creative adaptations:
    - Miss-tap + motor impairment → `switch_mode` to voice.
    - Voice + tap fusion → `trigger_button` + `increase_size`.
    - Gesture + voice → `trigger_button` + `increase_contrast`.
    - Heatmap simulation → `reposition_element` for frequent targets.
    - Hands-free users → `simplify_layout`.
  - Artifact: `backend.py` (artifact_id: `6d072a65-d673-4ff5-809e-cb257902db21`).
- **Testing**:
  - Installed dependencies: `pip install fastapi uvicorn`.
  - Ran backend: `uvicorn backend:app --reload`.
  - Tested HTTP endpoint with curl:
    ```bash
    curl -X POST http://localhost:8000/context -H "Content-Type: application/json" -d '{"event_type": "miss_tap", "source": "touch", "timestamp": "2025-07-29T21:06:00Z", "user_id": "user_123", "target_element": "button_play"}'
    ```
    Expected: `{"adaptations": [{"action": "increase_size", "target": "button_play", "value": 1.5, "reason": "Miss-tap detected on button_play"}]}`
  - Tested WebSocket with `wscat`:
    ```bash
    wscat -c ws://localhost:8000/ws/adapt
    ```
    Sent: `{"event_type": "voice", "source": "voice", "timestamp": "2025-07-29T21:06:00Z", "user_id": "user_123", "metadata": {"command": "play"}}`
    Expected: `{"adaptations": [{"action": "trigger_button", "target": "button_play", "reason": "Voice command 'play' detected"}, {"action": "simplify_layout", "target": "card_list", "value": "reduced", "reason": "Hands-free user detected, simplifying card list layout"}]}`
  - Verified `adaptation_log.jsonl` logs.

### Step 2: Plan for LLM Integration
- **Objective**: Prepare for Gemini API integration on July 30, 2025.
- **Implementation**:
  - Planned to replace `smart_intent_fusion` with Gemini API call using `requests`.
  - Drafted prompt: “Analyze event: {event}, profile: {profile}, history: {history[-10:]}; suggest adaptations.”
  - Kept mock logic as fallback if API setup fails.
- **Testing**: Not applicable (planned for next day).

## Day 2: July 30, 2025

### Step 3: Backend Update with LLM Integration
- **Objective**: Integrate Gemini API into `smart_intent_fusion` for real LLM reasoning.
- **Implementation**:
  - Updated `backend.py` to use `requests` for Gemini API (`https://api.gemini.ai/v1/chat/completions`).
  - Added environment variable `GEMINI_API_KEY` for authentication.
  - Crafted prompt for LLM to fuse event, profile, and history, returning JSON adaptations.
  - Kept mock logic as fallback.
  - Artifact: Updated `backend.py` (artifact_id: `6d072a65-d673-4ff5-809e-cb257902db21`).
- **Testing**:
  - Installed `requests`: `pip install requests`.
  - Set `GEMINI_API_KEY` environment variable.
  - Tested with curl (same as Step 1) to verify LLM-generated adaptations.
  - Ensured fallback mock responses work if API fails.

### Step 4: Initial Flutter Debug App
- **Objective**: Build a Flutter app to send events to backend and display raw JSON responses.
- **Implementation**:
  - Created `debug_app.dart` with:
    - WebSocket connection to `ws://localhost:8000/ws/adapt`.
    - Button to send a miss-tap event.
    - Text display for raw JSON response.
    - Pre-existing profiles (`Motor Impaired`, `Hands-Free`) and events (`Miss-Tap on Play`, `Voice Play Command`, `Gesture Point`) in dropdowns.
    - Text fields for manual JSON input of profiles and events.
    - History log of events and responses.
  - Used `web_socket_channel` package for WebSocket communication.
  - Artifact: `debug_app.dart` (artifact_id: `20ae1429-e970-4363-b16c-45f331a5b427`).
- **Testing**:
  - Installed dependency: `flutter pub add web_socket_channel`.
  - Ran backend: `uvicorn backend:app --reload`.
  - Ran app: `flutter run`.
  - Tested sending pre-existing event (e.g., `Miss-Tap on Play`) and verified raw JSON response (e.g., `[{"action": "increase_size", ...}]`).

### Step 5: Enhanced Flutter Debug App with User-Friendly Output
- **Objective**: Improve app to display adaptations in human-readable format with visual explainability.
- **Implementation**:
  - Updated `debug_app.dart` to:
    - Parse JSON adaptations into natural language (e.g., `{"action": "increase_size", "target": "button_play", "value": 1.5}` → "Enlarge Play button by 1.5x because: Miss-tap detected").
    - Display each adaptation in a `Card` with an icon (e.g., `Icons.zoom_out_map` for `increase_size`).
    - Add a visual flow diagram (icons: User Profile → Event Input → LLM Fusion → Adaptations).
    - Include loading indicator (`CircularProgressIndicator`) during backend response.
    - Retain pre-existing profiles/events and history log.
  - Artifact: Updated `debug_app.dart` (artifact_id: `20ae1429-e970-4363-b16c-45f331a5b427`).
- **Testing**:
  - Ran app: `flutter run`.
  - Tested sending events (e.g., `Voice Play Command`) and verified readable output (e.g., "Trigger Play button because: Voice command 'play' detected" in a card).
  - Confirmed visual flow diagram displays correctly.
  - Checked history log and `adaptation_log.jsonl` for consistency.

## Planned for Demo Day: July 31, 2025
- **Objective**: Finalize demo with video and metrics.
- **Implementation**:
  - Record 1-2 min video showing:
    - Sending multimodal events (e.g., miss-tap, voice mock) via Flutter app.
    - Displaying user-friendly adaptations (e.g., "Enlarge Play button by 1.5x").
    - Visual flow diagram for backend explainability.
  - Log metrics from `adaptation_log.jsonl`:
    - Adaptation accuracy (e.g., correct button trigger).
    - Latency (time from event to response).
  - Test with 2-3 simulated users (e.g., motor-impaired, hands-free).
- **Testing**:
  - Verify Gemini API responses for complex scenarios (e.g., voice + miss-tap).
  - Use mock fallback if API fails.
  - Ensure video captures **Smart Intent Fusion** (e.g., voice + gesture → trigger + contrast).

## Notes for Thesis
- **Novelty**: Highlight **Smart Intent Fusion** combining multimodal inputs (touch, voice, gesture) with LLM reasoning for accessibility-focused adaptations.
- **Explainability**: Emphasize user-friendly output (cards, icons, flow diagram) to make backend process clear to non-technical audience.
- **Metrics**: Use logs for adaptation accuracy, latency, and user profile updates in evaluation.
- **Future Work**: Note Gemini API as a step toward specialized UI-adapting AI models.

## July 31, 2025

1.  Update FastAPI backend: Add /profile endpoint for POST/PUT to receive and update profiles by user\_id.
2.  Integrate MongoDB (or Redis): Store profiles keyed by user\_id; use pymongo for persistence, optional in-memory cache.
3.  Modify event endpoints (/ws/adapt, /context): Extract user\_id from event, load profile/history from DB on demand.
4.  Append events: On event receipt, async update history array in profile doc (use $push, cap with slicing for N entries).
5.  Fuse data: In smart\_intent\_fusion, pass loaded profile, history, and current event to LLM.
6.  Async processing: Use FastAPI's BackgroundTasks for non-blocking DB updates.
7.  Indexing: Add MongoDB index on user\_id for fast queries.
8.  Logging: Persist events/adaptations to separate collection or adaptation\_log.jsonl.
9.  Edge case mitigation: Client waits for /profile success response before sending events; server uses MongoDB transactions for atomic updates.

