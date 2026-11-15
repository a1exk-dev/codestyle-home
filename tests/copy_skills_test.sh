#!/usr/bin/env bash
# Tests for scripts/copy-skills.sh on throwaway Git repos.
# Each test runs the script as the operator would, in a temporary home
# with its own skills, policies, manifest and clones, and checks the
# folders, the summary and the exit code.
set -euo pipefail

script="$(cd "$(dirname "$0")/.." && pwd)/scripts/copy-skills.sh"

# Isolate the tests from the operator's Git config.
setup_git() {
	export GIT_CONFIG_NOSYSTEM=1
	export GIT_CONFIG_GLOBAL="$tmp/gitconfig"
	git config --global user.name Test
	git config --global user.email test@example.com
	git config --global init.defaultBranch main
}

# make_home: a home with the three process skills, their policies, one
# other skill, and an empty manifest.
make_home() {
	home="$tmp/home"
	git init -q "$home"
	mkdir -p "$home/scripts" "$home/docs/agents" "$home/.claude/skills"
	cp "$script" "$home/scripts/copy-skills.sh"
	local skill
	for skill in git-commit semver common-changelog tdd; do
		mkdir -p "$home/.agents/skills/$skill/references"
		echo "$skill skill" >"$home/.agents/skills/$skill/SKILL.md"
		echo "$skill reference" >"$home/.agents/skills/$skill/references/one.md"
		ln -s "../../.agents/skills/$skill" "$home/.claude/skills/$skill"
	done
	for policy in commit semver changelog domain; do
		echo "# $policy policy" >"$home/docs/agents/$policy-policy.md"
	done
	: >"$home/repos.gitconfig"
}

# make_clone <name>: a committed clone in the home, listed in the manifest.
make_clone() {
	local dir="$home/$1"
	printf '[repo "%s"]\n\tgithub = example/%s\n' "$1" "$1" >>"$home/repos.gitconfig"
	mkdir -p "$dir"
	echo "$1" >"$dir/README.md"
	git -C "$dir" init -q
	git -C "$dir" add -A
	git -C "$dir" commit -q -m one
}

# run_copy [args]: runs the script from outside the home; sets $out and
# $status.
run_copy() {
	status=0
	out="$(cd "$tmp" && bash "$home/scripts/copy-skills.sh" "$@" 2>&1)" || status=$?
}

fail() {
	echo "  $*"
	echo "  output was:"
	sed 's/^/    /' <<<"$out"
	exit 1
}

expect_status() { [[ $status -eq $1 ]] || fail "expected exit $1, got $status"; }
expect_output() { grep -qE "$1" <<<"$out" || fail "expected output matching: $1"; }

# expect_copied <name>: the clone holds the home's three process skills,
# their Claude Code links and their policies, and no other skill.
expect_copied() {
	local dir="$home/$1" skill policy
	for skill in git-commit semver common-changelog; do
		diff -r "$home/.agents/skills/$skill" "$dir/.agents/skills/$skill" >/dev/null ||
			fail "$1 has no copy of $skill"
		[[ "$(readlink "$dir/.claude/skills/$skill")" == "../../.agents/skills/$skill" ]] ||
			fail "$1 has no Claude Code link to $skill"
	done
	for policy in commit semver changelog; do
		cmp -s "$home/docs/agents/$policy-policy.md" "$dir/docs/agents/$policy-policy.md" ||
			fail "$1 has no copy of the $policy policy"
	done
	[[ ! -e $dir/.agents/skills/tdd && ! -e $dir/docs/agents/domain-policy.md ]] ||
		fail "$1 got a file that is not a process skill or policy"
}

test_clone_gets_the_process_skills_and_policies() {
	make_home
	make_clone codestyle.nvim
	run_copy
	expect_status 0
	expect_copied codestyle.nvim
	expect_output "^copied: codestyle.nvim$"
}

# commit_all <name>: commits the copies, as the repo's pull request would.
commit_all() {
	git -C "$home/$1" add -A
	git -C "$home/$1" commit -q -m copies
}

test_second_run_changes_nothing() {
	make_home
	make_clone codestyle.nvim
	run_copy
	commit_all codestyle.nvim
	run_copy
	expect_status 0
	expect_output "^up to date: codestyle.nvim$"
	[[ -z "$(git -C "$home/codestyle.nvim" status --porcelain)" ]] || fail "the clone changed"
}

test_home_change_replaces_the_copy() {
	make_home
	make_clone codestyle.nvim
	run_copy
	commit_all codestyle.nvim
	echo "new semver" >"$home/.agents/skills/semver/SKILL.md"
	rm "$home/.agents/skills/semver/references/one.md"
	echo "# new commit policy" >"$home/docs/agents/commit-policy.md"
	run_copy
	expect_status 0
	expect_output "^copied: codestyle.nvim$"
	expect_copied codestyle.nvim
	[[ ! -e $home/codestyle.nvim/.agents/skills/semver/references/one.md ]] ||
		fail "a file removed from the home stays in the copy"
}

test_check_names_stale_copies_and_changes_nothing() {
	make_home
	make_clone codestyle.nvim
	make_clone codestyle-json.nvim
	run_copy
	commit_all codestyle.nvim
	commit_all codestyle-json.nvim
	echo "edited here" >"$home/codestyle-json.nvim/docs/agents/semver-policy.md"
	git -C "$home/codestyle-json.nvim" commit -q -am edit
	run_copy --check
	expect_status 1
	expect_output "^up to date: codestyle.nvim$"
	expect_output "^stale: codestyle-json.nvim$"
	expect_output "^  docs/agents/semver-policy.md$"
	[[ "$(cat "$home/codestyle-json.nvim/docs/agents/semver-policy.md")" == "edited here" ]] ||
		fail "--check changed a file"
}

test_check_passes_when_every_copy_is_up_to_date() {
	make_home
	make_clone codestyle.nvim
	run_copy
	run_copy --check
	expect_status 0
	expect_output "^up to date: codestyle.nvim$"
}

test_clone_with_uncommitted_changes_is_skipped_and_named() {
	make_home
	make_clone codestyle.nvim
	echo "local" >"$home/codestyle.nvim/README.md"
	run_copy
	expect_status 0
	expect_output "^skipped \\(uncommitted changes\\): codestyle.nvim$"
	[[ ! -e $home/codestyle.nvim/.agents ]] || fail "the skipped clone changed"
}

test_repo_that_is_not_cloned_is_named() {
	make_home
	printf '[repo "codestyle.nvim"]\n\tgithub = example/codestyle.nvim\n' >>"$home/repos.gitconfig"
	run_copy
	expect_status 0
	expect_output "^not cloned: codestyle.nvim$"
}

test_unknown_option_fails() {
	make_home
	run_copy --force
	expect_status 2
	expect_output "usage"
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
