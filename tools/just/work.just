# Load .env from the justfile dir (CASPER_API_KEY, DITTO_LICENSE, ...) into
# recipe environments. Shell-exported vars still win over .env values.
set dotenv-load := true

[working-directory: 'main']
help:
    make help

# Shared ticket-protocol suffix appended to the prompt by `chat` and
# `chat-casper` — keep them from drifting by editing only here.
chat_protocol := "Follow the 'Starting work on a ticket' protocol in CLAUDE.md. Before you stop for any reason, record your terminal state in taskbook so the board is authoritative without anyone reading this log: when the PR is open, mark complete per the 'Closing the loop' protocol (tb-ticket complete); if you are paused waiting on my approval, permission, or an answer (not truly stuck), run tb-ticket needs-input TICKET-NNNN with a one-line reason; if you are truly stuck, run tb-ticket block TICKET-NNNN with a one-line reason. Then, as the very last line of your final message, also emit a machine-readable status sentinel on its own line in exactly this form: '::STATUS:: <state> — <detail>' where <state> is one of done|needs-input|blocked — use 'done' with the PR url as <detail> when a PR is open, 'needs-input' with a short reason when you are waiting on my approval or an answer, and 'blocked' with a one-line reason otherwise."

# starts work in headless mode, will exit when done but can resume with `claude -c` with optional "next prompt", also can resume from VSCode panel
# logs to .agent-logs/<TICKET>.out (e.g. .agent-logs/TICKET-1234.out) so parallel runs don't collide on shared nohup.out
# writes .agent-logs/<TICKET>.pid so `just -g status` can distinguish a running agent from a finished one
chat prompt:
    #!/usr/bin/env bash
    set -euo pipefail
    mkdir -p .agent-logs
    ticket=$(echo "{{prompt}}" | grep -oE '^[A-Z]+-[0-9]+' || echo "chat-$(date +%Y%m%d-%H%M%S)")
    log=".agent-logs/${ticket}.out"
    nohup claude --model opus --permission-mode acceptEdits -p "{{prompt}}. {{chat_protocol}}" > "$log" 2>&1 &
    pid=$!
    echo "$pid" > ".agent-logs/${ticket}.pid"
    echo "Started agent for ${ticket} (PID $pid) → just -g status  (or tail -f ${log})"

# Same as `just -g chat`, but drives Codex. It deliberately follows AGENTS.md rather
# than inheriting Claude's permissions or Taskbook/worktree protocol. The current
# workspace parent is not a Git worktree, so the agent uses the ticket worktree
# for implementation, creating one from the Linear branch when it does not exist.
# Resume interactively with `codex resume --last`.
# `--disable code_mode_host` works around the 0.144.0 Homebrew cask shipping the feature stable-on
# without the sidecar `codex-code-mode-host` binary; drop the flag once the cask packages it.
chatgpt prompt:
    #!/usr/bin/env bash
    set -euo pipefail
    mkdir -p .agent-logs
    ticket=$(echo "{{prompt}}" | grep -oE '^[A-Z]+-[0-9]+' || echo "chat-$(date +%Y%m%d-%H%M%S)")
    log=".agent-logs/${ticket}.out"
    model="${CODEX_MODEL:-gpt-5.5}"
    printf '%s\n' codex > ".agent-logs/${ticket}.runner"
    agent_prompt="{{prompt}}"$'\n\n'"You are the headless Codex runner for ${ticket}. Read AGENTS.md and any scoped instructions before acting. Follow the Codex ticket workflow in AGENTS.md, not the Claude ticket protocol."$'\n\n'"For implementation, use the ticket worktree at ${ticket}/. If it does not exist, create it from the Linear branch with 'just -g new ${ticket} <linear-branch>'. Do not substitute main or invent a branch. Before any visible GitHub or Linear message, show its body and wait for approval."$'\n\n'"As the final line of your response, emit exactly one machine-readable sentinel: ::STATUS:: <state> — <detail>. Use done only when a PR is open; use needs-input for an approval or answer you need from the user; use blocked for a concrete environmental or technical blocker."
    nohup codex exec --disable code_mode_host -m "$model" -s workspace-write --add-dir "$PWD/.bare" --add-dir "$HOME/.taskbook" --add-dir "$HOME/.taskbook-journals" --add-dir "$HOME/.config" --skip-git-repo-check "$agent_prompt" > "$log" 2>&1 &
    pid=$!
    echo "$pid" > ".agent-logs/${ticket}.pid"
    echo "Started codex agent (${model}) for ${ticket} (PID $pid) → tail -f ${log}"

# Dashboard of headless agents. Legacy Claude runs may still use Taskbook; Codex
# runs use their final sentinel and runner marker as the authoritative state.
status:
    #!/usr/bin/env python3
    import glob, json, os, re, subprocess, time
    STORAGE = os.path.expanduser('~/.taskbook/storage/storage.json')
    JOURNALS = os.path.expanduser('~/.taskbook-journals')
    LOGS = '.agent-logs'
    def runner(ticket):
        p = os.path.join(LOGS, ticket + '.runner')
        try:
            value = open(p).read().strip()
            return value if value in ('claude', 'codex') else 'claude'
        except Exception:
            return 'claude'
    def resume(ticket):
        return 'codex resume --last' if runner(ticket) == 'codex' else f'cd {ticket} && claude -c'
    def taskbook_state():
        out = {}
        try:
            d = json.load(open(STORAGE))
        except Exception:
            return out
        for v in d.values():
            if isinstance(v, dict) and v.get('_isTask'):
                m = re.match(r'([A-Z]+-\d+)', v.get('description', ''))
                if m:
                    boards = v.get('boards', [])
                    out[m.group(1)] = {'done': bool(v.get('isComplete')), 'blocked': '@blocked' in boards, 'needs_input': '@needs-input' in boards}
        return out
    def journal_pr(ticket):
        p = os.path.join(JOURNALS, ticket + '.md')
        if not os.path.exists(p):
            return None
        text = open(p).read()
        # prefer the PR on the authoritative handoff line, not a sibling PR cited in a comment
        for line in text.splitlines():
            if ('PR opened' in line or 'Complete —' in line) and 'pull/' in line:
                m = re.search(r'pull/(\d+)', line)
                if m:
                    return m.group(1)
        nums = re.findall(r'pull/(\d+)', text)
        return nums[-1] if nums else None
    def journal_reason(ticket, prefix):
        p = os.path.join(JOURNALS, ticket + '.md')
        if os.path.exists(p):
            hits = [l for l in open(p).read().splitlines() if prefix in l]
            if hits:
                return hits[-1].split(prefix, 1)[1].strip()
        return ''
    def alive(ticket):
        # verify the PID's command still matches this ticket — PIDs get recycled, so existence alone lies
        pidf = os.path.join(LOGS, ticket + '.pid')
        if os.path.exists(pidf):
            try:
                pid = int(open(pidf).read().strip())
                os.kill(pid, 0)
                cmd = subprocess.run(['ps', '-p', str(pid), '-o', 'command='], capture_output=True, text=True).stdout
                if runner(ticket) in cmd and re.search(re.escape(ticket) + r'(?!\d)', cmd):
                    return True
            except Exception:
                pass
        try:
            r = subprocess.run(['pgrep', '-fl', runner(ticket)], capture_output=True, text=True)
            return any(re.search(re.escape(ticket) + r'(?!\d)', line) for line in r.stdout.splitlines())
        except Exception:
            return False
    def sentinel(log):
        try:
            txt = open(log).read()
        except Exception:
            return None
        ms = re.findall(r'::STATUS::\s*(done|needs-input|blocked)\b\s*[—-]*\s*(.*)', txt)
        return ms[-1] if ms else None
    def last(log):
        return time.strftime('%m-%d %H:%M', time.localtime(os.path.getmtime(log)))
    tb = taskbook_state()
    logs = sorted(glob.glob(os.path.join(LOGS, '*.out')))
    if not logs:
        print(f'No agent logs ({LOGS}/*.out) found.')
        raise SystemExit
    done = []
    for log in logs:
        t = os.path.basename(log)[:-4]
        # A Codex runner marker opts into sentinel-only state. This prevents an
        # older Taskbook record for the same ticket from masking the current run.
        st = {} if runner(t) == 'codex' else tb.get(t, {})
        if st.get('done'):
            done.append((t, journal_pr(t)))
            continue
        if alive(t):
            print(f'🟢 {t:12} RUNNING')
            continue
        se = sentinel(log)
        # Taskbook is authoritative only for legacy Claude runs; Codex writes its
        # terminal state to the sentinel requested by the chatgpt recipe.
        if st.get('needs_input'):
            reason = journal_reason(t, 'Needs input — ') or (se[1] if se else '')
            print(f'⏸️  {t:12} NEEDS YOU  {reason} (last {last(log)}) → {resume(t)}')
            continue
        if st.get('blocked'):
            reason = journal_reason(t, 'Blocked — ') or (se[1] if se else '')
            print(f'⛔ {t:12} BLOCKED    {reason} (last {last(log)}) → {resume(t)}')
            continue
        if se:
            state, detail = se
            if state == 'needs-input':
                print(f'⏸️  {t:12} NEEDS YOU  {detail} (last {last(log)}) → {resume(t)}')
            elif state == 'blocked':
                print(f'⛔ {t:12} BLOCKED    {detail} (last {last(log)}) → {resume(t)}')
            elif state == 'done':
                if runner(t) == 'codex':
                    print(f'✅ {t:12} DONE      {detail}')
                else:
                    print(f'✅ {t:12} DONE?      {detail}  (sentinel says done but taskbook does not — run tb-ticket complete {t})')
            else:
                print(f'⚪ {t:12} {state:10} {detail} (last {last(log)})')
            continue
        txt = open(log).read()
        if re.search(r'github\.com/\S+/pull/\d+', txt):
            url = re.findall(r'https://github\.com/\S+/pull/\d+', txt)[-1]
            if runner(t) == 'codex':
                print(f'✅ {t:12} DONE?      {url}  (PR found in Codex log; no terminal sentinel)')
            else:
                print(f'✅ {t:12} DONE?      {url}  (PR in log but taskbook not complete — run tb-ticket complete {t})')
        elif re.search(r'requires approval|please approve|how would you like to proceed|blocked on|requires permission', txt, re.I):
            print(f'⏸️  {t:12} NEEDS YOU  (last {last(log)}) → {resume(t)}')
        else:
            print(f'⚪ {t:12} STOPPED    (last {last(log)}) → tail {log}')
    if done:
        labels = ', '.join(t + (f' (PR #{pr})' if pr else '') for t, pr in done)
        print(f'— {len(done)} done: {labels}  → `just -g sweep` to archive merged')

# archive run artifacts (.out/.pid) for tickets that are taskbook-complete AND whose
# PR is MERGED, moving them from .agent-logs/ into .agent-archive/. Reversible (move,
# not delete). A taskbook-complete ticket whose PR is still open/draft is kept, so you
# never lose an in-flight review. Also removes the merged ticket's git worktree — but
# ONLY if it is perfectly clean (no uncommitted or untracked changes); any dirt keeps
# the worktree and reports it.
sweep:
    #!/usr/bin/env python3
    import glob, json, os, re, subprocess, shutil
    STORAGE = os.path.expanduser('~/.taskbook/storage/storage.json')
    JOURNALS = os.path.expanduser('~/.taskbook-journals')
    LOGS, REPO, ARCHIVE = '.agent-logs', os.environ.get('DITTO_REPO', 'org/repo'), '.agent-archive'
    def taskbook_done():
        out = set()
        try:
            d = json.load(open(STORAGE))
        except Exception:
            return out
        for v in d.values():
            if isinstance(v, dict) and v.get('_isTask') and v.get('isComplete'):
                m = re.match(r'([A-Z]+-\d+)', v.get('description', ''))
                if m:
                    out.add(m.group(1))
        return out
    def journal_pr(ticket):
        p = os.path.join(JOURNALS, ticket + '.md')
        if not os.path.exists(p):
            return None
        text = open(p).read()
        # prefer the PR on the authoritative handoff line, not a sibling PR cited in a comment
        for line in text.splitlines():
            if ('PR opened' in line or 'Complete —' in line) and 'pull/' in line:
                m = re.search(r'pull/(\d+)', line)
                if m:
                    return m.group(1)
        nums = re.findall(r'pull/(\d+)', text)
        return nums[-1] if nums else None
    def pr_state(ticket, num):
        # returns 'merged' | 'unmerged' | 'mismatch' | None(gh error).
        # 'mismatch' guards the destructive move: the journal PR# must belong to THIS ticket
        # (Linear branch carries the ticket id, e.g. alycda/sdks-3976-...), not a sibling cited in a comment.
        try:
            r = subprocess.run(['gh', 'pr', 'view', num, '--repo', REPO, '--json', 'state,headRefName'], capture_output=True, text=True)
            if r.returncode != 0:
                return None
            d = json.loads(r.stdout)
            if ticket.lower() not in (d.get('headRefName') or '').lower():
                return 'mismatch'
            return 'merged' if d.get('state') == 'MERGED' else 'unmerged'
        except Exception:
            return None
    done = taskbook_done()
    archived, kept, removed_wt, kept_wt = [], [], [], []
    for log in sorted(glob.glob(os.path.join(LOGS, '*.out'))):
        t = os.path.basename(log)[:-4]
        if t not in done:
            continue
        pr = journal_pr(t)
        if not pr:
            kept.append(f'{t}: complete but no PR# in journal — kept')
            continue
        s = pr_state(t, pr)
        if s is None:
            kept.append(f'{t}: PR #{pr} state unknown (gh failed) — kept')
            continue
        if s == 'mismatch':
            kept.append(f'{t}: journal PR #{pr} does not belong to {t} — kept')
            continue
        if s != 'merged':
            kept.append(f'{t}: PR #{pr} not merged yet — kept')
            continue
        os.makedirs(ARCHIVE, exist_ok=True)
        for ext in ('.out', '.pid'):
            src = os.path.join(LOGS, t + ext)
            if os.path.exists(src):
                shutil.move(src, os.path.join(ARCHIVE, t + ext))
        archived.append(f'{t} (PR #{pr})')
        # strict worktree removal: only when the worktree is perfectly clean (no dirt at all)
        if os.path.isdir(t):
            stt = subprocess.run(['git', '-C', t, 'status', '--porcelain'], capture_output=True, text=True)
            if stt.returncode != 0:
                kept_wt.append(f'{t}: worktree status check failed — left in place')
            elif stt.stdout.strip():
                kept_wt.append(f'{t}: worktree has local changes — left in place (just -g del {t} to remove)')
            else:
                rm = subprocess.run(['git', '-C', 'main', 'worktree', 'remove', os.path.abspath(t)], capture_output=True, text=True)
                if rm.returncode == 0:
                    removed_wt.append(t)
                else:
                    kept_wt.append(f'{t}: worktree remove failed ({rm.stderr.strip()[:60]}) — left in place')
    for k in kept + kept_wt:
        print('•', k)
    print(f'📦 archived to {ARCHIVE}/: ' + ', '.join(archived) if archived else 'Nothing to archive.')
    if removed_wt:
        print('🌳 worktrees removed (were clean): ' + ', '.join(removed_wt))

# Reclaim memory from accumulated Dart tooling: the analysis servers (`dart
# language-server`), MCP servers (`dart mcp-server`), and custom_lint runners that
# every Claude Code panel/agent spawns. One per open session, they pile up across
# parallel worktrees (seen: 70 procs, multi-GB, some 6+ days old) and are the biggest
# reclaimable chunk when macOS throws "out of application memory". They are stateless
# caches — any still-live session transparently respawns its analysis server on the
# next Dart operation — so killing them is safe; it only frees what idle or
# closed-but-not-quit sessions leave resident. Matches ONLY the tooling processes, so a
# real `flutter run` / `dart run` app is never touched. There is deliberately NO
# per-ticket / taskbook-done targeting: every panel session runs with cwd = repo root
# and holds no worktree files open, so a dart PID cannot be attributed to a ticket —
# age is the only honest signal. Spares anything younger than <spare_min> minutes so a
# server you're actively waiting on isn't nuked mid-analyze. `just -g reap-dart 0` = all.
reap-dart spare_min='5':
    #!/usr/bin/env python3
    import re, os, signal, subprocess
    spare = int("{{spare_min}}") * 60
    pat = re.compile(r'dart (mcp-server|language-server)|custom_lint_client')
    def to_secs(e):
        days = 0
        if '-' in e:
            d, e = e.split('-', 1); days = int(d)
        p = [int(x) for x in e.split(':')]
        h, m, s = ([0] * (3 - len(p)) + p)
        return days * 86400 + h * 3600 + m * 60 + s
    out = subprocess.run(['ps', '-Ao', 'pid=,etime=,rss=,command='], capture_output=True, text=True).stdout
    victims = []
    for line in out.splitlines():
        parts = line.split(None, 3)
        if len(parts) < 4:
            continue
        pid, etime, rss, cmd = parts
        if not pat.search(cmd) or to_secs(etime) < spare:
            continue
        kind = 'lsp' if 'language-server' in cmd else ('mcp' if 'mcp-server' in cmd else 'lint')
        victims.append((int(pid), etime, int(rss), kind))
    if not victims:
        print(f'No Dart tooling older than {{spare_min}}m to reap.')
        raise SystemExit
    freed = 0
    for pid, etime, rss, kind in sorted(victims, key=lambda v: -v[2]):
        try:
            os.kill(pid, signal.SIGTERM)
            freed += rss
            print(f'  killed {kind:4} pid={pid:<7} age={etime:<12} {rss/1024/1024:.2f}GB')
        except ProcessLookupError:
            pass
        except PermissionError:
            print(f'  skip   {kind:4} pid={pid:<7} (permission denied)')
    print(f'♻️  reaped {len(victims)} Dart processes, ~{freed/1024/1024:.2f}GB resident. '
          f'Live sessions respawn their analysis server on next Dart use.')

kb title profile wt:
    hermes kanban create {{title}} --assignee {{profile}} --workspace dir:./{{wt}}

# pass data to claude from a file
hey-claude data prompt:
    cat {{data}} | claude -p {{prompt}}

# create new branch from main
new ticket branch:
    git worktree add -b {{branch}} {{ticket}} main

# checkout existing branch
old ticket branch:
    git worktree add {{ticket}} {{branch}}

del ticket:
    git worktree remove {{ticket}}

# Reclaim space by deleting git-ignored build artifacts in a worktree.
# Scoped to target/ (cargo workspace output), sdks/, downstream/, and crates/
# so root-level .envrc.override, .jj/, and .direnv/ are preserved. Removes only
# ignored files (target/debug/, Xcode DerivedData/, .xcframework/, node_modules/,
# etc.) — tracked files are never touched. Re-runnable; rebuild when you need
# the artifacts back.
clean dir='main':
    cd {{dir}} && git clean -fdX -- target/ sdks/ downstream/ crates/

rerun id:
    gh run rerun {{id}}

[working-directory: 'main']
build:
    make build-mac

build-all dir='main':
    cd {{dir}}
    make build-mac && make build-ios && make build-flutter 

[working-directory: 'main']
build-wasm:
    make -C examples/carsapp wasm

[working-directory: 'main']
build-flutter:
    make build-flutter-apple

test-flutter dir:
    cd {{dir}} && ./sdks/flutter/run.sh ci test --targets native

devices:
    flutter devices

# Copy expensive FFI build from main worktree to specified worktree
copy ticket:
    #!/usr/bin/env bash
    set -euo pipefail
    echo "Copying FFI build from main to {{ticket}}..."

    # Find the Rust target directory in main
    MAIN_TARGET="main/target"
    if [ ! -d "$MAIN_TARGET" ]; then
        echo "Error: main/target directory not found. Build FFI in main first with 'just -g build'"
        exit 1
    fi

    # Create target directory in destination worktree
    mkdir -p "{{ticket}}/target"

    # Copy the entire target directory (includes all architectures and profiles)
    echo "Copying target directory..."
    rsync -a --progress "$MAIN_TARGET/" "{{ticket}}/target/"

    echo "✓ FFI build copied to {{ticket}}/target"

    # Copy Flutter binaries if they exist
    if [ -d "main/sdks/flutter/ditto_live/macos/DittoCore.xcframework" ]; then
        echo "Copying Flutter macOS binaries..."
        mkdir -p "{{ticket}}/sdks/flutter/ditto_live/macos"
        rsync -a main/sdks/flutter/ditto_live/macos/DittoCore.xcframework/ "{{ticket}}/sdks/flutter/ditto_live/macos/DittoCore.xcframework/"
        echo "✓ Flutter macOS binaries copied"
    fi

    if [ -d "main/sdks/flutter/ditto_live/ios/DittoCore.xcframework" ]; then
        echo "Copying Flutter iOS binaries..."
        mkdir -p "{{ticket}}/sdks/flutter/ditto_live/ios"
        rsync -a main/sdks/flutter/ditto_live/ios/DittoCore.xcframework/ "{{ticket}}/sdks/flutter/ditto_live/ios/DittoCore.xcframework/"
        echo "✓ Flutter iOS binaries copied"
    fi

# Copy WASM builds specifically from main worktree to specified worktree
copy-wasm ticket:
    #!/usr/bin/env bash
    set -euo pipefail
    echo "Copying WASM builds from main to {{ticket}}..."

    # Copy carsapp WASM build
    if [ -f "main/examples/carsapp/wasm/carsapp.js" ]; then
        echo "Copying carsapp WASM..."
        mkdir -p "{{ticket}}/examples/carsapp/wasm"
        cp -v main/examples/carsapp/wasm/carsapp.js "{{ticket}}/examples/carsapp/wasm/"
        cp -v main/examples/carsapp/wasm/carsapp.wasm "{{ticket}}/examples/carsapp/wasm/"
        echo "✓ Carsapp WASM copied"
    else
        echo "Warning: main/examples/carsapp/wasm/carsapp.js not found"
        echo "Build WASM in main first with: cd main && make -C examples/carsapp wasm"
    fi

    # Copy vendor dependencies (cJSON, etc.)
    if [ -d "main/examples/carsapp/vendor" ]; then
        echo "Copying vendor dependencies..."
        mkdir -p "{{ticket}}/examples/carsapp"
        rsync -a main/examples/carsapp/vendor/ "{{ticket}}/examples/carsapp/vendor/"
        echo "✓ Vendor dependencies copied"
    fi

    # Copy local JS SDK build (v5.x) - requires full build for ditto.es6.js
    if [ -d "main/sdks/js/build/package/web" ]; then
        echo "Copying local Ditto JS SDK (v5.x)..."
        mkdir -p "{{ticket}}/examples/carsapp/wasm/ditto"
        rsync -a main/sdks/js/build/package/web/ "{{ticket}}/examples/carsapp/wasm/ditto/"
        echo "✓ Local JS SDK copied"
    elif [ -d "main/examples/carsapp/wasm/ditto" ]; then
        echo "Copying Ditto WASM files from wasm/ditto..."
        mkdir -p "{{ticket}}/examples/carsapp/wasm"
        rsync -a main/examples/carsapp/wasm/ditto/ "{{ticket}}/examples/carsapp/wasm/ditto/"
        echo "✓ Ditto WASM files copied"
    else
        echo "Warning: No JS SDK build found. Build it with: cd main/sdks/js && npx jake build:web variants=web"
    fi

    echo "✓ WASM builds copied to {{ticket}}"

# Run WASM Playwright tests in specified worktree (copies builds first)
test-wasm ticket:
    #!/usr/bin/env bash
    set -euo pipefail
    echo "Running WASM Playwright tests in {{ticket}}..."

    # Copy WASM builds if not present
    if [ ! -f "{{ticket}}/examples/carsapp/wasm/carsapp.js" ]; then
        echo "WASM build not found, copying from main..."
        just -g copy-wasm {{ticket}}
    fi

    # Install Playwright if not already installed
    if [ ! -d "{{ticket}}/examples/carsapp/wasm/tests/node_modules" ]; then
        echo "Installing Playwright..."
        cd "{{ticket}}/examples/carsapp/wasm/tests" && npm install
    fi

    # Run tests
    echo "Running Playwright tests..."
    cd "{{ticket}}/examples/carsapp/wasm/tests" && npm test

    echo "✓ WASM tests completed!"

# Install Playwright in specified worktree
install-playwright ticket:
    #!/usr/bin/env bash
    set -euo pipefail
    echo "Installing Playwright in {{ticket}}..."
    cd "{{ticket}}/examples/carsapp/wasm/tests"
    npm install
    npx playwright install --with-deps chromium
    echo "✓ Playwright installed in {{ticket}}"

push dir:
    cd {{dir}} && git push --no-verify

# ---------------------------------------------------------------------------
# Prebuilt libdittoffi fetch (mirrors PR #22526 — local until that PR lands)
#
# Resolves a published version from crates.io (override with DITTO_VERSION),
# downloads the prebuilt static lib from software.ditto.live, and caches it
# at ~/.cache/ditto/libdittoffi/{version}/{target}/ so all worktrees on the
# same version share one download. Use `just -g env <dir>` to print the shell
# exports needed to use the cached binary with plain cargo from a worktree.
# ---------------------------------------------------------------------------

base_url    := "https://software.ditto.live/rust/Ditto"
cache_root  := home_directory() / ".cache" / "ditto" / "libdittoffi"

# Resolve the best published libdittoffi version for a worktree.
# Order: exact patch → closest major.minor (incl. prereleases) → same-major stable.
# Override with DITTO_VERSION=x.y.z. dir defaults to 'main'.
resolve-version dir='main':
    #!/usr/bin/env bash
    set -euo pipefail
    if [[ -n "${DITTO_VERSION:-}" ]]; then
        echo "$DITTO_VERSION"
        exit 0
    fi
    python3 - "{{dir}}" <<'PY'
    import json, re, sys
    from pathlib import Path
    from urllib.request import Request, urlopen

    dir_arg = sys.argv[1]
    cargo_path = Path(dir_arg) / "sdks" / "rust" / "dittolive-ditto" / "Cargo.toml"
    m = re.search(r'version\s*=\s*"(\d+)\.(\d+)\.(\d+)', cargo_path.read_text())
    if not m:
        sys.exit(f"error: could not parse version from {cargo_path}")

    major, minor, patch = m.group(1), m.group(2), m.group(3)
    exact         = f"{major}.{minor}.{patch}"
    minor_prefix  = f"{major}.{minor}."
    major_prefix  = f"{major}."
    stable        = re.compile(r"^\d+\.\d+\.\d+$")

    req = Request(
        "https://crates.io/api/v1/crates/dittolive-ditto/versions",
        headers={"User-Agent": "ditto-justfile"},
    )
    versions = json.load(urlopen(req))["versions"]  # newest-first
    published = {v["num"] for v in versions if not v.get("yanked")}

    if exact in published:
        print(exact); sys.exit(0)
    for v in versions:
        if not v.get("yanked") and v["num"].startswith(minor_prefix):
            print(v["num"]); sys.exit(0)
    for v in versions:
        if not v.get("yanked") and v["num"].startswith(major_prefix) and stable.match(v["num"]):
            print(v["num"]); sys.exit(0)
    sys.exit(
        f"error: no published libdittoffi found for {major}.{minor}.x or {major}.x\n"
        f"Build locally with: cd {dir_arg} && make build-mac (or appropriate make build-*)"
    )
    PY

# Print resolved version, host target, and download URL for a worktree
info dir='main':
    #!/usr/bin/env bash
    set -euo pipefail
    version=$(just -g resolve-version {{dir}})
    host_target=$(rustc --print host-tuple)
    echo "worktree    : {{dir}}"
    echo "sdk_version : $version"
    echo "host_target : ${host_target}"
    echo "cache_dir   : {{cache_root}}/$version/${host_target}"
    echo "fetch_url   : {{base_url}}/$version/${host_target}/release/libdittoffi.a"

# Print shell exports for using the cached binary with plain cargo.
# Usage: eval "$(just -g env <dir>)" && cd <dir> && cargo check --manifest-path sdks/rust/dittolive-ditto/Cargo.toml
env dir='main':
    #!/usr/bin/env bash
    set -euo pipefail
    version=$(just -g resolve-version {{dir}})
    host_target=$(rustc --print host-tuple)
    echo "export DITTOFFI_SEARCH_PATH={{cache_root}}/$version/${host_target}"
    echo "export DITTO_LOCAL_BUILD=0"

# Fetch prebuilt libdittoffi.a for the host platform (no-op if cached)
fetch dir='main':
    #!/usr/bin/env bash
    set -euo pipefail
    version=$(just -g resolve-version {{dir}})
    host_target=$(rustc --print host-tuple)
    cache_dir="{{cache_root}}/$version/${host_target}"
    if [[ -f "$cache_dir/libdittoffi.a" ]]; then
        echo "Already cached: $cache_dir/libdittoffi.a"
        exit 0
    fi
    mkdir -p "$cache_dir"
    curl -fL --progress-bar \
        "{{base_url}}/$version/${host_target}/release/libdittoffi.a" \
        -o "$cache_dir/libdittoffi.a"
    echo "Saved to $cache_dir/libdittoffi.a"

# Fetch prebuilt libdittoffi.a for a specific target triple (no-op if cached)
# Usage: just -g fetch-target x86_64-unknown-linux-gnu [dir]
fetch-target target dir='main':
    #!/usr/bin/env bash
    set -euo pipefail
    version=$(just -g resolve-version {{dir}})
    cache_dir="{{cache_root}}/$version/{{target}}"
    if [[ -f "$cache_dir/libdittoffi.a" ]]; then
        echo "Already cached: $cache_dir/libdittoffi.a"
        exit 0
    fi
    mkdir -p "$cache_dir"
    curl -fL --progress-bar \
        "{{base_url}}/$version/{{target}}/release/libdittoffi.a" \
        -o "$cache_dir/libdittoffi.a"
    echo "Saved to $cache_dir/libdittoffi.a"

# Fetch for Linux x86_64 (common Docker/CI target)
fetch-linux dir='main':
    just -g fetch-target x86_64-unknown-linux-gnu {{dir}}

# cargo check inside <dir> using the fetched host prebuilt.
# Note: sdks/rust/ is a separate Cargo workspace from the repo root, so
# `-p dittolive-ditto` won't work from the root manifest. Use --manifest-path:
#   just -g cargo-check main --manifest-path sdks/rust/dittolive-ditto/Cargo.toml
cargo-check dir *args:
    #!/usr/bin/env bash
    set -euo pipefail
    just -g fetch {{dir}}
    host_target=$(rustc --print host-tuple)
    version=$(just -g resolve-version {{dir}})
    cd {{dir}}
    DITTO_LOCAL_BUILD=0 DITTOFFI_SEARCH_PATH="{{cache_root}}/$version/${host_target}" \
        cargo check {{args}}

# cargo build inside <dir> using the fetched host prebuilt
cargo-build dir *args:
    #!/usr/bin/env bash
    set -euo pipefail
    just -g fetch {{dir}}
    host_target=$(rustc --print host-tuple)
    version=$(just -g resolve-version {{dir}})
    cd {{dir}}
    DITTO_LOCAL_BUILD=0 DITTOFFI_SEARCH_PATH="{{cache_root}}/$version/${host_target}" \
        cargo build {{args}}

# cargo test inside <dir> using the fetched host prebuilt
cargo-test dir *args:
    #!/usr/bin/env bash
    set -euo pipefail
    just -g fetch {{dir}}
    host_target=$(rustc --print host-tuple)
    version=$(just -g resolve-version {{dir}})
    cd {{dir}}
    DITTO_LOCAL_BUILD=0 DITTOFFI_SEARCH_PATH="{{cache_root}}/$version/${host_target}" \
        cargo test {{args}}

import 'work/flutter.just'

# Check whether the main build cache is stale (default: stale if > 7 days)
fresh-check days='7':
    #!/usr/bin/env bash
    set -euo pipefail
    paths=(
        "main/target"
        "main/sdks/flutter/ditto_live/macos/DittoCore.xcframework"
        "main/sdks/flutter/ditto_live/ios/DittoCore.xcframework"
        "main/sdks/cocoa/build"
    )
    threshold_sec=$(( {{days}} * 86400 ))
    now=$(date +%s)
    stale=0; missing=0; fresh=0
    oldest_mtime=$now
    for p in "${paths[@]}"; do
        if [ ! -e "$p" ]; then
            printf "  %-8s %s\n" "MISSING" "$p"
            missing=$((missing+1)); continue
        fi
        mtime=$(stat -f %m "$p")
        [ "$mtime" -lt "$oldest_mtime" ] && oldest_mtime=$mtime
        age_days=$(( (now - mtime) / 86400 ))
        if [ $((now - mtime)) -gt $threshold_sec ]; then
            printf "  %-8s %s  (%dd)\n" "STALE" "$p" "$age_days"
            stale=$((stale+1))
        else
            printf "  %-8s %s  (%dd)\n" "FRESH" "$p" "$age_days"
            fresh=$((fresh+1))
        fi
    done
    if [ -e main/.git ]; then
        new_commits=$(cd main && git log --since="@$oldest_mtime" --oneline 2>/dev/null | wc -l | tr -d ' ')
        [ "$new_commits" -gt 0 ] && echo "  $new_commits new commit(s) on main since the cache was last touched"
    fi
    echo
    if [ $stale -gt 0 ] || [ $missing -gt 0 ]; then
        echo "Cache is stale ($stale stale, $missing missing, $fresh fresh). Run: just -g freshen"
        exit 1
    fi
    echo "Cache is fresh."

# Clean rebuild of the main build cache from scratch (rerun weekly)
freshen:
    #!/usr/bin/env bash
    set -euo pipefail
    cd main
    rm -rf target sdks/flutter/ditto_live/macos/DittoCore.xcframework sdks/flutter/ditto_live/ios/DittoCore.xcframework sdks/cocoa/build
    make build-mac
    make build-ios
    make build-flutter
    date "+✓ Build cache rebuilt at %Y-%m-%d %H:%M"

kanban issue cycle:
    hermes kanban create "[{{cycle}}] {{issue}}" --idempotency-key {{issue}}

my-notes:
    tb -l notes


# ---------------------------------------------------------------------------
# Claude Code on Casper (internal OpenAI-compatible endpoint)
#
# casper speaks ONLY OpenAI /v1/chat/completions (probed
# 2026-08-26: /v1/messages is 404 on every common mount), while the claude CLI
# speaks only Anthropic Messages. A local LiteLLM proxy bridges the two:
#   claude → http://127.0.0.1:$CASPER_PORT/v1/messages → casper /v1/chat/completions
#
# Requires CASPER_API_KEY exported in your shell (never written to disk —
# casper-litellm.yaml references it via os.environ/).
#
# Wiring lessons baked in from an internal code-review harness PR:
#   - model selection via ANTHROPIC_DEFAULT_*_MODEL tier envs, NOT --model
#     (claude validates --model against known Anthropic IDs and rejects "auto")
#   - --strict-mcp-config so a repo's .mcp.json can't inject tool definitions
#     that bloat the prompt past the backing model's context window
# ---------------------------------------------------------------------------

casper_port := env_var_or_default('CASPER_PORT', '4400')
# Real endpoint is internal - set CASPER_BASE_URL in the workspace .env.
casper_base := env_var_or_default('CASPER_BASE_URL', 'https://casper')

# Ensure the LiteLLM bridge is running (no-op if already listening).
# First run downloads litellm via nix — expect a few minutes once.
casper-proxy:
    #!/usr/bin/env bash
    set -euo pipefail
    : "${CASPER_API_KEY:?export CASPER_API_KEY first (mint a token for casper)}"
    if curl -sf "http://127.0.0.1:{{casper_port}}/health/liveliness" >/dev/null 2>&1; then
        echo "casper-litellm already listening on :{{casper_port}}"
        exit 0
    fi
    mkdir -p .agent-logs
    nohup nix run nixpkgs#litellm -- --config casper-litellm.yaml --port {{casper_port}} \
        > .agent-logs/casper-litellm.out 2>&1 &
    echo $! > .agent-logs/casper-litellm.pid
    for _ in $(seq 1 120); do
        curl -sf "http://127.0.0.1:{{casper_port}}/health/liveliness" >/dev/null 2>&1 && break
        sleep 1
    done
    if ! curl -sf "http://127.0.0.1:{{casper_port}}/health/liveliness" >/dev/null 2>&1; then
        echo "casper-litellm failed to start — tail .agent-logs/casper-litellm.out" >&2
        exit 1
    fi
    echo "casper-litellm up on :{{casper_port}} (PID $(cat .agent-logs/casper-litellm.pid)) → .agent-logs/casper-litellm.out"

casper-proxy-stop:
    #!/usr/bin/env bash
    set -euo pipefail
    if [[ -f .agent-logs/casper-litellm.pid ]]; then
        kill "$(cat .agent-logs/casper-litellm.pid)" 2>/dev/null && echo "stopped casper-litellm" || echo "not running"
        rm -f .agent-logs/casper-litellm.pid
    else
        echo "no pid file (.agent-logs/casper-litellm.pid)"
    fi

# `just -g chatgpt`, but routed to Casper via codex's NATIVE Responses wire — no
# LiteLLM bridge in the path (codex 0.145+ is responses-only; casper's
# /v1/responses supports tools, verified 2026-08-26 with kimi-k2.7-code).
# Provider is passed entirely via -c overrides so ~/.codex/config.toml is never
# touched. Follows AGENTS.md (codex ticket workflow), same log/pid/sentinel
# contract as `chatgpt`. Pin model with CASPER_MODEL=<id from casper /v1/models>.
chatgpt-casper prompt:
    #!/usr/bin/env bash
    set -euo pipefail
    : "${CASPER_API_KEY:?export CASPER_API_KEY first (or put it in .env)}"
    mkdir -p .agent-logs
    ticket=$(echo "{{prompt}}" | grep -oE '^[A-Z]+-[0-9]+' || echo "chat-$(date +%Y%m%d-%H%M%S)")
    log=".agent-logs/${ticket}.out"
    model="${CASPER_MODEL:-kimi-k2.7-code}"
    printf '%s\n' codex > ".agent-logs/${ticket}.runner"
    agent_prompt="{{prompt}}"$'\n\n'"You are the headless Codex runner for ${ticket}. Read AGENTS.md and any scoped instructions before acting. Follow the Codex ticket workflow in AGENTS.md, not the Claude ticket protocol."$'\n\n'"The ticket worktree at ${ticket}/ ALREADY EXISTS on the correct Linear branch — verify with a plain 'ls ${ticket}/' and then work directly inside it. Do NOT run any 'git worktree' subcommand and do NOT run git commands against main/ or .bare/ — the command classifier approval-gates those in this environment and every attempt will be rejected; repeating them wastes the run. Use 'git -C ${ticket} status/diff/add/commit' for version control inside the ticket worktree only. If the worktree were ever missing, emit '::STATUS:: blocked — worktree ${ticket} missing' instead of trying to create it. Before any visible GitHub or Linear message, show its body and wait for approval."$'\n\n'"IMPORTANT sandbox rule: run every shell command as a PLAIN sandboxed command. NEVER request escalated permissions (require_escalated / with_escalated_permissions) — this is a headless run with approval_policy=never, so any escalation request is auto-rejected. If a command is rejected, do not retry it verbatim and do not escalate — choose a different, plainer command."$'\n\n'"As the final line of your response, emit exactly one machine-readable sentinel: ::STATUS:: <state> — <detail>. Use done only when a PR is open; use needs-input for an approval or answer you need from the user; use blocked for a concrete environmental or technical blocker."
    # Supervisor: casper rate-limits at roughly ~100K tokens per window, and
    # codex's seconds-scale retry backoff can't outlast a minutes-scale window.
    # On a 429 death, cool down and `codex exec resume --last` (same session,
    # context intact) — bounded at 4 resumes so worst-case spend is explicit.
    supervisor() {
        local codex_args=(
            --disable code_mode_host
            -c model_providers.casper.name=Casper
            -c model_providers.casper.base_url="{{casper_base}}/v1"
            -c model_providers.casper.env_key=CASPER_API_KEY
            -c model_providers.casper.wire_api=responses
            -c model_providers.casper.request_max_retries=10
            -c model_providers.casper.stream_max_retries=10
            -c model_provider=casper
            -c model_reasoning_effort=low
            -c approval_policy=never
            -m "$model" -s workspace-write
            --add-dir "$PWD/.bare" --add-dir "$HOME/.taskbook" --add-dir "$HOME/.taskbook-journals" --add-dir "$HOME/.config"
            --skip-git-repo-check
        )
        codex exec "${codex_args[@]}" "$agent_prompt"
        local attempt=0
        while (( attempt < 4 )); do
            grep -Eq '::STATUS:: (done|needs-input|blocked)' "$log" && return 0
            if tail -5 "$log" | grep -q "429 Too Many Requests"; then
                attempt=$((attempt+1))
                echo "[supervisor] 429 death — cooling down 10m, then resume ($attempt/4)"
                sleep 600
                codex exec "${codex_args[@]}" resume --last "Continue the ${ticket} task from where you left off. Your earlier in-flight edits may not have been applied — re-read the files you were editing inside ${ticket}/ before continuing. Work only inside ${ticket}/ with plain sandboxed commands; never run 'git worktree' subcommands or git against main//.bare (approval-gated, always rejected)."
            else
                return 0
            fi
        done
        echo "[supervisor] resume budget exhausted (4 resumes)"
    }
    printf '%s' "$agent_prompt" > ".agent-logs/${ticket}.prompt"
    nohup bash -c "$(declare -f supervisor); model='$model'; agent_prompt=\$(cat .agent-logs/${ticket}.prompt); log='$log'; ticket='$ticket'; supervisor" > "$log" 2>&1 &
    pid=$!
    echo "$pid" > ".agent-logs/${ticket}.pid"
    echo "Started casper codex agent (model: ${model}, supervised: auto-resume on 429) for ${ticket} (PID $pid) → tail -f ${log}"

# `just -g chat`, but routed through Casper. Pin the model with
# CASPER_MODEL=<id from casper /v1/models>, e.g.:
#   CASPER_MODEL=kimi-k3 just -g chat-casper "TICKET-NNNN - title"
# Default is casper's "auto" router — the launch line echoes the routed model
# so a wrong pin is visible immediately.
# MCP is pinned to casper-mcp.json (linear-server ONLY) via --strict-mcp-config:
# the ticket protocol needs linear get_issue, but the full MCP roster (workflowy,
# hackmd, dart, slack, ...) adds ~200KB of tool schemas per request — context
# bloat that correlates with local models corrupting tool-call JSON (run #6:
# kimi-k3 mashed two calls' args into one, claude rejected, model gave up).
# Expect the "claude.ai connectors are disabled" warning in the log — the
# bridge credential overrides the claude.ai login; .mcp.json servers still load.
chat-casper prompt:
    #!/usr/bin/env bash
    set -euo pipefail
    just -g casper-proxy
    mkdir -p .agent-logs
    ticket=$(echo "{{prompt}}" | grep -oE '^[A-Z]+-[0-9]+' || echo "chat-$(date +%Y%m%d-%H%M%S)")
    log=".agent-logs/${ticket}.out"
    model="${CASPER_MODEL:-auto}"
    export ANTHROPIC_BASE_URL="http://127.0.0.1:{{casper_port}}"
    export ANTHROPIC_AUTH_TOKEN="casper-litellm-local"
    export ANTHROPIC_DEFAULT_OPUS_MODEL="$model"
    export ANTHROPIC_DEFAULT_SONNET_MODEL="$model"
    export ANTHROPIC_DEFAULT_HAIKU_MODEL="$model"
    export CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC=1
    # No extended thinking: claude's thinking request becomes reasoning_effort=high
    # upstream, the local model's reasoning comes back as Anthropic thinking blocks,
    # and replaying those in history 400s on casper's strict Rust router.
    export MAX_THINKING_TOKENS=0
    nohup claude --model opus --permission-mode acceptEdits --strict-mcp-config --mcp-config casper-mcp.json -p "{{prompt}}. {{chat_protocol}}" > "$log" 2>&1 &
    pid=$!
    echo "$pid" > ".agent-logs/${ticket}.pid"
    echo "Started casper agent (model: ${model}) for ${ticket} (PID $pid) → just -g status  (or tail -f ${log})"

# Run Claude Code against Casper: `just -g claude-code` (interactive) or
# `just -g claude-code -p "prompt"`. Override the routed model with
# CASPER_MODEL=<id from /v1/models> (default: casper's "auto" router).
claude-code *args:
    #!/usr/bin/env bash
    set -euo pipefail
    : "${CASPER_API_KEY:?export CASPER_API_KEY first (mint a token for casper)}"
    just -g casper-proxy
    model="${CASPER_MODEL:-auto}"
    export ANTHROPIC_BASE_URL="http://127.0.0.1:{{casper_port}}"
    export ANTHROPIC_AUTH_TOKEN="casper-litellm-local"   # bridge does auth upstream; claude just needs a non-empty credential
    export ANTHROPIC_DEFAULT_OPUS_MODEL="$model"
    export ANTHROPIC_DEFAULT_SONNET_MODEL="$model"
    export ANTHROPIC_DEFAULT_HAIKU_MODEL="$model"
    export CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC=1
    # See chat-casper: thinking blocks don't survive the round-trip to casper.
    export MAX_THINKING_TOKENS=0
    exec claude --strict-mcp-config {{args}}