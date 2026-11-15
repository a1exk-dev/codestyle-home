#!/usr/bin/env bash
# Usage: scripts/copy-skills.sh [--check]
#
# Copies the home's process skills (git-commit, semver, common-changelog)
# and their policies into each clone in the home's manifest
# (repos.gitconfig), so that each repo follows the same process without
# the home (home ADR-0006). Each clone gets .agents/skills/<skill>/, a Claude Code link
# .claude/skills/<skill>, and docs/agents/<name>-policy.md. It commits
# nothing: open one pull request per repo with the changes.
#
# Skips a clone that has uncommitted changes and names it. With --check,
# it changes no file, names each stale copy, and exits 1 when one is
# stale.
set -euo pipefail

home="$(git -C "$(dirname "$0")" rev-parse --show-toplevel)"
skills=(git-commit semver common-changelog)
policies=(commit semver changelog)

case ${1:-} in
"") check=false ;;
--check) check=true ;;
*)
	echo "usage: scripts/copy-skills.sh [--check]" >&2
	exit 2
	;;
esac

# stale <dir>: prints each copy in a clone that differs from the home.
stale() {
	local skill policy
	for skill in "${skills[@]}"; do
		diff -rq "$home/.agents/skills/$skill" "$1/.agents/skills/$skill" >/dev/null 2>&1 ||
			echo "  .agents/skills/$skill/"
		[[ "$(readlink "$1/.claude/skills/$skill" || true)" == "../../.agents/skills/$skill" ]] ||
			echo "  .claude/skills/$skill"
	done
	for policy in "${policies[@]}"; do
		cmp -s "$home/docs/agents/$policy-policy.md" "$1/docs/agents/$policy-policy.md" ||
			echo "  docs/agents/$policy-policy.md"
	done
}

# copy <dir>: replaces each copy in a clone with the home's.
copy() {
	local skill policy
	mkdir -p "$1/.agents/skills" "$1/.claude/skills" "$1/docs/agents"
	for skill in "${skills[@]}"; do
		rm -rf "$1/.agents/skills/$skill" "$1/.claude/skills/$skill"
		cp -R "$home/.agents/skills/$skill" "$1/.agents/skills/$skill"
		ln -s "../../.agents/skills/$skill" "$1/.claude/skills/$skill"
	done
	for policy in "${policies[@]}"; do
		cp "$home/docs/agents/$policy-policy.md" "$1/docs/agents/$policy-policy.md"
	done
}

status=0
while read -r key _; do
	name=${key#repo.} && name=${name%.github}
	dir="$home/$name"
	if [[ ! -e $dir/.git ]]; then
		echo "not cloned: $name"
		continue
	fi
	report="$(stale "$dir")"
	if [[ -z $report ]]; then
		echo "up to date: $name"
	elif $check; then
		echo "stale: $name"
		echo "$report"
		status=1
	elif [[ -n "$(git -C "$dir" status --porcelain)" ]]; then
		echo "skipped (uncommitted changes): $name"
	else
		copy "$dir"
		echo "copied: $name"
	fi
done < <(git config -f "$home/repos.gitconfig" --get-regexp '^repo\..+\.github$')
exit "$status"
