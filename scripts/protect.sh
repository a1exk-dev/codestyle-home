#!/usr/bin/env bash
# Protects `main` and `develop` on each GitHub repo in the home's manifest
# (repos.gitconfig) with your `gh` login: each branch requires the five
# checks of Core ADR-0017 and one more for each `check` key in the repo's
# section, from GitHub Actions, also for admins. Also allows auto-merge
# and deletes a pull request's branch after its merge, for the
# operator's pull requests that the Auto-merge workflow merges, and sets
# the repo's GitHub topics, as a template copies no settings.
# Sets only a branch, settings or topics that differ, so it is safe to run
# again after a repo joins the manifest. Names each repo and branch, or the
# repo's settings or topics, with "protected", "set", "up to date" or
# "failed", and exits non-zero when one failed, after the others.
set -euo pipefail

home="$(git -C "$(dirname "$0")" rev-parse --show-toplevel)"

# The five required checks of every repo, by their job names in the
# Core's CI. Each `check` key in a repo's section adds one for that repo.
shared_checks=(
	"Tests (Neovim v0.11.7)"
	"Tests (Neovim stable)"
	"Spell check with typos"
	"Format check with StyLua"
	"Type check with lua-language-server"
)
github_actions=15368

# body <check>...: the request body that requires these checks. A PUT
# replaces the whole protection, so it states each rule that the endpoint
# takes, and the comparison below covers each of them.
body() {
	jq -n --argjson app "$github_actions" '{
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
	}' --args "$@"
}

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

# protect <owner/repo> <branch>: sets $protection on the branch when its
# protection differs from $wanted; sets $result, and $reason when it
# fails.
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

# The repo settings, in the shape that GitHub returns them.
settings='{"allow_auto_merge":true,"delete_branch_on_merge":true}'

# configure <owner/repo>: sets the repo settings when they differ; sets
# $result, and $reason when it fails.
configure() {
	local path="repos/$1" current
	reason=
	if ! current="$(gh api "$path" --jq '{allow_auto_merge, delete_branch_on_merge}' 2>"$errors" </dev/null)"; then
		result="failed" reason="$(<"$errors")"
	elif [[ "$(jq -cS . <<<"$current")" == "$(jq -cS . <<<"$settings")" ]]; then
		result="up to date"
	elif reason="$(gh api --method PATCH "$path" --input - <<<"$settings" 2>&1 >/dev/null)"; then
		result="set"
	else
		result="failed"
	fi
}

# The GitHub topics of every repo. A Language Plugin,
# `codestyle-<id>.nvim` on GitHub, also gets its language, `<id>` with
# each `_` turned into `-`, as a topic takes no `_`; the Core and the
# template get none.
shared_topics=(neovim neovim-plugin lua formatter code-style)
template=codestyle-language-template.nvim

# tag <owner/repo> <topic>...: sets these topics as the repo's full set
# when its topics differ; sets $result, and $reason when it fails.
tag() {
	local path="repos/$1/topics" current wanted
	shift
	reason=
	wanted="$(jq -cn '$ARGS.positional | sort' --args "$@")"
	if ! current="$(gh api "$path" --jq '.names | sort' 2>"$errors" </dev/null)"; then
		result="failed" reason="$(<"$errors")"
	elif [[ "$(jq -c . <<<"$current")" == "$wanted" ]]; then
		result="up to date"
	elif reason="$(jq -c '{names: .}' <<<"$wanted" |
		gh api --method PUT "$path" --input - 2>&1 >/dev/null)"; then
		result="set"
	else
		result="failed"
	fi
}

# report <what>: prints $result for <what> of the repo $name, with
# $reason when there is one, and sets $status when it failed.
report() {
	echo "$result: $name $1${reason:+ ($reason)}"
	[[ $result != failed ]] || status=1
}

errors="$(mktemp)"
trap 'rm -f "$errors"' EXIT

status=0
while read -r key repo; do
	name=${key#repo.} && name=${name%.github}
	checks=("${shared_checks[@]}")
	while IFS= read -r check; do
		checks+=("$check")
	done < <(git config -f "$home/repos.gitconfig" --get-all "repo.$name.check" || true)
	protection="$(body "${checks[@]}")"
	wanted="$(jq -r "$sorted" <<<"$protection")"
	for branch in main develop; do
		protect "$repo" "$branch"
		report "$branch"
	done
	configure "$repo"
	report settings
	topics=("${shared_topics[@]}")
	slug=${repo#*/} && id=${slug#codestyle-} && id=${id%.nvim}
	[[ $slug != codestyle-?*.nvim || $slug == "$template" ]] || topics+=("${id//_/-}")
	tag "$repo" "${topics[@]}"
	report topics
done < <(git config -f "$home/repos.gitconfig" --get-regexp '^repo\..+\.github$')
exit "$status"
