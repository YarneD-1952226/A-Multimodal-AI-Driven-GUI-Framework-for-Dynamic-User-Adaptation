<font size="+1">
# Multi-Agent Smart Intent Fusion (MA-SIF) Architecture Design

## Overview

**Multi-Agent Smart Intent Fusion (MA-SIF)** enhances the **LLM Reasoning** component within **Smart Intent Fusion (SIF)** by introducing a multi-agent system. This approach mitigates hallucinations, improves adaptation reliability, and ensures accessibility-focused outputs. MA-SIF operates as a collaborative layer where agents interact iteratively to refine inferences. 

- Retain **"Smart Intent Fusion"** as the primary name.
- Use **"Multi-Agent Enhanced"** as a subtitle to highlight thesis novelty.

This positions SIF as a robust framework for real-time UI adaptation in domains like accessibility, gaming, and smart homes, addressing LLM limitations through agentic validation.

---

## Core Components

### **Intent Inference Agent (IIA)**

- **Role**: Analyzes fused multimodal inputs (e.g., voice command + miss-tap), user profile (e.g., motor impairment flags), and interaction history (e.g., frequent miss-taps) to infer user goals.
- **Inputs**: 
    - Current event JSON
    - Profile data
    - Capped history array (e.g., last 20 events)
- **Outputs**: Inferred intent summary (e.g., "User intends to trigger 'play' button despite motor issues").
- **Design**: Prompted LLM (e.g., Gemini) with a focus on behavioral insights and intent clarity.

---

### **Adaptation Proposal Agent (APA)**

- **Role**: Generates proactive UI adaptations based on IIA's intent, constrained to predefined actions (e.g., `increase_size`, `switch_mode`).
- **Inputs**: 
    - IIA's intent summary
    - Full context (event, profile, history)
- **Outputs**: List of proposed adaptations with reasons (e.g., `[{"action": "increase_size", "target": "button_play", "value": 1.5, "reason": "Motor impairment detected"}]`).
- **Design**: LLM prompted for creative yet rule-aligned suggestions, emphasizing novelty beyond static rules (e.g., mode switching for hands-free users).

---

### **Validation and Refinement Agent (VRA)**

- **Role**: Critiques APA's proposals for hallucinations, consistency with profile/history, safety (e.g., no buggy adaptations), and accessibility compliance (e.g., WCAG guidelines).
- **Inputs**: 
    - IIA intent
    - APA proposals
    - Original context
- **Outputs**: Refined adaptations (e.g., approve, modify, or reject with feedback).
- **Design**: LLM as a "critic" agent, checking for biases, factual errors, and edge cases (e.g., shaky gestures implying motor issues).

---

## Data Flow and Integration

### **Entry Point**
- SIF's AI Backend Logic receives events via `/ws/adapt` or `/context`.
- Loads profile/history from MongoDB.

### **Agent Pipeline**
1. Fuse data (event + profile + history) into a shared context payload.
2. **IIA** processes first: Generates intent summary via LLM prompt.
3. **APA** receives IIA output: Proposes adaptations.
4. **VRA** reviews APA output: Provides feedback (e.g., "Proposal hallucinates non-existent impairment; refine to visual aid").
5. **Iteration**: Loop 2-3 rounds—APA incorporates VRA feedback, VRA re-validates—via prompt chaining (sequential LLM calls) for efficiency.
6. **Final Output**: VRA-approved JSON adaptations returned to the frontend.

### **Integration with Existing SIF**
- Embed MA-SIF within the **LLM Reasoning** sub-component, replacing the single LLM call.
- Rule-Based Logic and Heatmap Analysis run in parallel as fallbacks or inputs to agents.
- **User Profiles & History**: Agents access via MongoDB; append outcomes post-validation for continuous learning.
- **Endpoints**: No changes; MA-SIF handles processing internally.
- **Logging**: Extend `adaptation_log.jsonl` to include agent traces (e.g., intent summaries, feedback loops) for explainability.

---

## Efficiency and Scalability

- **Latency Management**: Use async LLM calls; cap iterations at 3; fallback to single LLM or rules if timeouts occur.
- **Resource Optimization**: Agents share the same LLM model (e.g., Gemini Flash for speed); cache common prompts.
- **Edge Cases**: Handle incomplete data (e.g., no history → IIA defaults to profile); VRA detects hallucinations via cross-validation (e.g., fact-check against history).

### **Thesis Novelty**
- **"Agentic Fusion Layer"** reduces LLM errors by 20-30% (hypothetical metric via evaluation).
- Enables PhD extension to specialized agents (e.g., domain-specific like gaming).
- Positions as emerging HCI research for reliable AI-driven UIs.

---

## Evaluation Plan

- **Metrics**: 
    - Adaptation accuracy (precision/recall vs. ground truth)
    - Hallucination rate (manual review)
    - Latency
    - User satisfaction (SUS scores)
- **Studies**: Compare single-LLM vs. MA-SIF in accessibility scenarios (e.g., motor-impaired users); test with 10 simulated interactions per modality.

</font>