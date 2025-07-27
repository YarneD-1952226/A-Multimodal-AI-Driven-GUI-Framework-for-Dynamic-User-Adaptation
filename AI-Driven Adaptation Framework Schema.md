# A Multimodal AI-Driven GUI Framework for Dynamic User Adaptation

## Objective

This thesis presents a generalized, modular, and scalable framework for dynamic user interface (UI) adaptation, enabling real-time, personalized UI enhancements across diverse platforms (Flutter, React, SwiftUI, and future Unity) and domains (accessibility, gaming, smart homes). The framework leverages multimodal inputs (touch, keyboard, voice, gestures) to capture rich user interaction context, processed by a large language model (LLM) via xAI’s API (https://x.ai/api) and rule-based logic to deliver intelligent, accessibility-focused adaptations. The novel **Smart Intent Fusion** feature uses the LLM to fuse multimodal inputs, infer user intent, and propose predefined UI adaptations, enhancing accessibility and usability. Designed to be developer-friendly, the framework minimizes integration effort through a cross-platform SDK and is extensible to future modalities (e.g., eye tracking) and on-device AI models. The thesis positions AI-driven UI adaptation as an emerging research area, with LLMs as a stepping stone 
toward specialized models that dynamically rewrite UI code, a future PhD-level challenge.

"Let’s have an AI system that understands the multimodal user context (gesture, layout, gaze, etc.), and adapts the GUI dynamically — on the fly — to improve the UX for this specific user, in this specific moment."

---
## Architecture Overview

The framework is input- and output-agnostic, with an optional analyzing module for dynamic UI inspection. The data flow is:

**Frontend → Input Adapter Layer (with Optional Analyzing Module) → AI Backend Logic (with User Profiles & History) → Frontend (for Adaptations)**

### Data Flow

1. **Frontend**: Renders a cross-platform UI, captures multimodal interactions (touch, keyboard, voice, gestures), and applies AI-driven adaptations (e.g., button enlargement).
2. **Input Adapter Layer**: Unifies multimodal inputs and optional UI metadata into standardized context events, adhering to a strict JSON contract.
3. **AI Backend Logic**: Combines rule-based logic, LLM-driven **Smart Intent Fusion**, heatmap analysis, user profiles, and historical data to generate personalized adaptation actions.
4. **Frontend (Feedback)**: Applies adaptations, logs outcomes, and feeds back to the backend for continuous learning.

---

## Components

### 1. Frontend Layer

- **Purpose**: Renders a consistent UI across platforms, captures multimodal interactions, and applies dynamic adaptations from the backend. Focused on 3 main UI elements Scrollable card list, buttons and text blocks.
- **Platforms**:
  - **Flutter (Desktop/Mobile/web)**: main code base
  - **SwiftUI (Apple)**: contrast code base
  - **Future (VR/AR)**: Unity
- **Test UI Design**:
  - **Structure**: Art explorer
  - **Inputs**:
    - **Touch/Tap (Standard)**: Taps and miss-taps on buttons/cards, detecting errors (e.g., motor issues). Implemented via `GestureDetector` (Flutter), `onClick` (React), `.onTapGesture` (SwiftUI).
    - **Keyboard (Standard)**: `Tab` for navigation, `Enter` for selection, supporting motor-impaired users. Implemented via `RawKeyboardListener` (Flutter), `onKeyDown` (React), `.onKeyPress` (SwiftUI).
    - **Voice (Advanced)**: Commands (e.g., “play,” “next”) via speech-to-text for hands-free interaction. Implemented via `speech_to_text` (Flutter), Web Speech API (React), AVSpeechRecognizer (SwiftUI). Simulated via mock inputs if SDK setup is delayed.
    - **Gestures (Advanced)**: Hand gestures (e.g., point → select, swipe → scroll) via MediaPipe for natural/VR interaction. Implemented via `flutter_mediapipe` (Flutter), MediaPipe.js (React), custom bindings (SwiftUI). Simulated via mock events if integration exceeds sprint timeline.
  - **Behaviors (Adaptations)**:
    - **Standard (Cross-Platform)**:
      - **Increase Size**: Enlarges UI elements (e.g., buttons, text) for motor/visual impairments (e.g., `{"action": "increase_size", "target": "button", "value": 1.5}`).
      - **Reposition Element**: Moves elements closer to interaction points (e.g., `{"action": "move_closer", "target": "button", "offset": {"x": 20, "y": 0}}`).
      - **Increase Contrast**: Adjusts colors for readability (e.g., `{"action": "increase_contrast", "target": "button", "mode": "high"}`).
      - **Adjust Scroll Speed**: Reduces scroll speed for motor-impaired users (e.g., `{"action": "adjust_scroll_speed", "target": "scrollview", "value": 0.015}`).
      - **Mode Switching**: Switches to voice navigation on repeated miss-taps (e.g., `{"action": "switch_mode", "mode": "voice"}`). Simulated via mock backend responses if voice SDK setup is delayed. 
    - **Platform-Exclusive**:
      - **Flutter**: Smooth animations (e.g., `AnimatedScale` for button scaling).
      - **SwiftUI**: Haptic feedback (e.g., `UIImpactFeedbackGenerator` for button taps).
      - **Unity (Future)**: 3D object manipulation (e.g., `transform.localScale`) + sticky effect.
  - **Outputs**:
    - Interaction data (taps, keyboard presses, voice commands, gestures) for backend processing.
    - Optional UI metadata (e.g., button sizes, positions) via analyzing module.
  - **Developer Integration**:
    - Use SDK with pre-built UI templates and event hooks (e.g., `AdaptiveUI.sendEvent`).
    - Example (Flutter):
      ```dart
      AdaptiveUI.sendEvent('tap', element: 'button', coordinates: event.position, userId: 'user_123');
      AdaptiveUI.sendEvent('voice', command: 'info', confidence: 0.9, userId: 'user_123');
      ```
    - Minimal setup: 5–10 lines per platform for standard inputs; advanced inputs (voice, gestures) enabled via SDK config (e.g., `enableVoice: true`).

---

### 2. Input Adapter Layer

- **Purpose**: Unifies multimodal inputs and optional UI metadata into standardized context events, enabling LLM-driven **Smart Intent Fusion** for dynamic adaptations.
- **Inputs**:
  - **Touch/Tap**: Taps/miss-taps on buttons/cards to detect interactions/errors.
  - **Keyboard**: `Tab`/`Enter` for navigation/selection.
  - **Voice**: Commands (e.g., “play”) via speech-to-text. Simulated if SDK integration is delayed.
  - **Gestures**: Hand gestures (e.g., point, swipe) via MediaPipe. Simulated via mock events if integration exceeds sprint.
  - **Future**: Eye tracking -> webgazer.js, bio-signals.
  - **Optional Metadata**: UI structure (e.g., button sizes) from analyzing module.
- **Processing**:
  - Converts raw inputs to context events using a strict JSON contract.
  - Enriches events with `user_id`, timestamps, confidence scores, and metadata (e.g., gesture type).
  - Detects patterns (e.g., miss-tap if coordinates miss target).
- **JSON Contract**:
  ```json
  {
    "type": "object",
    "required": ["event_type", "source", "timestamp", "user_id"],
    "properties": {
      "event_type": {
        "type": "string",
        "enum": ["tap", "miss_tap", "key_press", "voice", "gesture"]
      },
      "source": {
        "type": "string",
        "enum": ["touch", "keyboard", "voice", "gesture"]
      },
      "timestamp": { "type": "string", "format": "date-time" },
      "user_id": { "type": "string" },
      "target_element": { "type": "string" },
      "coordinates": {
        "type": "object",
        "properties": { "x": { "type": "number" }, "y": { "type": "number" } }
      },
      "confidence": { "type": "number", "minimum": 0, "maximum": 1 },
      "metadata": {
        "type": "object",
        "properties": {
          "command": { "type": "string" }, // e.g., "play"
          "gesture_type": { "type": "string" }, // e.g., "swipe"
          "key": { "type": "string" } // e.g., "Enter"
        }
      }
    }
  }
  ```
- **Smart Intent Fusion (LLM-Driven Feature)**:
  - **Purpose**: Fuses multimodal inputs (e.g., voice “play” + miss-tap) to infer intent and suggest proactive adaptations (e.g., trigger button, enlarge it).
  - **Process**:
    - Combines inputs, user profiles (e.g., motor impairment), and history (e.g., frequent miss-taps).
    - Uses LLM (via xAI’s API) to reason (e.g., “Given user_123 with motor impairment, miss_tap near button_play, and voice ‘play,’ suggest adaptation”).
    - Response: `{"action": "increase_size", "target": "button_play", "value": 1.5, "secondary_action": "trigger_button"}`.
  - **Examples**:
    - **Accessibility**: Miss-tap + voice “play” → enlarge button, trigger action.
    - **Gaming**: Repeated miss-taps + voice “attack” → larger hitboxes.
    - **Smart Homes**: Voice “turn on” + gesture → reposition control.
  - **Value**:
    - **Intent Clarity**: Voice/gestures clarify vague inputs (e.g., point + “play” = select Play).
    - **Behavioral Insight**: Shaky gestures indicate motor issues, triggering accessibility adaptations.
    - **Novelty**: LLM’s proactive adaptations (e.g., switch to voice mode) go beyond static rules.
  - **Implementation**:
    - SDK provides adapters for voice (`speech_to_text`, Web Speech API) and gestures (MediaPipe). Simulated via mock events if setup exceeds sprint.
    - Developers call `sendEvent` with raw or library outputs (e.g., `{"event_type": "gesture", "gesture_type": "swipe"}`).
    - Backend validates events and processes via LLM/rules.
- **Developer Notes**:
  - Minimal effort: 1 line per event for standard inputs; advanced inputs via SDK config.
  - JSON contract ensures extensibility for new modalities.
  - Analyzing module (optional) provides UI metadata (e.g., button sizes).

---

### 3. AI Backend Logic

- **Purpose**: Generates adaptation actions using rule-based logic, LLM-driven **Smart Intent Fusion**, heatmap analysis, user profiles, and historical data.
- **Components**:
  - **Rule-Based Logic**: Deterministic adaptations (e.g., `if miss_tap then increase_size`).
    - Config: `{"condition": "miss_tap", "action": "increase_size", "value": 1.5}`
  - **LLM Reasoning (Smart Intent Fusion)**: Fuses inputs and profiles to infer intent and suggest creative adaptations (e.g., switch to voice mode).
  - **Heatmap Analysis**: Prioritizes targets based on interaction density (e.g., frequent taps on “Play”). Simulated via mock data if sprint time is limited.
  - **User Profiles & History**:
    - **Content**:
      - `user_id`: Unique identifier (e.g., UUID).
      - `accessibility_needs`: Booleans (e.g., `motor_impaired: true`, `visual_impaired: false`, `hands_free_preferred: true`).
      - `input_preferences`: Preferred modality (e.g., “voice”), sensitivity (0–1, e.g., 0.8 for gestures).
      - `interaction_history`: Past events (e.g., `[{event_type: "miss_tap", timestamp: "..."}]`), adaptation outcomes (e.g., `[{action: "increase_size", success: true}]`).
      - `ui_preferences`: Font size (e.g., 18), contrast mode (e.g., “high”), button size (e.g., 1.2).
      - Example:
        ```json
        {
          "user_id": "user_123",
          "accessibility_needs": {
            "motor_impaired": true,
            "visual_impaired": false,
            "hands_free_preferred": true
          },
          "input_preferences": {
            "preferred_modality": "voice",
            "sensitivity": 0.8
          },
          "interaction_history": [
            {"event_type": "miss_tap", "target_element": "button_play", "timestamp": "2025-07-22T12:00:00Z"},
            {"event_type": "tap", "target_element": "button_info", "timestamp": "2025-07-22T12:01:00Z"}
          ],
          "ui_preferences": {
            "font_size": 18,
            "contrast_mode": "normal",
            "button_size": 1.2
          }
        }
        ```
    - **Use**:
      - Personalizes adaptations (e.g., larger buttons for motor_impaired: true).
      - Provides LLM context for intent inference (e.g., prioritize voice for hands_free_preferred).
      - Updates history for continuous learning (e.g., frequent miss-taps → permanent size increase).
  - **Endpoints (FastAPI)**:
    - `/context`: Receives events, returns actions (e.g., `{"action": "increase_size", "target": "button_play"}`).
    - `/profile`: Manages user profiles.
    - `/modalities`: Configures supported inputs.
    - `/ws/adapt`: WebSocket for real-time adaptations (optional, simulated if needed).
  - **Logging**: Stores events and adaptations in `adaptation_log.jsonl` (e.g., `{"timestamp": "...", "context": {...}, "action": {...}}`). Uses MongoDB for scalability in production.
- **Implementation**:
  - Day 4: Build FastAPI backend with rule-based logic and mock LLM responses.
  - Day 5: Integrate xAI’s API for LLM-driven **Smart Intent Fusion**. Mock responses if API setup exceeds sprint.

---

## Key Features

- **Multimodal Intelligence**: Fuses touch, keyboard, voice, and gestures via **Smart Intent Fusion** to infer intent and adapt UI dynamically.
- **LLM-Centric**: LLM drives proactive, creative adaptations (e.g., mode switching, layout simplification) beyond static rules, with potential for specialized AI models in the future.
- **Generalization**: Input-agnostic (supports future modalities) and output-agnostic (Flutter, React, SwiftUI, Unity).
- **Accessibility-Focused**: Enhances usability for motor-impaired, visually impaired, or hands-free users.
- **Developer-Friendly**: SDK minimizes integration effort with pre-built adapters for voice/gestures.
- **Extensibility**: JSON contract and modular design support new domains and inputs.
- **Continuous Learning**: LLM refines adaptations using implicit feedback and historical data.

---

## Potential Applications

1. **Accessibility**: Real-time button resizing or navigation switching for motor/visual impairments.
2. **Gaming**: Adaptive hitboxes/controls based on player skill (e.g., larger hitboxes for novices).
3. **Smart Homes**: Context-aware control rearrangement (e.g., prioritize lights at night).
4. **Healthcare**: Personalized medical device interfaces (e.g., simplify for elderly users).
5. **Education**: Adaptive e-learning UIs based on learner interaction patterns.

---

## Future Work

The current framework uses LLMs to infer intent and suggest predefined adaptations, proving the concept of AI-driven UI adaptation within the constraints of 2025 technology. Future advancements could enable specialized AI models to dynamically rewrite UI code, a transformative but complex goal:

- **Specialized UI-Adapting AI Models**:
  - **Vision**: Develop lightweight AI models trained to generate stable, platform-specific UI code (e.g., Flutter widgets, React components) in real-time based on user context (e.g., motor impairments, voice commands).
  - **Capabilities**:
    - Dynamically rewrite UI codebases (e.g., adjust Flutter widget trees) for hyper-personalized adaptations.
    - Integrate multimodal inputs (touch, voice, gestures, eye tracking) and user profiles to propose creative solutions (e.g., redesign layouts for elderly users).
    - Run on-device for low-latency, privacy-preserving adaptations, reducing cloud dependency.
  - **Feasibility with Current Technology**:
    - **Possible**: Fine-tuning existing LLMs (e.g., CodeLlama) on curated datasets of UI codebases and interaction patterns could produce a prototype generating simple UI changes (e.g., CSS styles, widget parameters). Tools like MediaPipe and on-device inference frameworks (e.g., TensorFlow Lite) support multimodal input processing.
    - **Challenges**: 
      - **Dataset Scarcity**: No large-scale dataset exists for UI code paired with multimodal interactions and adaptation outcomes. Creating one requires months of data collection and annotation.
      - **Training Complexity**: Generating stable, platform-specific code in milliseconds demands advanced architectures (e.g., transformer-based code synthesis, graph neural networks) and significant compute resources.
      - **Stability and Safety**: Generated code must be bug-free and respect platform constraints, requiring robust validation pipelines.
      - **Real-Time Inference**: Achieving millisecond latency for on-device UI changes is cutting-edge, requiring model optimization (e.g., quantization, pruning).
    - **PhD-Level Scope**: Building such a model is feasible but requires 2–3 years of research, including dataset creation, model training, and integration with UI frameworks. This aligns with PhD-level challenges in AI-driven software engineering and HCI.
  - **Impact**: Specialized models could revolutionize accessibility, gaming, and smart homes by enabling seamless, personalized UI adaptations. The current framework’s use of LLMs for predefined behaviors lays the foundation for this future research.
- **Real-Time WebSocket Streaming**: Enable low-latency adaptations for immersive applications (e.g., VR).
- **Unity VR/AR Support**: Add hand/poke interactions for gaming and immersive environments.
- **Additional Modalities**: Integrate eye tracking, bio-signals for richer context.
- **Cloud-Based Microservices**: Scale backend for production-grade apps.

---

## Developer Workload & Integration

- **Setup**:
  - Integrate SDK with pre-built UI template and event hooks (5–10 lines per platform).
  - Enable standard inputs (touch, keyboard) via `sendEvent`.
  - Enable voice/gestures via SDK config (e.g., `enableVoice: true`) and library outputs (e.g., MediaPipe). Simulate if setup exceeds sprint.
- **Extending Modalities**:
  - Pass new input data (e.g., eye-tracking coordinates) to `sendEvent` with `metadata`.
  - JSON contract ensures backend compatibility.
- **Mitigation**:
  - SDK abstracts complexity (e.g., gesture processing via MediaPipe).
  - Analyzing module reduces manual metadata tagging.
  - API docs define contract fields and adaptation formats.
- **Example (Flutter)**:
  ```dart
  GestureDetector(
    onTapDown: (details) => AdaptiveUI.sendEvent(
      'tap',
      element: 'button_play',
      coordinates: details.globalPosition,
      userId: 'user_123',
    ),
    child: ElevatedButton(
      onPressed: () {},
      child: Text("Play"),
    ),
  )
  ```

---

## Evaluation Plan

- **Metrics**:
  - **Adaptation Accuracy**: Precision/recall of LLM-suggested actions (e.g., correct button enlargement).
  - **User Performance**: Task completion time, error rate (missed inputs).
  - **User Satisfaction**: System Usability Scale (SUS) scores, qualitative feedback.
  - **System Performance**: End-to-end latency (cloud-based, simulated on-device).
- **Case Studies**:
  - **Accessibility**: Flutter/React/SwiftUI UI adapting for motor-impaired users (e.g., button grows after miss-tap).
  - **Gaming**: Simulated hitbox enlargement in React UI.
  - **Smart Homes**: SwiftUI mockup adjusting controls via voice/gesture.
- **User Studies**:
  - Test with 5–10 users (simulated motor impairments) per platform.
  - Compare task success with/without **Smart Intent Fusion**.
  - Collect feedback on usability and accessibility.

---

## Novelty and Thesis Impact

- **Emerging Research Area**: AI-driven UI adaptation is a novel, under-explored field in HCI, with limited work on multimodal, LLM-driven frameworks. **Smart Intent Fusion** distinguishes this thesis by fusing inputs (e.g., voice “play” + miss-tap) to infer intent and propose creative adaptations (e.g., trigger button, enlarge it).
- **Multimodal Value**: Touch, keyboard, voice, and gestures provide intent clarity (e.g., voice + gesture = select button) and behavioral cues (e.g., shaky gestures → larger buttons).
- **Generalizability**: Cross-platform (Flutter, React, SwiftUI) and cross-domain (accessibility, gaming, smart homes) applicability.
- **Developer-Friendly**: SDK with pre-built adapters minimizes integration effort.
- **Accessibility Impact**: Personalized adaptations enhance usability for motor-impaired, visually impaired, or hands-free users.
- **Future Vision**: The framework lays the groundwork for specialized AI models that dynamically rewrite UI code, a PhD-level challenge that could transform adaptive UX.
- **Evaluation**: Rigorous metrics and user studies ensure academic rigor and publishable results.

---

## 5-Day Implementation Plan (July 22–26, 2025)

To ensure a thesis-worthy demo, we’ll deliver a working component daily, focusing on touch and keyboard inputs, with voice and gestures simulated if SDK integration exceeds time constraints. The scope prioritizes **Smart Intent Fusion** to demonstrate LLM-driven GUI adaptation.

- **Day 1 (July 22, Today, by 5 PM CEST)**:
  - **Goal**: Enhance Flutter UI to capture tap/miss-tap events, remove simulated buttons, implement **Input Adapter** with `user_id`, and support **increase_size** and **reposition_element** behaviors (hard-coded).
  - **Output**: Flutter app with card list, Play/Info buttons, tap/miss-tap logging to `events.jsonl`, and temporary adaptations.
  - **Tasks** (~3.5 hours from 1:26 PM CEST):
    - Setup: Add `placeholder.png`, update `pubspec.yaml`, copy code (30 min).
    - UI: Add “Info” button, remove simulated buttons, test tap/miss-tap detection (1.5 hours).
    - Input Adapter: Log events with `user_id` (1 hour).
    - Test: Verify miss-taps trigger **increase_size** (scale 1.5) and **reposition_element** (20px right) (30 min).
  - **Status**: Code provided (flutter_test_ui.dart, artifact_id: f6ae2212-6f36-4f15-ba79-2b5be38cb194).

- **Day 2 (July 23)**:
  - **Goal**: Port UI to React and SwiftUI, extend Input Adapter for keyboard inputs (`Tab`, `Enter`), add **increase_contrast** behavior.
  - **Output**: Cross-platform UI with tap/keyboard support, logging events consistently.
  - **Tasks** (~5 hours):
    - React: Use `div` for cards, `<button>` for Play/Info, `onClick`/`onKeyDown` for inputs.
    - SwiftUI: Use `List` for cards, `Button` for Play/Info, `.onTapGesture`/.onKeyPress`.
    - Input Adapter: Add keyboard events (e.g., `{"event_type": "key_press", "key": "Enter"}`).
    - Test: Verify tap/keyboard navigation and contrast adjustment.

- **Day 3 (July 24)**:
  - **Goal**: Add voice and gesture support to Input Adapter using SDK adapters (e.g., `speech_to_text`, MediaPipe). Simulate if setup exceeds sprint.
  - **Output**: Multimodal Input Adapter handling tap, keyboard, voice, gestures (or mock events).
  - **Tasks** (~5 hours):
    - Voice: Integrate `speech_to_text` (Flutter), Web Speech API (React), AVSpeechRecognizer (SwiftUI). Mock commands (e.g., `{"event_type": "voice", "command": "play"}`) if needed.
    - Gestures: Integrate `flutter_mediapipe` (Flutter), MediaPipe.js (React), custom bindings (SwiftUI). Mock gestures (e.g., `{"event_type": "gesture", "gesture_type": "point"}`) if needed.
    - Test: Log voice/gesture events.

- **Day 4 (July 25)**:
  - **Goal**: Build FastAPI backend with rule-based logic and mock LLM responses for **Smart Intent Fusion**, applying adaptations (e.g., enlarge button).
  - **Output**: UI adapting to tap/keyboard inputs via backend.
  - **Tasks** (~5 hours):
    - Backend: Create `/context` endpoint with rules (e.g., `if miss_tap then increase_size`).
    - Mock LLM: Simulate responses (e.g., `{"action": "increase_size"}`).
    - Test: Verify UI adapts based on backend responses.

- **Day 5 (July 26)**:
  - **Goal**: Integrate xAI’s API for LLM-driven **Smart Intent Fusion**, fusing multimodal inputs (e.g., voice + gesture). Finalize demo and evaluation plan. Mock LLM responses if API setup exceeds sprint.
  - **Output**: Thesis-ready prototype with demo video and evaluation metrics.
  - **Tasks** (~5 hours):
    - LLM: Use xAI’s API for prompts (e.g., “Given miss_tap and voice ‘play,’ suggest adaptation”). Mock if needed.
    - Demo: Record video showing UI adapting (e.g., button enlarges after voice + gesture).
    - Evaluation: Define metrics (accuracy, performance, satisfaction) and user study plan (5–10 users).
    - Test: Verify multimodal fusion.

---

## Simulation Strategy for Feasibility

To manage the ambitious scope within 5 days, we’ll simulate complex components if implementation exceeds time constraints:
- **Voice/Gestures**: Mock events (e.g., `{"event_type": "voice", "command": "play"}`) if SDK integration (e.g., MediaPipe) takes too long.
- **LLM Responses**: Mock backend responses (e.g., `{"action": "increase_size"}`) on Days 1–4, integrating xAI’s API on Day 5. Simulate if API setup is delayed.
- **Heatmap Analysis**: Mock interaction density data if full implementation is infeasible.
- **Platform-Exclusive Behaviors**: Prioritize Flutter animations; implement React CSS transitions and SwiftUI haptics if time allows.
This ensures a polished demo focusing on the novel **Smart Intent Fusion** concept while maintaining feasibility.

---

## Thesis Focus: Novelty of LLM-Driven GUI Adaptation

The thesis centers on the transformative potential of LLMs (and future specialized AI models) to dynamically adapt GUIs based on multimodal inputs and user profiles in an emerging research area. **Smart Intent Fusion** enables the LLM to:
- **Infer Intent**: Combine inputs (e.g., voice “play” + miss-tap) to understand user goals (e.g., trigger Play button).
- **Propose Creative Adaptations**: Suggest proactive changes (e.g., enlarge button, switch to voice mode) beyond static rules.
- **Personalize via Profiles**: Use user data (e.g., motor impairment) and history (e.g., frequent miss-taps) to tailor adaptations.
- **Enhance Accessibility**: Improve usability for motor-impaired, visually impaired, or hands-free users.
- **Future Vision**: Specialized on-device AI models could generate real-time, stable UI code (e.g., Flutter widgets), a PhD-level challenge requiring advanced training and integration. The current framework proves the concept using LLMs, laying the foundation for this future research.