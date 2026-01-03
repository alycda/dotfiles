{ pkgs, cheatsheetsPath }:

pkgs.writeText "conf.yml" ''
  colorize: false
  style: monokai
  formatter: terminal256
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
