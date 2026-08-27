[group('gh')]
my-prs:
    gh pr list -a @me

# name + email of the logged-in gh user
[group('gh')]
gh-whoami:
    @gh api user | jq -r '.name, .email'
