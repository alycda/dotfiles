_default:
    @just --list

# Create a task directory named with a UTC HUID and seed its TASK.md
[group('huid')]
task title:
    tasks/scripts/huid-task {{ quote(title) }}

# Create a task and open it in $EDITOR (helix by default)
[group('huid')]
task-edit title:
    tasks/scripts/huid-task-edit {{ quote(title) }}

# MACRO.MESO.MICRO
bump effort:
    tools/effver/bump-effver {{ effort }}

# Check VERSION and CHANGELOG.md in every commit of REVSET (default: the stack not on trunk yet)
check-effver revset='':
    tools/effver/check-effver --jj {{ quote(revset) }}

# Setup recipes are one-time steps you run by hand, written so that running
# one again does nothing. Never make them run automatically, e.g. from a hook:
# a login prompt with no terminal attached just hangs. On a new machine, mise
# is not active in the shell yet: run the first one as `mise exec -- just
# identity`, which also runs the two it depends on.

# Create an SSH key for GitHub, unless one exists
[group('setup')]
ssh-key:
    @tools/setup/ssh-key

# Log gh in over SSH, unless it already is
[group('setup')]
gh-login: ssh-key
    @tools/setup/gh-login

# Set git and jj identity from the logged-in GitHub account
[group('setup')]
identity: gh-login
    @tools/setup/identity
