# Both PR recipes scope to the current repo by default; export DITTO_REPO
# (e.g. in a workspace .env) to pin them to a specific repo from anywhere.
pr_repo := env_var_or_default('DITTO_REPO', '')
repo_flag := if pr_repo != '' { '--repo ' + pr_repo } else { '' }

[group('gh')]
my-prs:
    gh pr list {{repo_flag}} -a @me --state open

# non-draft PRs, oldest-updated first, with review state
[group('gh')]
my-open-prs:
    gh pr list {{repo_flag}} -a @me --state open --json number,title,isDraft,reviewDecision,updatedAt --jq '[.[] | select(.isDraft|not)] | sort_by(.updatedAt) | .[] | "\(.number)\t\(.reviewDecision)\t\(.updatedAt[:10])\t\(.title)"'

# name + email of the logged-in gh user
[group('gh')]
gh-whoami:
    @gh api user | jq -r '.name, .email'
