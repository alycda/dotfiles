# taskbook
tasks:
    tb --cli

# HUID tasks, in whatever repo `just -g` runs from. The logic is in
# tasks/scripts: huid-task writes to tasks/ if the repo has one, else to the
# globally ignored .tasks/.

# Create a task named with a fresh HUID; prints its TASK.md path
[group('huid')]
task title:
    @huid-task {{ quote(title) }}

# Create a task and open it in $EDITOR (helix by default)
[group('huid')]
task-edit title:
    @huid-task-edit {{ quote(title) }}
