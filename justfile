_default:
    @just --list

# MACRO.MESO.MICRO
bump effort:
    tools/effver/bump-effver {{ effort }}
