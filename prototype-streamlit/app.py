import json
import re
from datetime import date, datetime, timedelta
from pathlib import Path

import requests
import streamlit as st

APP_DIR = Path(__file__).resolve().parent
JOURNAL_FILE = APP_DIR / "nature_journal.json"
OLLAMA_URL = "http://localhost:11434"
MODEL_NAME = "qwen2.5:0.5b"

st.set_page_config(page_title="Offscreen", page_icon="🌱", layout="centered")

st.markdown(
    """
    <style>
      .block-container { max-width: 850px; padding-top: 2rem; padding-bottom: 3rem; }
      .hero { padding: 1.4rem; border: 1px solid rgba(110,140,100,.28); border-radius: 18px;
              background: linear-gradient(120deg, rgba(80,130,70,.12), rgba(140,170,100,.06)); }
      .small-note { opacity: .78; font-size: .92rem; }
    </style>
    """,
    unsafe_allow_html=True,
)


def ollama_status():
    """Return (reachable, model_installed, message)."""
    try:
        response = requests.get(f"{OLLAMA_URL}/api/tags", timeout=2)
        response.raise_for_status()
        models = response.json().get("models", [])
        installed = any(m.get("name", "").split(":")[0] == MODEL_NAME.split(":")[0] and
                        (m.get("name", "").endswith(":0.5b") or m.get("name") == MODEL_NAME)
                        for m in models)
        return True, installed, "Ollama is running."
    except requests.RequestException:
        return False, False, "Ollama is not responding on this computer."
    except (ValueError, TypeError):
        return True, False, "Ollama responded, but its model list could not be read."


def make_prompt(place, minutes, energy, company, focus):
    # Small local models are more reliable when asked for one short idea,
    # rather than an entire formatted mission. Python adds the consistent steps.
    return f"""Suggest ONE simple thing to notice during a safe outdoor break.
Place: {place}
Time available: {minutes} minutes
Energy: {energy}
Going: {company}
Interest: {focus}

Return only one short, natural sentence of 8 to 14 words.
Describe something the person can observe from a safe public spot.
Use ordinary words and sensory details, not scientific explanations.
Do not name or identify species, list facts, give instructions to touch anything,
or mention eating, collecting, approaching, chasing, or disturbing wildlife.
No title, no bullet, no numbering, no Markdown, no quotation marks, no preamble.
"""


def safe_ai_idea(raw_text, focus):
    """Clean and validate the model's short suggestion; fall back if malformed."""
    fallbacks = {
        "Plants and leaves": "Notice how leaf edges, colours, and shadows differ from plant to plant.",
        "Birds and natural sounds": "Stand still and listen for layers of sound without approaching any animal.",
        "Clouds and the sky": "Notice cloud shapes, gaps of blue, and how sunlight changes their edges.",
        "Small details I usually miss": "Look for an overlooked pattern, shadow, texture, or tiny change in colour.",
        "A mix of everything": "Notice one sound, one shape, and one small detail you usually walk past.",
    }
    fallback = fallbacks.get(focus, fallbacks["A mix of everything"])
    original = (raw_text or "").strip()
    # If the model ignores the one-sentence instruction, use the known-safe idea.
    if re.match(r"^(?:\d+[.)]|[-*•])\s+", original):
        return fallback
    idea = original.splitlines()[0].strip()
    idea = re.sub(r"^(?:here is |here's )?(?:an? )?(?:idea|suggestion|spotlight)\s*:?\s*", "", idea, flags=re.IGNORECASE)
    idea = idea.strip(" \"'`-*•")
    idea = re.sub(r"\s+", " ", idea)
    unsafe_or_unhelpful = re.compile(
        r"\b(eat|taste|collect|pluck|pick|touch|handle|feed|chase|capture|"
        r"approach|disturb|climb|cross (?:the )?road|leave (?:the )?path|"
        r"cumin|cumulonimbus|identify species)\b",
        re.IGNORECASE,
    )
    if not idea or len(idea) > 150 or len(idea.split()) > 20 or unsafe_or_unhelpful.search(idea):
        return fallback
    return idea.rstrip(" .") + "."


def build_mission(raw_idea, place, minutes, energy, company, focus):
    """Use the AI for a custom idea and stable Python text for a clear mission."""
    idea = safe_ai_idea(raw_idea, focus)
    title_by_focus = {
        "Plants and leaves": "A Closer Look at Leaves",
        "Birds and natural sounds": "A Listening Walk",
        "Clouds and the sky": "Clouds and the Sky",
        "Small details I usually miss": "The Notice-Three Mission",
        "A mix of everything": "A Little Bit of Everything",
    }
    title = title_by_focus.get(focus, "The Notice-Three Mission")
    observation_minutes = min(5, max(2, int(minutes) // 3))
    if company == "By myself":
        share_step = "When you finish, remember the detail you found most interesting. No photo needed."
    else:
        share_step = "When you finish, each of you can share one detail the other person missed."

    return (
        f"### Mission: {title}\n\n"
        f"*{minutes} minutes · {place} · made for your energy today*\n\n"
        f"1. **Find a safe spot.** Stay in a familiar public area or on a marked path, "
        f"and keep an eye on traffic and your surroundings.\n\n"
        f"2. **Your AI-generated idea:** {idea}\n\n"
        f"3. **Slow down for {observation_minutes} minutes.** Notice one more sound, shape, "
        f"or colour around you. Observe from where you are; don't touch or disturb plants or animals.\n\n"
        f"4. **Put your phone away.** {share_step}\n\n"
        f"**Reflection:** What did you notice that you might normally walk past?"
    )


def generate_mission(prompt):
    response = requests.post(
        f"{OLLAMA_URL}/api/generate",
        json={
            "model": MODEL_NAME,
            "prompt": prompt,
            "stream": False,
            "keep_alive": "5m",
            "options": {
                "temperature": 0.3,
                "num_predict": 48,
                "num_ctx": 1024,
                "num_thread": 2,
            },
        },
        timeout=150,
    )
    response.raise_for_status()
    text = response.json().get("response", "").strip()
    if not text:
        raise RuntimeError("The model returned an empty answer. Try once more.")
    return text


def read_journal():
    if not JOURNAL_FILE.exists():
        return []
    try:
        data = json.loads(JOURNAL_FILE.read_text(encoding="utf-8"))
        return data if isinstance(data, list) else []
    except (OSError, json.JSONDecodeError):
        return []


def save_entry(entry):
    entries = read_journal()
    entries.append(entry)
    JOURNAL_FILE.write_text(json.dumps(entries, ensure_ascii=False, indent=2), encoding="utf-8")


def format_saved_at(value):
    """Turn an ISO timestamp into a friendly date and time for the journal."""
    if not value:
        return "Date not available"
    try:
        stamp = datetime.fromisoformat(value)
        # Use the computer's local timezone when the saved timestamp includes an offset.
        if stamp.tzinfo is not None:
            stamp = stamp.astimezone()
        return stamp.strftime("%d %b %Y, %I:%M %p").lstrip("0").replace(" 0", " ")
    except (TypeError, ValueError):
        return str(value)


st.markdown(
    """
    <div class="hero">
      <h1>🌱 Offscreen</h1>
      <p><b>A tiny AI nature companion.</b></p>
      <p>Get one small mission, put your phone away, and notice what's around you.</p>
      <p class="small-note">Designed to run locally. No account, tracking, or cloud AI API required.</p>
    </div>
    """,
    unsafe_allow_html=True,
)

st.write("")
reachable, installed, status_message = ollama_status()
if reachable and installed:
    st.success(f"Local AI ready · {MODEL_NAME}")
elif reachable:
    st.warning("Ollama is running, but the model isn't installed yet. Follow the setup instructions in README.md.")
else:
    st.info("Demo mode: install and start Ollama to generate missions with the local AI.")

st.subheader("Plan a small outdoor break")
with st.form("mission_form"):
    col1, col2 = st.columns(2)
    with col1:
        place = st.selectbox("Where are you going?", ["College campus", "Park or garden", "My neighbourhood", "Balcony or outdoor area"])
        minutes = st.selectbox("How much time do you have?", [10, 20, 30], index=0, format_func=lambda x: f"{x} minutes")
        energy = st.selectbox("Your energy today", ["Low — keep it gentle", "Okay — a little walking", "High — I want to explore"])
    with col2:
        company = st.selectbox("Going", ["By myself", "With a friend", "With family"])
        focus = st.selectbox("What sounds interesting?", ["Plants and leaves", "Birds and natural sounds", "Clouds and the sky", "Small details I usually miss", "A mix of everything"])
    submitted = st.form_submit_button("Give me a mission 🌿", type="primary", use_container_width=True)

if submitted:
    st.session_state.pop("break_started_at", None)
    st.session_state.pop("break_completed_at", None)
    st.session_state.pop("observation_input", None)
    prompt = make_prompt(place, minutes, energy, company, focus)
    if reachable and installed:
        with st.spinner("Your local AI is thinking. On this laptop, the first answer may take a little while..."):
            try:
                ai_idea = generate_mission(prompt)
                st.session_state["mission"] = build_mission(
                    ai_idea, place, minutes, energy, company, focus
                )
                st.session_state["mission_source"] = "Local Qwen2.5 0.5B idea · mission formatted by Python"
                st.session_state["mission_details"] = {"place": place, "minutes": minutes, "focus": focus}
            except requests.Timeout:
                st.session_state["mission"] = "The local model took too long to answer. Try again with a shorter mission, or check that Ollama is running."
                st.session_state["mission_source"] = "Local AI timed out"
                st.session_state["mission_details"] = {"place": place, "minutes": minutes, "focus": focus}
            except (requests.RequestException, RuntimeError, ValueError) as exc:
                st.session_state["mission"] = f"I couldn't get a response from Ollama. Check that the model is installed and try again.\n\nTechnical detail: {exc}"
                st.session_state["mission_source"] = "Local AI error"
                st.session_state["mission_details"] = {"place": place, "minutes": minutes, "focus": focus}
    else:
        st.session_state["mission"] = (
            "### The Notice-Three Mission\n\n"
            "1. Find a safe spot outdoors and put your phone away for a moment.\n"
            "2. Notice three things you hadn't paid attention to before: a shape, a sound, and a colour.\n"
            "3. Take a slow look around without touching or disturbing anything.\n\n"
            "**Reflection:** Which detail would you have missed if you were scrolling?\n\n"
            "*This is a built-in demo mission, not an AI-generated answer. Install the local model to activate AI.*"
        )
        st.session_state["mission_source"] = "Built-in demo (AI not connected)"
        st.session_state["mission_details"] = {"place": place, "minutes": minutes, "focus": focus}

def show_break_timer():
    """Refresh only the timer area, not the whole app, once per second."""
    started_at = st.session_state.get("break_started_at")
    if not started_at:
        return
    try:
        start_time = datetime.fromisoformat(started_at)
    except (TypeError, ValueError):
        st.session_state.pop("break_started_at", None)
        return
    details = st.session_state.get("mission_details", {})
    target_seconds = int(details.get("minutes", 10)) * 60
    elapsed = max(0, int((datetime.now().astimezone() - start_time).total_seconds()))
    remaining = max(0, target_seconds - elapsed)
    mins, secs = divmod(remaining, 60)
    st.metric("Time to put your phone away", f"{mins:02d}:{secs:02d}")
    if remaining == 0:
        st.info("Your planned time is up. Finish safely whenever you're ready.")
    else:
        st.caption("Leave this page open if you want to see the timer. Then put your phone away and head outside.")


if st.session_state.get("mission"):
    st.divider()
    st.subheader("Your mission")
    st.caption(st.session_state.get("mission_source", ""))
    st.markdown(st.session_state["mission"])

    details = st.session_state.get("mission_details", {})
    if not st.session_state.get("break_started_at") and not st.session_state.get("break_completed_at"):
        if st.button("Start my phone-down break 🌿", type="primary", use_container_width=True):
            st.session_state["break_started_at"] = datetime.now().astimezone().isoformat(timespec="seconds")
            st.rerun()

    if st.session_state.get("break_started_at") and not st.session_state.get("break_completed_at"):
        # Streamlit fragments refresh this small section, leaving the rest of the app alone.
        @st.fragment(run_every="1s")
        def live_break_timer():
            show_break_timer()
        live_break_timer()
        if st.button("I'm back from my break", use_container_width=True):
            st.session_state["break_completed_at"] = datetime.now().astimezone().isoformat(timespec="seconds")
            st.rerun()

    if st.session_state.get("break_completed_at"):
        st.success("Break marked complete. What did you notice outside?")

    st.write("When you're back, save one thing you noticed. No need to take a photo.")
    observation = st.text_area("One thing I noticed", key="observation_input", placeholder="For example: I heard two different bird calls near the library...")
    if st.button("Save to my local nature journal", use_container_width=True):
        if not observation.strip():
            st.warning("Write one short observation first, even just a sentence.")
        else:
            try:
                started_at = st.session_state.get("break_started_at")
                completed_at = st.session_state.get("break_completed_at")
                elapsed_minutes = None
                if started_at and completed_at:
                    elapsed_minutes = max(0, round((datetime.fromisoformat(completed_at) - datetime.fromisoformat(started_at)).total_seconds() / 60, 1))
                save_entry({
                    "saved_at": datetime.now().astimezone().isoformat(timespec="seconds"),
                    "place": details.get("place", "Not specified"),
                    "minutes": details.get("minutes", "Not specified"),
                    "focus": details.get("focus", "Not specified"),
                    "mission": st.session_state["mission"],
                    "source": st.session_state.get("mission_source", "Unknown"),
                    "observation": observation.strip(),
                    "break_completed": bool(completed_at),
                    "break_started_at": started_at,
                    "break_completed_at": completed_at,
                    "elapsed_minutes": elapsed_minutes,
                })
                st.success("Saved on this computer in nature_journal.json.")
                st.session_state.pop("break_started_at", None)
                st.session_state.pop("break_completed_at", None)
            except (OSError, ValueError) as exc:
                st.error(f"Couldn't save the journal file: {exc}")

with st.expander("My nature journal", expanded=True):
    entries = read_journal()
    if not entries:
        st.write("Your journal is empty for now. Finish a mission and save an observation to start it.")
    else:
        completed_entries = [entry for entry in entries if entry.get("break_completed")]
        total_minutes = sum(float(entry.get("elapsed_minutes") or 0) for entry in completed_entries)

        # Count one completed day at most once, even if multiple breaks were saved.
        completed_days = set()
        for entry in completed_entries:
            stamp = entry.get("break_completed_at") or entry.get("saved_at", "")
            try:
                completed_days.add(datetime.fromisoformat(stamp).astimezone().date())
            except (TypeError, ValueError):
                continue

        today = datetime.now().astimezone().date()
        streak_anchor = today if today in completed_days else today - timedelta(days=1)
        current_streak = 0
        while streak_anchor in completed_days:
            current_streak += 1
            streak_anchor -= timedelta(days=1)

        stat1, stat2, stat3, stat4 = st.columns(4)
        stat1.metric("Journal entries", len(entries))
        stat2.metric("Breaks completed", len(completed_entries))
        stat3.metric("Minutes outside", round(total_minutes))
        stat4.metric("Day streak", current_streak)
        st.caption("Progress is calculated from entries saved on this computer. Only entries saved after you mark a break complete count toward minutes, streaks, and the chart.")
        uncompleted_count = sum(1 for entry in entries if not entry.get("break_completed"))
        if uncompleted_count:
            st.info(f"{uncompleted_count} saved observation(s) are journal-only because the break wasn't marked complete. They're kept here and won't be counted as outdoor time.")

        # Keep the dates as actual dates so Streamlit plots them chronologically
        # rather than sorting weekday labels alphabetically.
        import pandas as pd

        week_start = today - timedelta(days=6)
        daily_minutes = {week_start + timedelta(days=i): 0.0 for i in range(7)}
        for entry in completed_entries:
            stamp = entry.get("break_completed_at") or entry.get("saved_at", "")
            try:
                day = datetime.fromisoformat(stamp).astimezone().date()
                if day in daily_minutes:
                    daily_minutes[day] += float(entry.get("elapsed_minutes") or 0)
            except (TypeError, ValueError):
                continue
        st.markdown("**Your last 7 days**")
        chart_data = pd.DataFrame({
            "Date": [pd.Timestamp(day) for day in daily_minutes],
            "Minutes outside": [round(minutes, 1) for minutes in daily_minutes.values()],
        })
        st.bar_chart(chart_data, x="Date", y="Minutes outside", x_label="Day", y_label="Minutes outside", use_container_width=True)
        if not any(daily_minutes.values()):
            st.info("No completed breaks recorded yet. Start a break, return using the completion button, then save an observation. Your first completed break will appear here.")

        st.markdown("**Your observations**")
        for entry in reversed(entries):
            readable_time = format_saved_at(entry.get("saved_at", ""))
            st.markdown(f"**{readable_time} · {entry.get('place', 'Outdoor')}**")
            st.write(entry.get("observation", ""))
            if entry.get("break_completed"):
                elapsed = entry.get("elapsed_minutes")
                st.caption(f"Break completed · {elapsed if elapsed is not None else 'time not recorded'} minutes")
            else:
                st.caption("Observation saved · break completion not recorded")
            with st.expander("View mission"):
                st.markdown(entry.get("mission", ""))
            st.divider()

with st.expander("About this project"):
    st.write("Offscreen is a student-built experiment in using an open-weight language model to encourage short, real-world nature breaks.")
    st.write("The local model suggests one small observation idea. Python then places it in a consistent mission format, because tiny local models can produce messy lists or incorrect details when asked to write everything at once.")
    st.write("The model runs through Ollama on your own computer. Your journal is stored in a local JSON file. The app itself does not send journal entries to a cloud service.")
    st.write("For safety, stick to public and familiar places, stay aware of traffic, and do not touch or eat unknown plants or disturb wildlife.")

st.caption("A small reminder: the app's job is to get you outside, not keep you here.")
st.markdown("Built by [@ouuwz on GitHub](https://github.com/ouuwz) · [@ouuwz on Telegram](https://t.me/ouuwz)")
