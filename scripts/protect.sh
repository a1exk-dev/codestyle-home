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

# The five required checks, by their job names in the Core's CI. The
# template map (a1exk-dev/codestyle-home#28) decides the template's.
checks=(
	"Tests (Neovim v0.11.7)"
	"Tests (Neovim stable)"
	"Spell check with typos"
	"Format check with StyLua"
	"Type check with lua-language-server"
)
github_actions=15368

# The request body. A PUT replaces the whole protection, so it states
# each rule that the endpoint takes, and the comparison below covers each
# of them.
protection="$(jq -n --argjson app "$github_actions" '{
	required_status_checks: {
		strict: false,
		checks: [$ARGS.positional[] | {context: ., app_id: $app}]
	},
	enforce_admins: true,
	required_pull_request_reviews: null,
	restrictions: null,
	required_linear_history: false,
	allow_force_pushes: false,
	allow_deletions: false,
	block_creations: false,
	required_conversation_resolution: false,
	lock_branch: false,
	allow_fork_syncing: false
}' --args "${checks[@]}")"

# The rules of a protection that GitHub returns, in the shape of the
# request body.
rules='{
	required_status_checks: (.required_status_checks // null
		| if . then {strict, checks: (.checks | map({context, app_id}))} else . end),
	enforce_admins: .enforce_admins.enabled,
	required_pull_request_reviews: (.required_pull_request_reviews // null | if . then true else . end),
	restrictions: (.restrictions // null | if . then true else . end),
	required_linear_history: .required_linear_history.enabled,
	allow_force_pushes: .allow_force_pushes.enabled,
	allow_deletions: .allow_deletions.enabled,
	block_creations: .block_creations.enabled,
	required_conversation_resolution: .required_conversation_resolution.enabled,
	lock_branch: .lock_branch.enabled,
	allow_fork_syncing: .allow_fork_syncing.enabled
}'
# sorted: a body with its checks in a stable order, for comparison.
sorted='.required_status_checks.checks |= (. // [] | sort_by(.context)) | tojson'
wanted="$(jq -r "$sorted" <<<"$protection")"

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
	if ! reason="$(gh api "$path" --silent 2>&1 </dev/null)"; then
		result="failed"
		return
	fi
	if current="$(gh api "$path/protection" 2>"$errors" </dev/null)"; then
		current="$(jq "$rules" <<<"$current" | jq -r "$sorted")"
	elif grep -q "Branch not protected" "$errors"; then
		current=
	else
		result="failed" reason="$(<"$errors")"
		return
	fi
	if [[ $current == "$wanted" ]]; then
		result="up to date"
	elif reason="$(gh api --method PUT "$path/protection" --input - <<<"$protection" 2>&1 >/dev/null)"; then
		result="protected"
	else
		result="failed"
	fi
}

errors="$(mktemp)"
trap 'rm -f "$errors"' EXIT

status=0
while read -r line || [[ -n $line ]]; do
	read -r name url _ <<<"${line%%#*}"
	[[ -n $name ]] || continue
	if [[ -z $url ]]; then
		echo "failed: $name (no GitHub URL)"
		status=1
		continue
	elif ! repo="$(github_repo "$url")"; then
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
