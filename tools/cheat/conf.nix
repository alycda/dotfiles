{ pkgs, cheatsheetsPath }:

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
''
