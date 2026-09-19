# jj-moment-agent - the agent commit protocol for Moment documents, behind the
# `jj agent-start` / `jj agent-done` aliases (tools/moment/jj-agent-aliases.toml,
# active only under ~/.moment/documents). Packaged by
# home-manager/modules/tools/moment.nix with writeShellApplication, which adds
# the shebang and `set -euo pipefail` and shellchecks this at build time.
#
# Why a protocol at all: jj records a change's author when the change is
# *created*. An agent that edits Moment's draft and runs `jj commit` gets its
# work attributed to Alyssa and leaves behind an empty change in its own name,
# which her next Moment commit then fills. So:
#   start - create the agent's own change with the agent's identity set
#           explicitly (no reliance on env vars each tool may or may not set),
#           then drop Moment's empty undescribed draft underneath it
#   done  - hand Moment a fresh draft authored by Alyssa

die() { echo "jj-moment-agent: $*" >&2; exit 2; }

usage() {
  cat >&2 <<'EOF'
usage: jj agent-start <claude|codex|crush> "<intent>" [<provider>/<model>]
       jj agent-done
crush reads its selected model from its data config; pass <provider>/<model>
when that is missing or not the model you are actually running.
EOF
  exit 2
}

# crush runs whatever model is configured, so its identity is the model:
# <model>@crush, or <model>@crush.local for a local ollama model. The local
# part is reduced to [A-Za-z0-9._-] - model ids carry ':' and '/'.
crush_email() {
  local spec=${1:-} data provider model
  if [ -z "$spec" ]; then
    data=${CRUSH_GLOBAL_DATA:-${XDG_DATA_HOME:-$HOME/.local/share}/crush}/crush.json
    spec=$(jq -r '.models.large | select(.provider and .model) | "\(.provider)/\(.model)"' "$data" 2>/dev/null || true)
  fi
  [ -n "$spec" ] && [ "${spec#*/}" != "$spec" ] ||
    die "crush: model unknown - pass it as the third argument, <provider>/<model>"
  provider=${spec%%/*}
  model=$(printf '%s' "${spec#*/}" | tr -c 'A-Za-z0-9._-' '-')
  if [ "$provider" = ollama ]; then
    echo "$model@crush.local"
  else
    echo "$model@crush"
  fi
}

cmd=${1:-}
[ $# -gt 0 ] && shift

case $cmd in
  start)
    [ $# -ge 2 ] || usage
    agent=$1 intent=$2
    case $agent in
      claude) name=Claude email=noreply@anthropic.com ;;
      codex) name=Codex email=noreply@openai.com ;;
      crush) name=Crush email=$(crush_email "${3:-}") ;;
      *) die "unknown agent '$agent' (claude, codex or crush)" ;;
    esac
    jj --config "user.name=\"$name\"" --config "user.email=\"$email\"" \
      new -m "$intent"
    # A no-op when the draft holds unsaved edits: those stay in Alyssa's
    # change underneath the agent's.
    jj abandon -r '@- & empty() & description(exact:"")'
    ;;
  done)
    [ $# -eq 0 ] || usage
    # env -u: the conf.d scope would otherwise make Claude the author again.
    env -u CLAUDECODE jj new
    ;;
  *) usage ;;
esac
