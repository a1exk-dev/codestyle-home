#!/usr/bin/env bash
# Clones each repo in the home's manifest (repos.gitconfig) into a folder
# of that name at the home root with `gh repo clone`, and fast-forwards
# each existing clone on its current branch. Skips a clone that has uncommitted changes, a detached
# HEAD, or a branch that cannot fast-forward, and names it in the summary.
# Exits non-zero when a clone or pull fails for another reason.
set -euo pipefail

home="$(git -C "$(dirname "$0")" rev-parse --show-toplevel)"

# sync <dir> <owner/name>: clones or fast-forwards one repo; sets $result.
sync() {
	local dir="$1" github="$2"
	if [[ ! -e $dir ]]; then
		gh repo clone "$github" "$dir" -- -q && result="cloned" || result="failed"
		return
	fi
	local git=(git -C "$dir")
	if [[ ! -e $dir/.git ]]; then
		echo "$dir is not a clone" >&2
		result="failed"
	elif [[ -n "$("${git[@]}" status --porcelain --untracked-files=no)" ]]; then
		result="skipped (uncommitted changes)"
	elif ! "${git[@]}" symbolic-ref -q HEAD >/dev/null; then
		result="skipped (detached HEAD)"
	elif ! "${git[@]}" fetch -q; then
		result="failed"
	elif "${git[@]}" merge-base --is-ancestor '@{upstream}' HEAD; then
		result="up to date"
	elif ! "${git[@]}" merge-base --is-ancestor HEAD '@{upstream}'; then
		result="skipped (cannot fast-forward)"
	elif "${git[@]}" merge -q --ff-only '@{upstream}'; then
		result="updated"
	else
		result="failed"
	fi
}

summary=()
status=0
while read -r key github; do
	name=${key#repo.} && name=${name%.github}
	sync "$home/$name" "$github"
	summary+=("$result: $name")
	[[ $result != failed ]] || status=1
done < <(git config -f "$home/repos.gitconfig" --get-regexp '^repo\..+\.github$')

printf '%s\n' "${summary[@]}"
exit "$status"
