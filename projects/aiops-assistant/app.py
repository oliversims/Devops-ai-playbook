"""
AIOps Assistant — Streamlit Chat UI
Connects to AWS Bedrock Agent for root cause analysis.

Setup:
    1. pip install -r requirements.txt
    2. cp .env.example .env
    3. Fill in your values in .env
    4. streamlit run app.py

How this file works (high level):
    1. Load settings from .env (agent ID, region, optional AWS keys)
    2. Configure the Streamlit page and UI CSS
    3. Validate that BEDROCK_AGENT_ID and BEDROCK_AGENT_ALIAS_ID are set
    4. On each user message, call invoke_agent() → AWS Bedrock Agent → Lambdas
    5. Show the agent's reply in the chat UI
"""

import streamlit as st
import boto3
import uuid
import json
import os
from dotenv import load_dotenv

# =============================================================================
# STEP 1: Load configuration from .env (in this folder)
# =============================================================================
# load_dotenv() reads projects/aiops-assistant/.env into os.environ.
# See .env.example for the variables you need after running bedrock/deploy.ps1.
load_dotenv()

# AWS credentials — optional. Leave blank if you use `aws configure` or SSO;
# boto3 will pick up ~/.aws/credentials automatically.
AWS_ACCESS_KEY_ID = os.getenv("AWS_ACCESS_KEY_ID")
AWS_SECRET_ACCESS_KEY = os.getenv("AWS_SECRET_ACCESS_KEY")
AWS_SESSION_TOKEN = os.getenv("AWS_SESSION_TOKEN")  # only for temporary creds (SSO/MFA)

# Which AWS region hosts your Bedrock agent (must match deploy region).
# Reads AWS_REGION from .env; falls back to us-east-1 only if .env is missing that line.
AWS_REGION = os.getenv("AWS_REGION", "us-east-1")

# Which Bedrock agent to call — printed by bedrock/deploy.ps1 and verify-deploy.ps1.
AGENT_ID = os.getenv("BEDROCK_AGENT_ID")
AGENT_ALIAS_ID = os.getenv("BEDROCK_AGENT_ALIAS_ID")  # usually TSTALIASID (test alias)


# =============================================================================
# STEP 2: Streamlit page setup (title, icon, layout)
# =============================================================================
st.set_page_config(
    page_title="Kira — AIOps Assistant",
    page_icon=":material/support_agent:",
    layout="wide",
    initial_sidebar_state="collapsed",
)

# =============================================================================
# STEP 3: Custom CSS — clean dark ops UI (visual only, no logic)
# =============================================================================
st.markdown("""
<style>
    @import url('https://fonts.googleapis.com/css2?family=Inter:wght@400;500;600&family=IBM+Plex+Mono:wght@400;500&display=swap');

    :root {
        --bg: #0d1117;
        --bg-elevated: #161b22;
        --surface: #1c2128;
        --surface-hover: #21262d;
        --border: #30363d;
        --border-focus: #388bfd;
        --text: #e6edf3;
        --text-secondary: #8b949e;
        --text-muted: #6e7681;
        --accent: #388bfd;
        --accent-soft: rgba(56, 139, 253, 0.15);
        --user-bg: rgba(56, 139, 253, 0.08);
        --ok: #3fb950;
        --err: #f85149;
    }

    .stApp {
        background: var(--bg);
        color: var(--text);
    }

    [data-testid="stAppViewContainer"],
    [data-testid="stAppViewContainer"] > section,
    .main,
    .main .block-container {
        background: var(--bg) !important;
    }

    .block-container {
        max-width: 800px;
        padding-top: 4rem;
        padding-bottom: 8rem;
        overflow: visible !important;
    }

    /* Top bar */
    .topbar {
        display: flex;
        align-items: center;
        justify-content: space-between;
        padding: 0 0 1rem;
        margin-bottom: 1.5rem;
        border-bottom: 1px solid var(--border);
        overflow: visible;
    }
    .topbar-left {
        display: flex;
        align-items: center;
        gap: 0.75rem;
    }
    .topbar-mark {
        width: 36px;
        height: 36px;
        border-radius: 8px;
        background: var(--accent);
        color: #fff;
        font-family: 'Inter', sans-serif;
        font-weight: 600;
        font-size: 0.875rem;
        display: flex;
        align-items: center;
        justify-content: center;
        flex-shrink: 0;
    }
    .topbar-title {
        font-family: 'Inter', sans-serif;
        font-size: 1rem;
        font-weight: 600;
        color: var(--text);
        margin: 0;
        line-height: 1.3;
    }
    .topbar-sub {
        font-family: 'Inter', sans-serif;
        font-size: 0.8125rem;
        color: var(--text-secondary);
        margin: 0;
    }
    .topbar-status {
        display: flex;
        align-items: center;
        gap: 0.375rem;
        font-family: 'Inter', sans-serif;
        font-size: 0.75rem;
        font-weight: 500;
        color: var(--text-secondary);
    }
    .topbar-status .dot {
        width: 6px;
        height: 6px;
        border-radius: 50%;
        background: var(--ok);
    }

    /* Welcome */
    .welcome-box {
        background: var(--bg-elevated);
        border: 1px solid var(--border);
        border-radius: 12px;
        padding: 2rem 1.5rem;
        margin-bottom: 1.25rem;
        text-align: center;
    }
    .welcome-box h2 {
        font-family: 'Inter', sans-serif;
        font-size: 1.0625rem;
        font-weight: 600;
        color: var(--text);
        margin: 0 0 0.5rem;
    }
    .welcome-box p {
        font-family: 'Inter', sans-serif;
        font-size: 0.875rem;
        color: var(--text-secondary);
        margin: 0 auto;
        max-width: 440px;
        line-height: 1.55;
    }

    /* Prompt chips label */
    .chips-label {
        font-family: 'Inter', sans-serif;
        font-size: 0.6875rem;
        font-weight: 500;
        text-transform: uppercase;
        letter-spacing: 0.05em;
        color: var(--text-muted);
        margin-bottom: 0.5rem;
    }

    /* Chat messages */
    [data-testid="stChatMessage"] {
        background: transparent !important;
        border: none !important;
        padding: 0.5rem 0 !important;
        max-width: 100% !important;
    }
    [data-testid="stChatMessage"] > div {
        max-width: 100% !important;
        min-width: 0 !important;
    }
    [data-testid="stChatMessage"] [data-testid="chatAvatarIcon-user"],
    [data-testid="stChatMessage"] [data-testid="chatAvatarIcon-assistant"] {
        width: 28px !important;
        height: 28px !important;
        min-width: 28px !important;
        border-radius: 6px !important;
        background: var(--surface) !important;
        border: 1px solid var(--border) !important;
    }
    [data-testid="stChatMessage"]:has([data-testid="chatAvatarIcon-user"]) [data-testid="chatAvatarIcon-user"] {
        background: var(--accent-soft) !important;
        border-color: rgba(56, 139, 253, 0.35) !important;
    }
    [data-testid="stChatMessage"] [data-testid="stMarkdownContainer"] {
        background: var(--bg-elevated) !important;
        border: 1px solid var(--border) !important;
        border-radius: 10px !important;
        padding: 0.875rem 1rem !important;
        font-family: 'Inter', sans-serif !important;
        font-size: 0.875rem !important;
        line-height: 1.6 !important;
        color: var(--text) !important;
        max-width: 100% !important;
        overflow-x: auto !important;
        overflow-wrap: anywhere !important;
        word-break: break-word !important;
    }
    [data-testid="stChatMessage"]:has([data-testid="chatAvatarIcon-user"]) [data-testid="stMarkdownContainer"] {
        background: var(--user-bg) !important;
        border-color: rgba(56, 139, 253, 0.2) !important;
    }
    [data-testid="stChatMessage"]:has([data-testid="chatAvatarIcon-assistant"]) [data-testid="stMarkdownContainer"] {
        border-left: 2px solid var(--accent) !important;
    }
    [data-testid="stChatMessage"] p,
    [data-testid="stChatMessage"] li,
    [data-testid="stChatMessage"] span {
        color: var(--text) !important;
    }
    [data-testid="stChatMessage"] code {
        background: var(--surface) !important;
        color: #79c0ff !important;
        border: 1px solid var(--border) !important;
        border-radius: 4px !important;
        font-family: 'IBM Plex Mono', monospace !important;
        font-size: 0.8125rem !important;
        padding: 0.1rem 0.35rem !important;
        white-space: pre-wrap !important;
        word-break: break-word !important;
        overflow-wrap: anywhere !important;
    }
    [data-testid="stChatMessage"] pre {
        background: var(--surface) !important;
        border: 1px solid var(--border) !important;
        border-radius: 6px !important;
        padding: 0.75rem !important;
        margin: 0.5rem 0 !important;
        max-width: 100% !important;
        overflow-x: auto !important;
        white-space: pre-wrap !important;
        word-break: break-word !important;
    }
    [data-testid="stChatMessage"] pre code {
        background: transparent !important;
        border: none !important;
        padding: 0 !important;
        color: #e6edf3 !important;
        white-space: pre-wrap !important;
        word-break: break-word !important;
        display: block !important;
    }
    [data-testid="stChatMessage"] [data-testid="stCodeBlock"] {
        max-width: 100% !important;
        overflow-x: auto !important;
    }
    [data-testid="stChatMessage"] [data-testid="stCodeBlock"] pre,
    [data-testid="stChatMessage"] [data-testid="stCodeBlock"] code {
        background: var(--surface) !important;
        color: #e6edf3 !important;
        white-space: pre-wrap !important;
        word-break: break-word !important;
    }

    /* Chat input — full-width bar and input field */
    [data-testid="stBottomBlockContainer"] {
        max-width: 100% !important;
        width: 100% !important;
        padding: 0.75rem 1.5rem 1.25rem !important;
        background: var(--bg) !important;
        border-top: 1px solid var(--border) !important;
    }
    [data-testid="stBottomBlockContainer"] > div,
    [data-testid="stBottomBlockContainer"] section {
        max-width: 100% !important;
        width: 100% !important;
        margin: 0 !important;
        padding: 0 !important;
        background: transparent !important;
    }
    [data-testid="stChatInput"],
    [data-testid="stChatInput"] > div,
    [data-testid="stChatInput"] [data-baseweb="base-input"],
    .stChatInput,
    .stChatInput > div {
        width: 100% !important;
        max-width: 100% !important;
        background: var(--surface) !important;
        background-color: var(--surface) !important;
        border: 1px solid var(--border) !important;
        border-radius: 12px !important;
        box-shadow: 0 2px 8px rgba(0, 0, 0, 0.2) !important;
        min-height: 52px !important;
        align-items: center !important;
    }
    [data-testid="stChatInput"] [data-baseweb="textarea"] {
        background: transparent !important;
        padding: 0 !important;
        margin: 0 !important;
    }
    [data-testid="stChatInput"]:focus-within,
    [data-testid="stChatInput"]:focus-within > div,
    [data-testid="stChatInput"]:focus-within [data-baseweb="base-input"] {
        border-color: var(--border-focus) !important;
        box-shadow: 0 0 0 3px var(--accent-soft), 0 2px 8px rgba(0, 0, 0, 0.2) !important;
    }
    [data-testid="stChatInput"] textarea,
    [data-testid="stChatInput"] [data-baseweb="textarea"] textarea,
    .stChatInput textarea {
        font-family: 'Inter', sans-serif !important;
        background: transparent !important;
        background-color: transparent !important;
        color: var(--text) !important;
        -webkit-text-fill-color: var(--text) !important;
        caret-color: var(--accent) !important;
        border: none !important;
        font-size: 0.9375rem !important;
        line-height: 1.5 !important;
        padding: 14px 48px 14px 16px !important;
        min-height: 24px !important;
        box-sizing: border-box !important;
        resize: none !important;
    }
    [data-testid="stChatInput"] textarea::placeholder,
    [data-testid="stChatInput"] [data-baseweb="textarea"] textarea::placeholder {
        color: var(--text-muted) !important;
        -webkit-text-fill-color: var(--text-muted) !important;
        opacity: 1 !important;
    }
    [data-testid="stChatInput"] button {
        margin-right: 8px !important;
        align-self: center !important;
    }
    [data-testid="stChatInput"] button,
    [data-testid="stChatInput"] button svg {
        color: var(--accent) !important;
        fill: var(--accent) !important;
    }

    /* Buttons → compact chips */
    .stButton > button {
        width: 100%;
        background: var(--bg-elevated) !important;
        border: 1px solid var(--border) !important;
        color: var(--text-secondary) !important;
        font-family: 'Inter', sans-serif !important;
        font-size: 0.8125rem !important;
        font-weight: 400 !important;
        padding: 0.5rem 0.75rem !important;
        border-radius: 8px !important;
        box-shadow: none !important;
        transition: background 0.15s, border-color 0.15s, color 0.15s !important;
    }
    .stButton > button:hover {
        background: var(--surface-hover) !important;
        border-color: var(--accent) !important;
        color: var(--text) !important;
        transform: none !important;
    }

    /* Sidebar */
    [data-testid="stSidebar"] {
        background: var(--bg-elevated);
        border-right: 1px solid var(--border);
    }
    [data-testid="stSidebar"] .stMarkdown,
    [data-testid="stSidebar"] p,
    [data-testid="stSidebar"] li {
        color: var(--text) !important;
        font-family: 'Inter', sans-serif !important;
        font-size: 0.8125rem !important;
    }
    [data-testid="stSidebar"] h3 {
        font-family: 'Inter', sans-serif !important;
        font-size: 0.9375rem !important;
        font-weight: 600 !important;
        color: var(--text) !important;
    }
    [data-testid="stSidebar"] hr {
        border-color: var(--border) !important;
        margin: 0.75rem 0 !important;
    }
    .sidebar-meta {
        font-family: 'IBM Plex Mono', monospace;
        font-size: 0.6875rem;
        color: var(--text-muted);
        line-height: 1.7;
    }
    .sidebar-label {
        font-size: 0.6875rem;
        font-weight: 500;
        text-transform: uppercase;
        letter-spacing: 0.05em;
        color: var(--text-muted);
        margin: 0.75rem 0 0.375rem;
    }

    .stSpinner > div { border-top-color: var(--accent) !important; }
    [data-testid="stSpinner"] p { color: var(--text-secondary) !important; font-size: 0.8125rem !important; }

    ::-webkit-scrollbar { width: 6px; }
    ::-webkit-scrollbar-track { background: transparent; }
    ::-webkit-scrollbar-thumb { background: var(--border); border-radius: 3px; }

    #MainMenu { visibility: hidden; }
    footer { visibility: hidden; }
    header[data-testid="stHeader"] {
        background: var(--bg) !important;
        border-bottom: 1px solid var(--border) !important;
    }
    [data-testid="stToolbar"] { display: none; }
</style>
""", unsafe_allow_html=True)


# =============================================================================
# STEP 4: Validate config — agent ID + alias are required; AWS keys are not
# =============================================================================
config_ok = bool(AGENT_ID and AGENT_ALIAS_ID)


# =============================================================================
# STEP 5: Session state — persists while the browser tab stays open
# =============================================================================
# messages: chat history shown in the UI
# session_id: sent to Bedrock so the agent remembers context within this tab
if "messages" not in st.session_state:
    st.session_state.messages = []
if "session_id" not in st.session_state:
    st.session_state.session_id = str(uuid.uuid4())


# =============================================================================
# STEP 6: AWS Bedrock client — talks to your deployed agent in the cloud
# =============================================================================
@st.cache_resource
def get_bedrock_client():
    """Create one boto3 client per app run (cached so we don't reconnect every message)."""
    kwargs = {"service_name": "bedrock-agent-runtime", "region_name": AWS_REGION}
    # Only pass explicit keys if set in .env; otherwise boto3 uses ~/.aws/credentials.
    if AWS_ACCESS_KEY_ID and AWS_SECRET_ACCESS_KEY:
        kwargs["aws_access_key_id"] = AWS_ACCESS_KEY_ID
        kwargs["aws_secret_access_key"] = AWS_SECRET_ACCESS_KEY
        if AWS_SESSION_TOKEN:
            kwargs["aws_session_token"] = AWS_SESSION_TOKEN
    return boto3.client(**kwargs)


def invoke_agent(prompt: str) -> str:
    """
    Send the user's question to the Bedrock Agent and return the full reply.

    Flow: this function → Bedrock Agent (OPBV8LHZCG) → action groups → Lambdas
          (fetch_logs, fetch_metrics, fetch_health) → agent synthesizes answer.
    """
    client = get_bedrock_client()

    try:
        # invoke_agent streams back events; we collect text chunks into one string.
        response = client.invoke_agent(
            agentId=AGENT_ID,
            agentAliasId=AGENT_ALIAS_ID,
            sessionId=st.session_state.session_id,  # same ID = multi-turn conversation
            inputText=prompt,
        )

        full_response = ""
        for event in response["completion"]:
            if "chunk" in event:
                chunk = event["chunk"]
                if "bytes" in chunk:
                    full_response += chunk["bytes"].decode("utf-8")

        return full_response

    except Exception as e:
        return f"Error: {str(e)}"


# =============================================================================
# STEP 7: Render UI — header, status, chat, sidebar
# =============================================================================

# --- Header ---
status_html = (
    '<div class="topbar-status"><span class="dot"></span>Connected</div>'
    if config_ok
    else '<div class="topbar-status" style="color:var(--err)">Not configured</div>'
)
st.markdown(f"""
<div class="topbar">
    <div class="topbar-left">
        <div class="topbar-mark">K</div>
        <div>
            <p class="topbar-title">Kira</p>
            <p class="topbar-sub">AIOps incident assistant</p>
        </div>
    </div>
    {status_html}
</div>
""", unsafe_allow_html=True)


# --- Config error screen ---
if not config_ok:
    st.error("Missing Bedrock agent settings. Create a `.env` file with at least:")
    st.code("""AWS_REGION=us-east-1
BEDROCK_AGENT_ID=your_agent_id
BEDROCK_AGENT_ALIAS_ID=TSTALIASID

# Optional (omit to use AWS CLI profile / SSO / role):
# AWS_ACCESS_KEY_ID=...
# AWS_SECRET_ACCESS_KEY=...
# AWS_SESSION_TOKEN=...  # only for temporary credentials""", language="bash")
    st.stop()


# --- Empty state + suggested prompts (hidden once chat starts) ---
if not st.session_state.messages:
    st.markdown("""
    <div class="welcome-box">
        <h2>What would you like to investigate?</h2>
        <p>Ask about errors, latency, CPU, or service health. Kira queries your logs,
        metrics, and cluster state to help identify root cause.</p>
    </div>
    """, unsafe_allow_html=True)

    st.markdown('<p class="chips-label">Suggested prompts</p>', unsafe_allow_html=True)
    col1, col2, col3, col4 = st.columns(4)
    with col1:
        if st.button("503 errors", key="qa1"):
            st.session_state.quick_action = "Why are we seeing 503 errors in the last hour?"
    with col2:
        if st.button("CPU & memory", key="qa2"):
            st.session_state.quick_action = "Check CPU and memory utilization across all services"
    with col3:
        if st.button("Database health", key="qa3"):
            st.session_state.quick_action = "Is the database healthy? Check connections and latency"
    with col4:
        if st.button("Recent errors", key="qa4"):
            st.session_state.quick_action = "What are the most frequent errors in the last hour?"
    st.markdown("<div style='height:1rem'></div>", unsafe_allow_html=True)


# --- Redraw previous messages ---
for message in st.session_state.messages:
    with st.chat_message(message["role"]):
        st.markdown(message["content"])


# --- Pick up quick-action prompt if a button was clicked this rerun ---
quick_action = st.session_state.pop("quick_action", None)


# --- Chat input box at the bottom ---
user_input = st.chat_input("Ask about an incident...")

# Use quick-action text if set, otherwise what the user typed
prompt = quick_action or user_input

if prompt:
    # 1. Show the user's message immediately
    st.session_state.messages.append({"role": "user", "content": prompt})
    with st.chat_message("user"):
        st.markdown(prompt)

    # 2. Call Bedrock Agent and show the reply (may take 30–60s while Lambdas run)
    with st.chat_message("assistant"):
        with st.spinner("Investigating..."):
            response = invoke_agent(prompt)
        st.markdown(response)

    # 3. Save assistant reply so it appears on the next rerun
    st.session_state.messages.append({"role": "assistant", "content": response})


# --- Sidebar — info panel + "New Session" to clear chat and start fresh ---
with st.sidebar:
    st.markdown("### Kira")
    st.caption("AIOps incident assistant")

    st.markdown('<p class="sidebar-label">Connection</p>', unsafe_allow_html=True)
    st.markdown(f"""<div class="sidebar-meta">
    Region &nbsp; {AWS_REGION}<br>
    Agent &nbsp;&nbsp; {AGENT_ID}<br>
    Session {st.session_state.session_id[:8]}
    </div>""", unsafe_allow_html=True)

    st.markdown('<p class="sidebar-label">Data sources</p>', unsafe_allow_html=True)
    st.markdown("""
    - CloudWatch Logs
    - CloudWatch Metrics
    - EKS cluster health
    """)

    st.markdown('<p class="sidebar-label">Examples</p>', unsafe_allow_html=True)
    st.markdown("""
    - Why are we seeing 503 errors?
    - Is CPU usage high on any pod?
    - Check database connection pool
    - Are all services healthy?
    """)

    st.markdown("---")
    if st.button("New session", key="new_session"):
        st.session_state.messages = []
        st.session_state.session_id = str(uuid.uuid4())  # new Bedrock conversation
        st.rerun()
