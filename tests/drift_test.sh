#!/usr/bin/env bash
# Tests for scripts/drift.sh on throwaway Git repos.
# Each test runs the script as the operator would, in a temporary home
# with its own manifest, boilerplate keys and clones, and checks the
# report, the exit code and that no clone changes.
set -euo pipefail

script="$(cd "$(dirname "$0")/.." && pwd)/scripts/drift.sh"
template=codestyle-language-template.nvim

# Isolate the tests from the operator's Git config.
setup_git() {
	export GIT_CONFIG_NOSYSTEM=1
	export GIT_CONFIG_GLOBAL="$tmp/gitconfig"
	git config --global user.name Test
	git config --global user.email test@example.com
	git config --global init.defaultBranch main
}

# make_home <boilerplate path>...: a home whose manifest has one
# `boilerplate` key per path in the template's section, and no repo yet.
make_home() {
	home="$tmp/home"
	git init -q "$home"
	mkdir "$home/scripts"
	cp "$script" "$home/scripts/drift.sh"
	printf '[repo "%s"]\n' "$template" >"$home/repos.gitconfig"
	local path
	for path in "$@"; do printf '\tboilerplate = %s\n' "$path" >>"$home/repos.gitconfig"; done
}

# make_clone <name>: a committed clone in the home that holds the standard
# boilerplate, listed in the manifest.
make_clone() {
	local dir="$home/$1"
	printf '[repo "%s"]\n\tgithub = example/%s\n' "$1" "$1" >>"$home/repos.gitconfig"
	mkdir -p "$dir/test" "$dir/.github/workflows" "$dir/lua"
	echo "run the tests" >"$dir/test/run.lua"
	echo "how to contribute" >"$dir/CONTRIBUTING.md"
	echo "ci" >"$dir/.github/workflows/ci.yml"
	echo "$1 spec" >"$dir/lua/spec.lua"
	git -C "$dir" init -q
	git -C "$dir" add -A
	git -C "$dir" commit -q -m one
}

standard_home() {
	make_home .github/workflows/ci.yml test/run.lua CONTRIBUTING.md
	make_clone "$template"
}

# run_drift [args]: runs the script from outside the home; sets $out and
# $status.
run_drift() {
	status=0
	out="$(cd "$tmp" && bash "$home/scripts/drift.sh" "$@" 2>&1)" || status=$?
}

fail() {
	echo "  $*"
	echo "  output was:"
	sed 's/^/    /' <<<"$out"
	exit 1
}

expect_status() { [[ $status -eq $1 ]] || fail "expected exit $1, got $status"; }
expect_output() { grep -qE "$1" <<<"$out" || fail "expected output matching: $1"; }
expect_no_output() { ! grep -qE "$1" <<<"$out" || fail "expected no output matching: $1"; }

test_matching_plugin_is_clean() {
	standard_home
	make_clone codestyle-json.nvim
	run_drift
	expect_status 0
	expect_output "^clean: codestyle-json.nvim$"
}

test_changed_file_is_named() {
	standard_home
	make_clone codestyle-json.nvim
	echo "run the json tests" >"$home/codestyle-json.nvim/test/run.lua"
	run_drift
	expect_status 0
	expect_output "^differs: codestyle-json.nvim$"
	expect_output "^  changed: test/run.lua$"
}

test_missing_file_is_named() {
	standard_home
	make_clone codestyle-json.nvim
	git -C "$home/codestyle-json.nvim" rm -q CONTRIBUTING.md
	run_drift
	expect_status 0
	expect_output "^differs: codestyle-json.nvim$"
	expect_output "^  missing: CONTRIBUTING.md$"
	expect_no_output "changed"
}

test_boilerplate_file_the_template_lacks_is_named() {
	make_home test/run.lua .github/workflows/release.yml
	make_clone "$template"
	make_clone codestyle-json.nvim
	run_drift
	expect_status 0
	expect_output "^not in $template: .github/workflows/release.yml$"
	expect_output "^clean: codestyle-json.nvim$"
}

test_boilerplate_file_only_the_plugin_has_is_extra() {
	make_home test/run.lua .github/workflows/release.yml
	make_clone "$template"
	make_clone codestyle-json.nvim
	echo "release" >"$home/codestyle-json.nvim/.github/workflows/release.yml"
	run_drift
	expect_status 0
	expect_output "^differs: codestyle-json.nvim$"
	expect_output "^  extra: .github/workflows/release.yml$"
}

test_files_outside_the_boilerplate_keys_are_ignored_in_a_workflow_folder() {
	standard_home
	make_clone codestyle-json.nvim
	echo "nightly" >"$home/codestyle-json.nvim/.github/workflows/nightly.yml"
	run_drift
	expect_status 0
	expect_output "^clean: codestyle-json.nvim$"
}

test_files_outside_the_boilerplate_list_are_ignored() {
	standard_home
	make_clone codestyle-json.nvim
	echo "other" >"$home/codestyle-json.nvim/README.md"
	run_drift
	expect_status 0
	expect_output "^clean: codestyle-json.nvim$"
}

# snapshot: the content and Git state of every clone in the home.
snapshot() {
	local dir
	for dir in "$home"/codestyle-*.nvim; do
		(cd "$dir" && find . -path ./.git -prune -o -type f -print0 | sort -z | xargs -0 sha1sum)
		git -C "$dir" status --porcelain
		git -C "$dir" rev-parse HEAD
	done
}

test_report_changes_no_clone() {
	standard_home
	make_clone codestyle-json.nvim
	echo "run the json tests" >"$home/codestyle-json.nvim/test/run.lua"
	git -C "$home/codestyle-json.nvim" rm -q CONTRIBUTING.md
	echo "ci nightly" >"$home/codestyle-json.nvim/.github/workflows/ci.yml"
	local before
	before="$(snapshot)"
	run_drift
	expect_status 0
	run_drift --diff
	expect_status 0
	[[ "$(snapshot)" == "$before" ]] || fail "a clone changed"
}

test_only_language_plugins_are_reported() {
	standard_home
	make_clone codestyle.nvim
	make_clone codestyle-json.nvim
	run_drift
	expect_status 0
	expect_output "^clean: codestyle-json.nvim$"
	expect_no_output "codestyle.nvim|$template"
}

test_plugin_that_is_not_cloned_is_named() {
	standard_home
	printf '[repo "codestyle-json.nvim"]\n\tgithub = example/json\n' >>"$home/repos.gitconfig"
	run_drift
	expect_status 0
	expect_output "^not cloned: codestyle-json.nvim$"
}

test_missing_template_clone_fails() {
	make_home .github/workflows/ci.yml test/run.lua CONTRIBUTING.md
	printf '[repo "%s"]\n\tgithub = example/%s\n' "$template" "$template" >>"$home/repos.gitconfig"
	make_clone codestyle-json.nvim
	run_drift
	expect_status 1
	expect_output "$template.*scripts/clone.sh"
}

test_diff_shows_each_difference() {
	standard_home
	make_clone codestyle-json.nvim
	echo "run the json tests" >"$home/codestyle-json.nvim/test/run.lua"
	git -C "$home/codestyle-json.nvim" rm -q CONTRIBUTING.md
	echo "ci nightly" >"$home/codestyle-json.nvim/.github/workflows/ci.yml"
	run_drift --diff
	expect_status 0
	expect_output "^  changed: test/run.lua$"
	expect_output "^-run the tests$"
	expect_output "^\\+run the json tests$"
	expect_output "^-how to contribute$"
	expect_output "^\\+ci nightly$"
}

test_named_plugins_are_the_only_ones_reported() {
	standard_home
	make_clone codestyle-json.nvim
	make_clone codestyle-yaml.nvim
	run_drift codestyle-yaml.nvim
	expect_status 0
	expect_output "^clean: codestyle-yaml.nvim$"
	expect_no_output "codestyle-json.nvim"
}

test_unknown_option_fails() {
	standard_home
	run_drift --force
	expect_status 2
	expect_output "usage"
}

test_name_that_is_not_a_listed_plugin_fails() {
	standard_home
	make_clone codestyle-json.nvim
	run_drift codestyle-jsn.nvim
	expect_status 2
	expect_output "codestyle-jsn.nvim is not a Language Plugin in repos.gitconfig"
}

test_boilerplate_keys_of_other_repos_are_ignored() {
	standard_home
	make_clone codestyle-json.nvim
	printf '\tboilerplate = README.md ; not the template\n' >>"$home/repos.gitconfig"
	echo "other" >"$home/codestyle-json.nvim/README.md"
	run_drift
	expect_status 0
	expect_output "^clean: codestyle-json.nvim$"
}

test_template_without_boilerplate_keys_fails() {
	make_home
	make_clone "$template"
	make_clone codestyle-json.nvim
	run_drift
	expect_status 1
	expect_output "repos.gitconfig names no boilerplate file of $template"
}

test_non_ascii_file_name_is_compared() {
	make_home docs/é.md
	make_clone "$template"
	mkdir "$home/$template/docs"
	echo "same" >"$home/$template/docs/é.md"
	make_clone codestyle-json.nvim
	mkdir "$home/codestyle-json.nvim/docs"
	echo "same" >"$home/codestyle-json.nvim/docs/é.md"
	run_drift
	expect_status 0
	expect_output "^clean: codestyle-json.nvim$"
}

test_name_with_glob_characters_fails() {
	standard_home
	make_clone codestyle-json.nvim
	run_drift 'codestyle-*.nvim'
	expect_status 2
}

passed=0
failed=0
for test in $(declare -F | awk '{print $3}' | grep '^test_'); do
	tmp="$(mktemp -d)"
	if (setup_git && "$test"); then
		passed=$((passed + 1))
		echo "ok   $test"
	else
		failed=$((failed + 1))
		echo "FAIL $test"
	fi
	rm -rf "$tmp"
done
echo "$passed passed, $failed failed"
[[ $failed -eq 0 ]]
