#!/usr/bin/env bash
# Usage: scripts/drift.sh [--diff] [<plugin>...]
#
# Reports, for each Language Plugin clone in the home's manifest
# (repos.gitconfig), or for each named one, the boilerplate files that
# differ from the template clone: changed, missing or extra. The boilerplate
# files are those that boilerplate.txt lists. With --diff, it also shows
# each difference. Plugins may differ on purpose, so the report never
# fails on a difference and changes no file. It exits 1 when the template
# is not cloned or boilerplate.txt lists no file, and 2 on a wrong
# argument.
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
paths=()
while read -r line || [[ -n $line ]]; do
	read -r path _ <<<"${line%%#*}"
	[[ -n $path ]] || continue
	paths+=("$path")
done <"$home/boilerplate.txt"
if ((${#paths[@]} == 0)); then
	echo "boilerplate.txt lists no file" >&2
	exit 1
fi

# The Language Plugins in the manifest.
plugins=()
while read -r key _; do
	name=${key#repo.} && name=${name%.github}
	[[ $name == codestyle-*.nvim && $name != "$template" ]] || continue
	plugins+=("$name")
done < <(git config -f "$home/repos.gitconfig" --get-regexp '^repo\..+\.github$')

for name in "${named[@]}"; do
	[[ " ${plugins[*]} " == *" ""$name"" "* ]] || {
		echo "$name is not a Language Plugin in repos.gitconfig" >&2
		usage
	}
done
((${#named[@]} == 0)) || plugins=("${named[@]}")

if [[ ! -e $home/$template/.git ]]; then
	echo "$template is not cloned: add it to repos.gitconfig and run scripts/clone.sh" >&2
	exit 1
fi

# list_boilerplate <dir>: the boilerplate files in a clone, tracked or
# untracked but not ignored, each ended by a NUL byte.
list_boilerplate() { git -C "$1" ls-files -z -co --exclude-standard -- "${paths[@]}"; }

# compare <name>: prints one line per boilerplate file that differs, and
# with --diff its diff.
compare() {
	local file template_file plugin_file kind
	while read -r -d '' file; do
		template_file="$home/$template/$file" plugin_file="$home/$1/$file"
		if [[ ! -e $plugin_file ]]; then
			kind=missing plugin_file=/dev/null
		elif [[ ! -e $template_file ]]; then
			kind=extra template_file=/dev/null
		elif ! cmp -s "$template_file" "$plugin_file"; then
			kind=changed
		else
			continue
		fi
		echo "  $kind: $file"
		if $show_diff; then
			diff -u --label "$template/$file" --label "$1/$file" "$template_file" "$plugin_file" || true
		fi
	done < <({ list_boilerplate "$home/$template" && list_boilerplate "$home/$1"; } | sort -zu)
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
