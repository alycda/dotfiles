# Hermes Profile Setup for Cross-Provider Mode B

One-time setup. Required only if you want Mode B (cross-provider diversity) in Step 1.5. Mode C (Anthropic-only multi-perspective) works without any of this.

## What you're creating

Two **worker profiles** alongside your default Anthropic profile. Each is a fully independent Hermes home directory with its own provider, credentials, sessions, and memory.

```
~/.hermes/                              # default profile (Anthropic Enterprise)
├── profiles/
│   ├── researcher-codex/               # worker #1 (OpenAI Codex)
│   └── researcher-gemini/              # worker #2 (Google Gemini)
```

Your default profile stays untouched.

## Worker #1 — Codex

```bash
# Outside any Hermes session:
hermes profile create researcher-codex
researcher-codex setup
```

Inside the setup wizard:

1. Pick **"OpenAI Codex"** from the provider list.
2. Device-code OAuth flow opens — Hermes prints a URL and a short code.
3. **If you already have `~/.codex/auth.json`** from the Codex CLI, the wizard offers to import it. Say yes — saves you the OAuth round trip.
4. Otherwise: open the URL, paste the code, sign in with the OpenAI account that has Codex access.
5. When asked, set Codex as the **main provider for this profile** (yes — for worker profiles you DO want this, unlike when adding providers to your default profile).

Verify:

```bash
researcher-codex chat -q "what model are you?"
# Should identify as Codex / GPT
```

## Worker #2 — Gemini (API-key path, lowest policy risk)

The OAuth path (`google-gemini-cli`) violates Google's policy when used by third-party software. The API-key path (`gemini`) uses Google AI Studio with your own credential — no policy issue.

### Get an API key

1. Open https://aistudio.google.com/apikey
2. Sign in with the Google account you want to bill against
3. Click "Create API key"
4. Copy the value (`AIzaSy...`)

### Configure the profile

```bash
hermes profile create researcher-gemini

# Add the key to the profile's .env (NOT the default profile's)
echo 'GEMINI_API_KEY=AIzaSy...' >> ~/.hermes/profiles/researcher-gemini/.env

researcher-gemini setup
```

Inside the setup wizard:

1. Pick **"Google AI Studio (Gemini models — native Gemini API)"** — this is the API-key entry. (Older docs call this "Google / Gemini"; same provider ID `gemini`, the wizard label was clarified.) Do NOT pick "Google Gemini (OAuth)" / `google-gemini-cli` — that's the policy-flagged path.
2. The wizard detects the env var; no browser flow needed.
3. Set Gemini as the main provider for this profile.

**Other entries in the wizard you'll see and should skip for this purpose:**

- *"Custom endpoint (enter URL manually)"* — for OpenAI-compatible third-party endpoints (Together, Groq, LiteLLM proxy, self-hosted vLLM). Not what you want here.
- *"Configure auxiliary models..."* — for compression, vision, web summarization, and similar side tasks. Auxiliary tasks default to "auto" (use main model), which is fine — leave alone unless you want a cheaper/faster model for those specifically.

Verify:

```bash
researcher-gemini chat -q "what model are you?"
# Should identify as Gemini, no policy warnings
```

### If you want OAuth instead anyway

If you accept the policy risk and want the OAuth path (e.g., for free-tier quota generosity):

```bash
researcher-gemini setup
# → pick "Google Gemini (OAuth)"
# → confirm policy warning
# → browser opens; sign in
```

Provider ID becomes `google-gemini-cli` instead of `gemini`. Functionally equivalent for our purposes.

## Verify all three profiles

```bash
hermes profile list
# Expected output:
#   default            (anthropic)
#   researcher-codex   (codex)
#   researcher-gemini  (gemini)

# Smoke-test each
hermes chat -q "what model are you?"                    # → claude
researcher-codex chat -q "what model are you?"          # → codex/gpt
researcher-gemini chat -q "what model are you?"         # → gemini
```

If `hermes profile list` doesn't show all three, the profile creation didn't complete cleanly — re-run the create + setup steps for the missing one.

## Web Search Backend (required for the Anthropic worker)

Hermes's `web_search` and `web_extract` tools require an external backend provider. Without one, the Anthropic-side worker silently falls back to training-corpus knowledge — it has nothing to search with. (Codex and Gemini workers use their provider's native browsing and are unaffected.)

### Pick a backend

| Backend | Cost | Capabilities | Best for |
|---|---|---|---|
| **Tavily** | Free 1000/mo, then pay-per-call | Search + extract | Default recommendation — single backend covers both, generous free tier |
| **SearXNG** (self-hosted) | Free | Search only | Privacy-focused users with docker; pair with Tavily/Firecrawl for extract |
| **Firecrawl** | Free 500/mo, paid above | Search + extract + crawl | If you also want to crawl docs sites |
| **Exa** | Pay-per-call (~$0.005/search) | Search + extract | If you want category filters (research paper, news, etc.) |
| **Parallel** | Pay-per-call | Search + extract | Less common; specific agentic search modes |
| **Nous Tool Gateway** | Bundled with paid Nous Portal subscription | All web tools + image gen + TTS + browser | If you already pay for Nous Portal |

### Setup — Tavily (recommended path)

```bash
# Get a key at https://tavily.com
echo 'TAVILY_API_KEY=tvly-...' >> ~/.hermes/.env
# Verify:
hermes tools | grep -A1 web_search
# Should now show web_search as available
```

Tavily is auto-detected as the backend when its key is present and no `web.backend` is explicitly set in config.yaml.

### Setup — SearXNG (free, self-hosted)

```bash
docker run -d --name searxng -p 8080:8080 searxng/searxng
echo 'SEARXNG_URL=http://localhost:8080' >> ~/.hermes/.env
# SearXNG is search-only; for extract you'll also need:
echo 'TAVILY_API_KEY=...' >> ~/.hermes/.env  # or another backend
# In config.yaml:
cat >> ~/.hermes/config.yaml <<EOF
web:
  search_backend: searxng
  extract_backend: tavily
EOF
```

### Verify before running researcher

```bash
hermes chat -q "test web_search('hermes agent') and report what URL was returned"
# Should return real URLs, not training-corpus guesses
```

If this returns no live URLs, the backend isn't wired correctly — fix before invoking `/researcher research --external`.

### Worker profile awareness

The default profile's `.env` is the only one that matters for the orchestrator's Mode C run (delegate_task inherits parent's env). For Mode B's worker profiles:

- `researcher-codex` and `researcher-gemini` profiles **do not need** a web backend — they use provider-native browsing
- They CAN have one configured as a fallback, but it's optional

So a minimal Mode B setup is: backend key in `~/.hermes/.env` (default profile only).

---

## Auth file locations (for debugging)

| Profile | Where credentials live |
|---|---|
| Default (Anthropic) | `~/.hermes/auth.json` (OAuth) or `~/.hermes/.env` (`ANTHROPIC_API_KEY`) |
| `researcher-codex` | `~/.hermes/profiles/researcher-codex/auth.json` |
| `researcher-gemini` | `~/.hermes/profiles/researcher-gemini/.env` (`GEMINI_API_KEY` or `GOOGLE_API_KEY`) |

## After setup

The researcher skill stays installed in your default profile only (`~/.hermes/skills/research/researcher/`). The worker profiles don't need their own copy — they're invoked one-shot via `hermes -p <profile> chat -q "..."` and read the brief directly from `RESEARCH-BRIEF.md` on disk.

## Updating later

If you rotate API keys or re-OAuth:

```bash
researcher-codex setup        # re-runs the wizard for that profile only
researcher-gemini setup
```

If you want to change the model within a worker profile (e.g., switch the codex profile from gpt-5 to gpt-5-codex):

```bash
researcher-codex config set model.default <new-model-id>
```

## Removing a profile

```bash
hermes profile delete researcher-codex
# → asks you to type the profile name to confirm
# → removes config, sessions, memory, the command alias, everything
```

Your default profile and other worker profiles are unaffected.

## Cost notes

- **Codex**: billed against your OpenAI account; each Mode B run = one full research execution on Codex
- **Gemini**: free tier covers small-volume use; pay-per-token beyond quotas (cheap)
- **Anthropic (default)**: billed against your Enterprise account as usual

A Mode B run = three concurrent research executions, one per provider. Roughly 3x the cost of a single research execution, but with cross-vendor diversity that's the whole point.
