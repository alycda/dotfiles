# Load the agenix token, then fail fast instead of prompting into the void.
#
# Not a standalone script: this is read into the hackmd-cli wrapper by
# home-manager/modules/tools/hackmd.nix, which supplies the shebang,
# `set -euo pipefail` and $hackmd_token_file (and shellchecks the result).
#
# PART 1 - token pickup.
#
# When a profile sets `hackmd.account`, agenix decrypts the token to
# $hackmd_token_file with the generation, and this turns it into the
# HMD_API_ACCESS_TOKEN the CLI reads. Doing it here rather than in
# home.sessionVariables keeps the token out of every process's environment: it
# is read at call time, by the one command entitled to it, from an
# owner-read-only file.
#
# An already-set HMD_API_ACCESS_TOKEN always wins, matching the CLI's own
# precedence (env over config file, lib/config.js).
#
# The file's shape is deliberately not assumed. PR #59 encrypted these secrets
# for a HackMD MCP server that wanted env-file format, so the plaintext is
# probably `HACKMD_API_TOKEN=<token>`; hackmd-cli wants the bare value under a
# different name. Rather than re-encrypt to settle it, accept both - a leading
# `HACKMD_API_TOKEN=` or `HMD_API_ACCESS_TOKEN=` is stripped, anything else is
# taken whole. Only those two exact names are recognised, never a generic
# `KEY=`: an opaque token may itself contain `=` (base64 padding), and a
# `*=*` test would silently truncate it to nothing.
hackmd_token_value=""
if [ -z "${HMD_API_ACCESS_TOKEN-}" ] && [ -r "$hackmd_token_file" ]; then
  while IFS= read -r hackmd_token_line || [ -n "$hackmd_token_line" ]; do
    # Skip blanks and comments; the first real line is the value.
    case "$hackmd_token_line" in
      '' | '#'*) continue ;;
    esac
    hackmd_token_value=$hackmd_token_line
    break
  done <"$hackmd_token_file"

  # CRLF survives a paste into an editor and would be sent in the auth header.
  hackmd_token_value=${hackmd_token_value%$'\r'}

  if [[ $hackmd_token_value =~ ^(HACKMD_API_TOKEN|HMD_API_ACCESS_TOKEN)=(.*)$ ]]; then
    hackmd_token_value=${BASH_REMATCH[2]}
  fi

  # Unwrap one layer of quoting, as an env file may carry it.
  case "$hackmd_token_value" in
    \"*\") hackmd_token_value=${hackmd_token_value#\"}; hackmd_token_value=${hackmd_token_value%\"} ;;
    \'*\') hackmd_token_value=${hackmd_token_value#\'}; hackmd_token_value=${hackmd_token_value%\'} ;;
  esac

  if [ -n "$hackmd_token_value" ]; then
    export HMD_API_ACCESS_TOKEN="$hackmd_token_value"
  fi
fi
unset hackmd_token_value

# PART 2 - the headless prompt guard.
#
# With no access token configured, hackmd-cli asks for one interactively. Its
# non-TTY fallback shells out to `sh -c 'read -s PASS && echo $PASS'`, which
# yields an empty answer on a pipe - and errors outright wherever /bin/sh is
# dash, which has no `read -s` ("read: Illegal option -s"). An empty answer
# re-asks the question, so the caller spins forever rather than failing.
#
# That is not a theoretical path. ../../home-manager/modules/common.nix puts
# this CLI in every profile including the headless devcontainer, precisely so
# agents can call it; an agent on a machine where `hackmd-cli login` was never
# run is exactly the case that hangs, and it hangs silently until killed.
#
# Only the non-interactive path is guarded. On a TTY the prompt works, and
# `hackmd-cli login` is the intended way to get a token in the first place.
if [ ! -t 0 ]; then
  case "${1-}" in
    # Root-level flags (--version, --help), `help`, `autocomplete`, `logout`
    # and the no-argument help screen all answer without calling the API.
    '' | -* | help | autocomplete | logout) ;;

    login)
      echo "hackmd-cli: 'login' needs a terminal to prompt for a token." >&2
      echo "  Non-interactively, set HMD_API_ACCESS_TOKEN instead." >&2
      echo "  Mint one at https://hackmd.io/settings#api" >&2
      exit 1
      ;;

    *)
      # Same resolution order as the CLI's lib/config.js: HMD_API_ACCESS_TOKEN
      # wins, then accessToken from the config file, whose directory
      # HMD_CLI_CONFIG_DIR may move. The CLI creates that file as `{}` on first
      # run, so its mere existence proves nothing - the key has to be there.
      hackmd_token_found=""
      if [ -n "${HMD_API_ACCESS_TOKEN-}" ]; then
        hackmd_token_found=yes
      else
        hackmd_config="${HMD_CLI_CONFIG_DIR:-${HOME-}/.hackmd}/config.json"
        if [ -r "$hackmd_config" ]; then
          case "$(<"$hackmd_config")" in
          *'"accessToken"'*) hackmd_token_found=yes ;;
          esac
        fi
      fi

      if [ -z "$hackmd_token_found" ]; then
        echo "hackmd-cli: no API token, and stdin is not a terminal to prompt on." >&2
        echo "  Set HMD_API_ACCESS_TOKEN, or run 'hackmd-cli login' from a terminal." >&2
        echo "  Mint a token at https://hackmd.io/settings#api" >&2
        echo "  This profile expects agenix to have decrypted one to:" >&2
        echo "    $hackmd_token_file" >&2
        echo "  If that file is missing, either the profile sets no" >&2
        echo "  hackmd.account, or activation could not decrypt it - check that" >&2
        echo "  the age identity is in place (see the Dockerfile's docker cp" >&2
        echo "  note for containers)." >&2
        exit 1
      fi
      ;;
  esac
fi
