# Offscreen

Offscreen is a small Streamlit app that uses the local Qwen2.5 0.5B model through Ollama to suggest outdoor nature missions. It stores observations in `nature_journal.json` on this computer.

## Run on Windows
1. Install Python 3.10+ and Ollama.
2. In PowerShell, run `ollama pull qwen2.5:0.5b`.
3. Run `start_app.bat`.

## v5 changes
- Weekly chart uses real date values so days appear in chronological order.
- Empty progress state explains how to record a completed break.
- Existing observations saved without marking a break complete remain in the journal, but do not count toward completed breaks, outdoor minutes, streaks, or the chart. This avoids inventing outdoor time.

The first install/download needs internet. After the model and Python packages are installed, the app can generate missions locally while offline, provided Ollama is running.


---

Built by [@ouuwz on GitHub](https://github.com/ouuwz) · [@ouuwz on Telegram](https://t.me/ouuwz)
