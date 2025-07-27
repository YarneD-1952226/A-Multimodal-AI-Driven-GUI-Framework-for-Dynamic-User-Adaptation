# A Multimodal AI-Driven GUI Framework for Dynamic User Adaptation

## Objective

This thesis presents a modular, scalable framework for dynamic user interface (UI) adaptation, enabling real-time, personalized UI enhancements across platforms (Flutter, React, SwiftUI) and domains. It leverages multimodal inputs (touch, keyboard, voice, gestures) processed by a large language model (LLM) via OpenAI API to deliver accessibility-focused adaptations, enhancing usability for motor-impaired, visually impaired, and hands-free users. The framework is developer-friendly, using a cross-platform SDK, and extensible to future modalities (e.g., eye tracking).

## Architecture Overview

The framework is input- and output-agnostic, with an optional analyzing module for UI inspection. Data flow: **Frontend → Input Adapter Layer → AI Backend Logic (with User Profiles & History) → Frontend (for Adaptations)**.

### Data Flow
1. **Frontend**: Renders UI, captures multimodal inputs, applies adaptations (e.g., button enlargement).
2. **Input Adapter Layer**: Unifies inputs into standardized context events (JSON contract).
3. **AI Backend Logic**: Uses rule-based logic, LLM-driven **Smart Intent Fusion**, user profiles, and historical data to generate personalized adaptation actions.
4. **Frontend (Feedback)**: Applies adaptations, logs outcomes for continuous learning.

## Components

### 1. Frontend Layer
- **Purpose**: Renders consistent UI, captures inputs (touch, keyboard, voice, gestures), applies adaptations.
- **Platforms**: Flutter, React, SwiftUI (future: Unity for VR/AR).
- **Test UI Design**: “Art Explorer” app with a vertical scrollable card list (image, title, description, Play/Info buttons).
- **Inputs**:
  - Touch/Tap: Detects taps/miss-taps on buttons/cards for motor issues.
  - Keyboard: `Tab`/`Enter` for navigation/selection.
  - Voice: Commands (e.g., “play”) for hands-free use (simulated if needed).
  - Gestures: Hand gestures (e.g., swipe to scroll) via MediaPipe (simulated if needed).
- **Behaviors (Adaptations)**:
  - Increase Size: Enlarges cards/buttons/text (e.g., card: 1.2x, button: 1.5x, text: 20pt).
  - Reposition Element: Moves buttons closer to tap points (e.g., 20px right).
  - Increase Contrast: Enhances text/button readability (e.g., black on white).
  - Adjust Scroll Speed: Slows scrolling for motor-impaired users (e.g., higher friction).
  - Mode Switching: Switches to voice navigation on repeated miss-taps (simulated if needed).
- **Outputs**: Interaction data (e.g., taps, voice commands) and optional UI metadata (e.g., button sizes).

### 2. Input Adapter Layer
- **Purpose**: Standardizes multimodal inputs into JSON events for LLM-driven **Smart Intent Fusion**.
- **Inputs**: Touch, keyboard, voice, gestures, future modalities (e.g., eye tracking).
- **Processing**: Converts raw inputs to events (e.g., `{"event_type": "miss_tap", "user_id": "user_123"}`).
- **Smart Intent Fusion**: LLM fuses inputs (e.g., miss-tap + voice “play”) to suggest adaptations (e.g., enlarge button).

### 3. AI Backend Logic
- **Purpose**: Generates adaptation actions using rule-based logic, LLM, user profiles, and history.
- **Components**:
  - Rule-Based Logic: Deterministic adaptations (e.g., miss-tap → enlarge button).
  - LLM (Smart Intent Fusion): Infers intent, suggests creative adaptations (e.g., voice mode).
  - User Profiles: Include `user_id`, accessibility needs (e.g., motor_impaired: true), input preferences, and interaction history.
  - Heatmap Analysis: Prioritizes targets based on interaction density (simulated if needed).
- **Endpoints**: Python FastAPI endpoints (e.g., `/context`) return actions (e.g., `{"action": "increase_size"}`).

## Key Features
- Multimodal intelligence.
- LLM-driven proactive adaptations (e.g., mode switching).
- Accessibility-focused for motor-impaired, visually impaired, hands-free users.
- Cross-platform (Flutter, React, SwiftUI) and extensible to new modalities.
- Developer-friendly SDK with minimal integration effort.

## Future Work
- Specialized AI models to dynamically rewrite UI code or real time microadaptations.
- Real-time WebSocket streaming for low-latency adaptations.
- Unity VR/AR support for immersive interactions.
- Additional modalities (e.g., eye tracking).