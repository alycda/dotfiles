# find which Claude Code session transcripts mention a ticket
[group('claude')]
find-session ticket:
    grep -rl "{{ticket}}" ~/.claude/projects/
