#!/usr/bin/env bats
# The cheatsheets in .cheat/, through the config mise points CHEAT_CONFIG_PATH
# at. One sheet whose front matter doesn't parse stops cheat for every sheet,
# so each must load. cheat is the version mise.toml pins.

setup() {
  repo="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
  export CHEAT_CONFIG_PATH="$repo/tools/cheat/conf.yml"
  cd "$repo" || return
}

@test "cheat lists every sheet in .cheat/, and only those" {
  run cheat -l
  [ "$status" -eq 0 ]
  listed="$(tail -n +2 <<<"$output" | awk '{ print $1 }' | sort)"
  want="$(cd .cheat && find . -type f | sed 's|^\./||' | sort)"
  [ "$listed" = "$want" ]
}

@test "every sheet shows" {
  while IFS= read -r sheet; do
    cheat "$sheet" > /dev/null || { echo "cannot show $sheet"; return 1; }
  done < <(cd .cheat && find . -type f | sed 's|^\./||')
}
