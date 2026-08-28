# Fail fast instead of prompting into the void.
#
# Not a standalone script: this is read into the hackmd-cli wrapper by
# home-manager/modules/tools/hackmd.nix, which supplies the shebang and
# `set -euo pipefail` (and shellchecks the result).
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
        exit 1
      fi
      ;;
  esac
fi
