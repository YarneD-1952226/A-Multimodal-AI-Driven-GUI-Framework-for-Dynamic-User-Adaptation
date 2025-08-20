
# Objective Metrics (What & Why)

This evaluation adds objective, log-driven measures of **effectiveness** (not just timing). They are computed with deterministic rules from your JSONL logs and the allowed action set.

## Metrics

1) **Profile–Action Alignment (PAA)**  
   *What*: % of accessibility-targeted actions whose category matches the active profile’s declared needs (motor / visual / hands-free).  
   *Why*: Quantifies **personalization**. High PAA means the system primarily proposes changes relevant to that user’s needs, not just generic accessibility tweaks.

2) **Error→Response Appropriateness (ERA)**  
   *What*: % of error events (miss_tap, slider_miss, plus voice/gesture entries) that received at least one acceptable corrective adaptation (pre-defined mapping).  
   *Why*: Captures **reactive correctness**: when an error occurs, does the system suggest a reasonable fix?

3) **Design Coherence Index (DCI)**  
   *What*: For each response, DCI = 1 − (conflicts + duplicates)/suggestions. Conflicts include proposing multiple `switch_mode` values (e.g., voice + gesture) in a single response; duplicates are repeated identical actions for the same target.  
   *Why*: Measures **design quality** within a single update—no contradictions, clean suggestions.

4) **Mode Enablement for Hands-free (MEH)**  
   *What*: For hands-free profiles, % of events where the system explicitly enables/uses hands-free paths (`switch_mode: voice|gesture` or `trigger_button` in a voice event).  
   *Why*: Ensures **hands-free users** reliably get an alternative to precise touch input.

5) **Global accessibility share** (already reported): % of all actions that are accessibility-targeted.  
   *Why*: Confirms the system’s **focus** on accessibility as a design goal.

6) **WCAG policy coverage (qualitative)**  
   *What*: Whether suggested actions address relevant WCAG SCs (2.5.5 Target Size; 1.4.3 Contrast; 1.4.4 Resize Text).  
   *Why*: Places adaptations in a recognised **accessibility standard** context (policy coverage, not a conformance audit).

## How to run

```
python compute_metrics.py /path/to/logs
```

Outputs:
- `metrics_summary.csv` (globals)
- `metrics_by_profile.csv` (per profile)

## Assumptions

- The parser looks for common keys (profile, event_type, actions). If yours differ, edit the *KEY PATHS* section at the top.
- Action names used: `increase_button_size`, `increase_button_border`, `increase_slider_size`, `adjust_spacing` (motor); `increase_font_size`, `increase_contrast` (visual); `switch_mode` (hands-free enabling); `trigger_button` (hands-free only if used in a voice event). Adjust if you have extra actions.
- Event names: `miss_tap`, `slider_miss`, `voice`, `gesture`. Aliases for `tap_miss`, `slider_overshoot`, `speech` are handled.

