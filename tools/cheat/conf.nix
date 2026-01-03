{ pkgs, cheatsheetsPath }:

pkgs.writeText "conf.yml" ''
  editor: vi
  colorize: false
  style: monokai
  formatter: terminal256
  pager: less -FRX
  cheatpaths:
    - name: community
      path: ${cheatsheetsPath}/community
      tags: [ community ]
      readonly: true
    - name: personal
      path: ${cheatsheetsPath}/personal
      tags: [ personal ]
      readonly: true
''
