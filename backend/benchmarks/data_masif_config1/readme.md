# MA-SIF Config 1 Benchmark Data

Welcome to the benchmark data folder for **MA-SIF Config 1**. This dataset supports the evaluation and testing of the Multi-Agent Smart Intent Fusion (MA-SIF) framework for adaptive UI in the Accessible Smart Home Controller.

---

## 📁 Contents

- **Benchmark datasets:**  
    Sample results generated using MA-SIF Config 1.

---

## ⚙️ MA-SIF Config 1 Settings

Agent settings are:

| Agent           | Model                  | Temperature | Thinking Budget| Timeout |
|-----------------|------------------------|-------------|----------------|---------|
| UI Agent        | gemini-2.5-flash-lite  | 0.2         | 0              | 15      |
| Geometry Agent  | gemini-2.5-flash-lite  | 0.2         | 0              | 15      |
| Input Agent     | gemini-2.5-flash-lite  | 0.2         | 0              | 15      |
| Validator Agent | gemini-2.5-flash       | 0.3         | -1 (dynamic)   | 30      |

---

## 📊 Results Summary

See [`seq_summary.json`](./seq_summary.json) for a summary of benchmark results for this configuration.

