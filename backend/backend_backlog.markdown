## Project Backlog for AI-Driven GUI Framework Demo

This backlog documents all implementation and testing steps completed for the **AI Backend Logic** and **Flutter Debug App** to demonstrate **Smart Intent Fusion (SIF)** for the thesis demo on August 5, 2025. The focus is on a FastAPI backend with WebSocket, Gemini API for LLM reasoning, MongoDB for profile and history storage, and a Flutter app for sending events and displaying user-friendly adaptations. The goal for August 1, 2025, is to complete a robust implementation with a new frontend, input adapter layer, and backend extensions (hybrid mode, MA-SIF toggle, DB visualizations) to ensure a strong master thesis by the August 11 draft deadline.

### Previously Completed (July 29–31, 2025)

#### Day 1: July 29, 2025

##### Step 1: Initial Backend Implementation
- **Objective**: Create a FastAPI backend with WebSocket for real-time event processing, in-memory user profiles, and simulated **Smart Intent Fusion**.
- **Implementation**:
  - Developed `backend.py` with:
    - WebSocket endpoint (`/ws/adapt`) for real-time event processing.
    - HTTP endpoint (`/context`) for event submission.
    - In-memory storage for user profiles and interaction history (skipped MongoDB initially).
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

##### Step 2: Plan for LLM Integration
- **Objective**: Prepare for Gemini API integration on July 30, 2025.
- **Implementation**:
  - Planned to replace `smart_intent_fusion` with Gemini API call using `requests`.
  - Drafted prompt: “Analyze event: {event}, profile: {profile}, history: {history[-10:]}; suggest adaptations.”
  - Kept mock logic as fallback if API setup fails.
- **Testing**: Not applicable (planned for next day).

#### Day 2: July 30, 2025

##### Step 3: Backend Update with LLM Integration
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

##### Step 4: Initial Flutter Debug App
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

##### Step 5: Enhanced Flutter Debug App with User-Friendly Output
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

#### Day 3: July 31, 2025

##### Step 6: Backend Update with MongoDB and Profile Management
- **Objective**: Integrate MongoDB for persistent profile and history storage, implement dedicated profile endpoints, and handle edge cases.
- **Implementation**:
  - Added `pymongo` for MongoDB integration, connecting to `mongodb://localhost:27017/`.
  - Created `profiles` collection with `user_id` index for fast queries and `logs` collection for adaptation logs.
  - Implemented `POST /profile` to create new profiles, validating `user_id`.
  - Implemented `PUT /profile/{user_id}` for profile updates with async processing via `BackgroundTasks`, supporting upsert for flexibility.
  - Modified `/context` and `/ws/adapt` endpoints to:
    - Load profiles/history from MongoDB using `user_id` on event receipt.
    - Append events to history array (capped at 20 entries) using `$push` and `$slice`.
  - Updated `log_adaptation` to store in MongoDB `logs` collection, retaining `adaptation_log.jsonl` as fallback.
  - Handled edge case (profile update in-flight during event): Client waits for `POST/PUT /profile` success before sending events; server uses MongoDB transactions for atomic updates.
  - Artifact: Updated `backend.py` (artifact_id: `6d072a65-d673-4ff5-809e-cb257902db21`).
- **Testing**:
  - Installed `pymongo`: `pip install pymongo`.
  - Started MongoDB: `mongod`.
  - Ran backend: `uvicorn backend:app --reload`.
  - Tested profile creation:
    ```bash
    curl -X POST http://localhost:8000/profile -H "Content-Type: application/json" -d '{"user_id": "user_123", "accessibility_needs": {"motor_impaired": true}, "input_preferences": {"preferred_modality": "voice"}}'
    ```
    Expected: `{"status": "Profile created", "id": "..."}`
  - Tested profile update:
    ```bash
    curl -X PUT http://localhost:8000/profile/user_123 -H "Content-Type: application/json" -d '{"user_id": "user_123", "accessibility_needs": {"motor_impaired": true}}'
    ```
    Expected: `{"status": "Profile update queued"}`
  - Tested event with WebSocket (`wscat`):
    ```bash
    wscat -c ws://localhost:8000/ws/adapt
    ```
    Sent: `{"event_type": "miss_tap", "source": "touch", "timestamp": "2025-07-31T18:09:00Z", "user_id": "user_123", "target_element": "button_play"}`
    Expected: LLM-generated adaptations (e.g., `[{"action": "increase_size", ...}]`).
  - Verified MongoDB `profiles` and `logs` collections; checked `adaptation_log.jsonl`.

### Day 4: August 1, 2025

#### Step 7: New Frontend App for Real UI
- **Objective**: Create a separate Flutter app (`adaptive_ui_app.dart`) to demonstrate a real UI with dynamic adaptations, distinct from the debug app.
- **Implementation** (Planned):
  - Build a Flutter app with:
    - Scrollable card list and Play/Info buttons (art explorer theme).
    - WebSocket integration (`web_socket_channel`) to send events (tap, miss-tap, mock voice/gestures) to `/ws/adapt`.
    - HTTP client (`http` package) to manage profiles via `POST/PUT/GET /profile`.
    - Dynamic application of adaptations (e.g., `AnimatedScale` for `increase_size`, color changes for `increase_contrast`).
    - Profile existence check via `GET /profile/{user_id}` before sending events.
  - Why separate? Debug app focuses on backend diagnostics; new app shows real UI adaptations for demo impact.
- **Testing** (Planned):
  - Install `http`: `flutter pub add http`.
  - Run backend: `uvicorn backend:app --reload` and MongoDB: `mongod`.
  - Run app: `flutter run`.
  - Test: Send tap event, verify button enlarges; send voice mock, verify trigger; check profile updates via HTTP.

#### Step 8: Input Adapter Layer as Template
- **Objective**: Implement a middleware layer in the new Flutter app to standardize events into JSON contract format.
- **Implementation** (Planned):
  - Create `AdaptiveUI` class in Flutter to:
    - Handle inputs: Tap (`GestureDetector`), keyboard (`RawKeyboardListener`), mock voice/gestures.
    - Convert to JSON contract: `{event_type, source, timestamp, user_id, target_element, coordinates, metadata}`.
    - Send via WebSocket (`/ws/adapt`) or HTTP (`/context`).
    - Check profile existence (`GET /profile/{user_id}`) before events, prompt `POST /profile` if missing.
  - Design as reusable template for future platforms (React, SwiftUI).
- **Testing** (Planned):
  - Test event standardization: Send tap, verify JSON format.
  - Test profile check: Ensure app waits for `POST /profile` success.
  - Verify events reach backend and adaptations apply.

#### Step 9: Backend Extensions
- **Objective**: Add hybrid mode, Multi-Agent SIF (MA-SIF) toggle, and DB visualization/clear endpoints.
- **Implementation** (Planned):
  - **Hybrid Mode**:
    - Add `hybrid_mode` flag in `smart_intent_fusion` to merge rule-based (e.g., `if miss_tap then increase_size`) and Gemini LLM suggestions.
    - Prioritize rules for deterministic cases, append LLM for creative adaptations.
  - **MA-SIF Toggle**:
    - Implement `ma_sif_reasoning` function with three agents: Intent Inference (IIA), Adaptation Proposal (APA), Validation and Refinement (VRA).
    - Use prompt chaining (2-3 iterations) to reduce hallucinations.
    - Add `use_ma_sif` query param in `/ws/adapt` and `/context` or store in profile.
    - Return agent traces in logs for explainability.
  - **DB Visualizations and Management**:
    - Add `/db/profiles` (GET) to list all profiles.
    - Add `/db/logs` (GET) to list adaptation logs.
    - Add `/db/clear` (DELETE) to drop collections.
    - Add `/db/delete/{user_id}` (DELETE) to remove specific profiles.
  - Artifact: Updated `backend.py` (artifact_id: `6d072a65-d673-4ff5-809e-cb257902db21`).
- **Testing** (Planned):
  - Test hybrid mode: Send miss-tap, verify rule-based + LLM adaptations.
  - Test MA-SIF toggle: Compare SIF vs. MA-SIF outputs for same event.
  - Test DB endpoints: Verify profile/log retrieval, clear/delete functionality.
  - Check MongoDB collections and `adaptation_log.jsonl`.

#### Step 10: Debug App Extensions
- **Objective**: Update debug app to support MA-SIF toggle and DB visualizations.
- **Implementation** (Planned):
  - Add checkbox in `debug_app.dart` to toggle `use_ma_sif` (send as query param or profile update).
  - Add “DB View” tab with tables for profiles (`/db/profiles`) and logs (`/db/logs`).
  - Add “Clear DB” and “Delete Profile” buttons calling `/db/clear` and `/db/delete/{user_id}`.
  - Display MA-SIF vs. SIF differences (e.g., side-by-side adaptations).
  - Artifact: Updated `debug_app.dart` (artifact_id: `20ae1429-e970-4363-b16c-45f331a5b427`).
- **Testing** (Planned):
  - Run app: `flutter run`.
  - Test MA-SIF toggle: Verify different outputs for same event.
  - Test DB view: Confirm profiles/logs display as tables; test clear/delete actions.
  - Verify history log consistency with backend.

## Planned for Next Week (August 4–10, 2025)
- **Objective**: Polish implementation for August 5 demo and August 11 draft deadline.
- **Implementation**:
  - Refine UI animations in `adaptive_ui_app.dart` (e.g., smoother button scaling).
  - Record 1-2 min demo video showing:
    - Multimodal events (tap, voice mock) in new app with visual adaptations.
    - Debug app showing MA-SIF vs. SIF, DB views, and explainability (flow diagram).
  - Finalize metrics from MongoDB logs and `adaptation_log.jsonl`:
    - Adaptation accuracy (precision/recall vs. ground truth).
    - Latency (event to response time).
    - User satisfaction (simulated SUS scores).
  - Conduct user study with 2-3 simulated users (motor-impaired, hands-free).
- **Testing**:
  - Verify Gemini API stability for complex scenarios (voice + miss-tap).
  - Test MA-SIF reliability vs. SIF (fewer hallucinations).
  - Ensure video captures **Smart Intent Fusion** novelty.

## Notes for Thesis
- **Novelty**: Highlight **Smart Intent Fusion** with Gemini LLM for multimodal accessibility adaptations; MA-SIF as a novel anti-hallucination approach.
- **Explainability**: Emphasize debug app’s user-friendly output (cards, icons, flow diagram) and DB visualizations for non-technical audiences.
- **Metrics**: Use MongoDB logs for evaluation (accuracy, latency, profile updates).
- **Future Work**: MA-SIF as foundation for specialized agent-based UI models; explore additional modalities (eye tracking).