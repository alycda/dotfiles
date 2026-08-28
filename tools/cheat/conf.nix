# cheat's conf.yml. Imported by BOTH the devShell (flake.nix) and home-manager
# (home-manager/modules/tools/cheat.nix) so a throwaway `nix develop` shell and
# a switched profile read the same sheets.
#
# community/ and personal/ are store paths - immutable, hence `readonly: true`.
# That left cheat with nowhere to write: `cheat -e <new-sheet>` needs a writable
# cheatpath and fails when every path is readonly. `inboxPath` supplies exactly
# one, and being the only writable entry it is unambiguously the write target
# whichever end of the list cheat scans from.
#
# The inbox entry is YAML flow style on purpose: an optional multi-line ${...}
# block would need to carry its own indentation, which Nix's indented-string
# stripping cannot preserve (the least-indented line always lands at column 0).
{ pkgs, cheatsheetsPath, inboxPath ? null }:
let
  inboxEntry = pkgs.lib.optionalString (
    inboxPath != null
  ) ''- { name: inbox, path: "${inboxPath}", tags: [ inbox, unverified ], readonly: false }'';
in
pkgs.writeText "conf.yml" ''
  editor: hx
  colorize: true
  style: monokai
  formatter: terminal256
  pager: bat --paging=auto
  cheatpaths:
    - name: community
      path: ${cheatsheetsPath}/community
      tags: [ community ]
      readonly: true
    - name: personal
      path: ${cheatsheetsPath}/personal
      tags: [ personal ]
      readonly: true
    ${inboxEntry}
''
