#!/usr/bin/env bash
# Protects `main` and `develop` on each GitHub repo in the home's manifest
# (repos.txt) with your `gh` login: each branch requires the five checks
# of Core ADR-0017, from GitHub Actions, also for admins. Sets only a
# branch whose protection differs, so it is safe to run again after a
# repo joins the manifest. Names each repo and branch with "protected",
# "up to date" or "failed", and exits non-zero when one failed, after
# the others.
set -euo pipefail

home="$(git -C "$(dirname "$0")" rev-parse --show-toplevel)"

# The required checks, as GitHub Actions (app 15368) reports them.
protection='{
	"required_status_checks": {
		"strict": false,
		"checks": [
			{"context": "Tests (Neovim v0.11.7)", "app_id": 15368},
			{"context": "Tests (Neovim stable)", "app_id": 15368},
			{"context": "Spell check with typos", "app_id": 15368},
			{"context": "Format check with StyLua", "app_id": 15368},
			{"context": "Type check with lua-language-server", "app_id": 15368}
		]
	},
	"enforce_admins": true,
	"required_pull_request_reviews": null,
	"restrictions": null,
	"allow_force_pushes": false,
	"allow_deletions": false
}'

# The settings that this script sets, from a protection that GitHub
# returns; a protection with the same settings needs no change.
settings='{
	strict: .required_status_checks.strict,
	checks: (.required_status_checks.checks // [] | map({context, app_id}) | sort_by(.context)),
	enforce_admins: .enforce_admins.enabled,
	reviews: (.required_pull_request_reviews != null),
	restrictions: (.restrictions != null),
	allow_force_pushes: .allow_force_pushes.enabled,
	allow_deletions: .allow_deletions.enabled
}'

# The same settings from the request body above.
wanted="$(jq -c '{
	strict: .required_status_checks.strict,
	checks: (.required_status_checks.checks | sort_by(.context)),
	enforce_admins,
	reviews: (.required_pull_request_reviews != null),
	restrictions: (.restrictions != null),
	allow_force_pushes,
	allow_deletions
}' <<<"$protection")"

# github_repo <url>: the owner/repo of a GitHub clone URL; fails for
# another URL.
github_repo() {
	local repo
	case $1 in
	https://github.com/*) repo=${1#https://github.com/} ;;
	git@github.com:*) repo=${1#git@github.com:} ;;
	*) return 1 ;;
	esac
	repo=${repo%.git}
	[[ $repo =~ ^[^/]+/[^/]+$ ]] && echo "$repo"
}

# protect <owner/repo> <branch>: sets the protection when it differs;
# sets $result, and $reason when it fails.
protect() {
	local path="repos/$1/branches/$2" current
	reason=
	if ! reason="$(gh api "$path" --silent 2>&1)"; then
		result="failed"
		return
	fi
	current="$(gh api "$path/protection" 2>/dev/null | jq -c "$settings" || true)"
	if [[ $current == "$wanted" ]]; then
		result="up to date"
	elif reason="$(gh api --method PUT "$path/protection" --input - <<<"$protection" 2>&1 >/dev/null)"; then
		result="protected"
	else
		result="failed"
	fi
}

status=0
while read -r line || [[ -n $line ]]; do
	read -r name url _ <<<"${line%%#*}"
	[[ -n $name ]] || continue
	if ! repo="$(github_repo "$url")"; then
		echo "failed: $name ($url is not a GitHub repo)"
		status=1
		continue
	fi
	for branch in main develop; do
		protect "$repo" "$branch"
		echo "$result: $name $branch${reason:+ ($reason)}"
		[[ $result != failed ]] || status=1
	done
done <"$home/repos.txt"
exit "$status"
