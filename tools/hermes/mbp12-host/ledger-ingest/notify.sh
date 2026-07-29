#!/usr/bin/env bash
# Signal notification via `hermes send` (no LLM, no agent loop). Targets the
# Signal home channel (SIGNAL_HOME_CHANNEL in ~/.hermes/.env) — no number here.
exec /Users/alyssa/.local/bin/hermes send -t signal "$*"
