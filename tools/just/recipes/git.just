my-prs repo='':
    gh pr list --repo {{repo}} --author alycda --state open

my-open-prs:
    gh pr list --repo getditto/ditto --author alycda --state open --json number,title,isDraft,reviewDecision,updatedAt --jq '[.[] | select(.isDraft|not)] | sort_by(.updatedAt) | .[] | "\(.number)\t\(.reviewDecision)\t\(.updatedAt[:10])\t\(.title)"'
