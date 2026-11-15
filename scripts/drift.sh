#!/usr/bin/env bash
# Usage: scripts/drift.sh [--diff] [<plugin>...]
#
# Reports, for each Language Plugin clone in the home's manifest
# (repos.txt), or for each named one, the boilerplate files that differ
# from the template clone: changed, missing or extra. The boilerplate
# files are those that boilerplate.txt lists. With --diff, it also shows
# each difference. Plugins may differ on purpose, so the report never
# fails on a difference and changes no file. It exits non-zero only when
# the template is not cloned or the arguments are wrong.
set -euo pipefail

home="$(git -C "$(dirname "$0")" rev-parse --show-toplevel)"
template=codestyle-language-template.nvim

usage() {
	echo "usage: scripts/drift.sh [--diff] [<plugin>...]" >&2
	exit 2
}

show_diff=false
named=()
for arg in "$@"; do
	case $arg in
	--diff) show_diff=true ;;
	-*) usage ;;
	*) named+=("$arg") ;;
	esac
done

# The boilerplate paths, one per line; a path that ends in / covers each
# file under it.
mapfile -t paths < <(sed 's/#.*//; s/^[[:space:]]*//; s/[[:space:]]*$//; /^$/d' "$home/boilerplate.txt")

# The Language Plugins in the manifest.
plugins=()
while read -r line || [[ -n $line ]]; do
	read -r name _ <<<"${line%%#*}"
	[[ $name == codestyle-*.nvim && $name != "$template" ]] && plugins+=("$name")
done <"$home/repos.txt"

for name in "${named[@]}"; do
	[[ " ${plugins[*]} " == *" $name "* ]] || {
		echo "$name is not a Language Plugin in repos.txt" >&2
		usage
	}
done
((${#named[@]} == 0)) || plugins=("${named[@]}")

if [[ ! -e $home/$template/.git ]]; then
	echo "$template is not cloned: add it to repos.txt and run scripts/clone.sh" >&2
	exit 1
fi

# files <dir>: the boilerplate files in a clone, tracked or untracked but
# not ignored.
files() { git -C "$1" ls-files -co --exclude-standard -- "${paths[@]}"; }

# compare <name>: prints one line per boilerplate file that differs, and
# with --diff its diff.
compare() {
	local file ours theirs kind
	while read -r file; do
		ours="$home/$template/$file" theirs="$home/$1/$file"
		if [[ ! -e $theirs ]]; then
			kind=missing theirs=/dev/null
		elif [[ ! -e $ours ]]; then
			kind=extra ours=/dev/null
		elif ! cmp -s "$ours" "$theirs"; then
			kind=changed
		else
			continue
		fi
		echo "  $kind: $file"
		if $show_diff; then
			diff -u --label "$template/$file" --label "$1/$file" "$ours" "$theirs" || true
		fi
	done < <({ files "$home/$template" && files "$home/$1"; } | sort -u)
}

for name in "${plugins[@]}"; do
	if [[ ! -e $home/$name/.git ]]; then
		echo "not cloned: $name"
		continue
	fi
	report="$(compare "$name")"
	if [[ -z $report ]]; then
		echo "clean: $name"
	else
		echo "differs: $name"
		echo "$report"
	fi
done
