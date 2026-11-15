#!/usr/bin/env bash
# Tests for scripts/clone.sh on throwaway Git repos.
# Each test runs the script as the operator would, in a temporary home
# with its own manifest. A fake `gh` on PATH clones from bare remotes in
# folders. The tests check folders, summary and exit code.
set -euo pipefail

script="$(cd "$(dirname "$0")/.." && pwd)/scripts/clone.sh"

# Isolate the tests from the operator's Git config.
setup_git() {
	export GIT_CONFIG_NOSYSTEM=1
	export GIT_CONFIG_GLOBAL="$tmp/gitconfig"
	git config --global user.name Test
	git config --global user.email test@example.com
	git config --global init.defaultBranch main
}

# make_gh: a fake `gh repo clone <owner/name> <dir> -- <git args>` that
# clones the bare remote $FAKE_GITHUB/<owner/name>.git.
make_gh() {
	mkdir -p "$tmp/bin" "$tmp/remotes"
	cat >"$tmp/bin/gh" <<'GH'
#!/usr/bin/env bash
set -euo pipefail
[[ $1 == repo && $2 == clone && $5 == -- ]] || exit 99
exec git clone "${@:6}" "$FAKE_GITHUB/$3.git" "$4"
GH
	chmod +x "$tmp/bin/gh"
	export FAKE_GITHUB="$tmp/remotes" PATH="$tmp/bin:$PATH"
}

# make_remote <name>: a bare remote with one commit on main.
make_remote() {
	local work="$tmp/work-$1"
	git init -q --bare "$tmp/remotes/example/$1.git"
	git clone -q "$tmp/remotes/example/$1.git" "$work" 2>/dev/null
	echo one >"$work/file"
	git -C "$work" add file
	git -C "$work" commit -q -m one
	git -C "$work" push -q origin main
}

# push_remote <name> <text>: a new commit on the remote's main.
push_remote() {
	local work="$tmp/work-$1"
	echo "$2" >"$work/file"
	git -C "$work" commit -q -am "$2"
	git -C "$work" push -q origin main
}

# make_home <name>...: a home repo whose manifest lists the given remotes.
make_home() {
	home="$tmp/home"
	git init -q "$home"
	mkdir "$home/scripts"
	cp "$script" "$home/scripts/clone.sh"
	: >"$home/repos.gitconfig"
	for name in "$@"; do add_entry "$name" "example/$name"; done
}

# add_entry <folder> <owner/name>: one more repo in the manifest.
add_entry() { printf '[repo "%s"]\n\tgithub = %s\n' "$1" "$2" >>"$home/repos.gitconfig"; }

# run_clone: runs the script from outside the home; sets $out and $status.
run_clone() {
	status=0
	out="$(cd "$tmp" && bash "$home/scripts/clone.sh" 2>&1)" || status=$?
}

fail() {
	echo "  $*"
	echo "  output was:"
	sed 's/^/    /' <<<"$out"
	exit 1
}

expect_status() { [[ $status -eq $1 ]] || fail "expected exit $1, got $status"; }
expect_output() { grep -qE "$1" <<<"$out" || fail "expected output matching: $1"; }
expect_file() { [[ "$(cat "$home/$1/file")" == "$2" ]] || fail "expected $1/file to be '$2'"; }

test_missing_repo_is_cloned() {
	make_remote alpha
	make_home alpha
	run_clone
	expect_status 0
	expect_file alpha one
	expect_output "cloned.*alpha"
}

test_clean_clone_behind_remote_is_fast_forwarded() {
	make_remote alpha
	make_home alpha
	run_clone
	push_remote alpha two
	run_clone
	expect_status 0
	expect_file alpha two
	expect_output "updated.*alpha"
}

test_clone_with_uncommitted_changes_is_skipped_and_named() {
	make_remote alpha
	make_home alpha
	run_clone
	echo local >"$home/alpha/file"
	push_remote alpha two
	run_clone
	expect_status 0
	expect_file alpha local
	expect_output "skipped.*uncommitted.*alpha"
}

test_diverged_clone_is_skipped_and_named() {
	make_remote alpha
	make_home alpha
	run_clone
	echo local >"$home/alpha/file"
	git -C "$home/alpha" commit -q -am local
	push_remote alpha two
	run_clone
	expect_status 0
	expect_file alpha local
	expect_output "skipped.*fast-forward.*alpha"
}

test_detached_head_is_skipped_and_named() {
	make_remote alpha
	make_home alpha
	run_clone
	git -C "$home/alpha" checkout -q --detach
	push_remote alpha two
	run_clone
	expect_status 0
	expect_file alpha one
	expect_output "skipped.*detached.*alpha"
}

test_second_run_changes_nothing() {
	make_remote alpha
	make_home alpha
	run_clone
	local before
	before="$(git -C "$home/alpha" rev-parse HEAD)"
	run_clone
	expect_status 0
	[[ "$(git -C "$home/alpha" rev-parse HEAD)" == "$before" ]] || fail "alpha moved"
	expect_output "up to date.*alpha"
}

test_new_manifest_line_is_cloned_on_next_run() {
	make_remote alpha
	make_remote beta
	make_home alpha
	run_clone
	add_entry beta example/beta
	run_clone
	expect_status 0
	expect_file beta one
	expect_output "cloned.*beta"
	expect_output "up to date.*alpha"
}

test_manifest_comments_and_other_keys_are_ignored() {
	make_remote alpha
	make_home
	printf '# The codestyle repos\n\n[repo "alpha"]\n\tgithub = example/alpha ; the first\n\tnote = x\n' \
		>"$home/repos.gitconfig"
	run_clone
	expect_status 0
	expect_file alpha one
	expect_output "cloned.*alpha"
}

test_folder_with_dots_is_cloned() {
	make_remote alpha
	make_home
	add_entry codestyle.nvim example/alpha
	run_clone
	expect_status 0
	expect_file codestyle.nvim one
}

test_failing_clone_exits_non_zero_after_the_other_repos() {
	make_remote beta
	make_home
	add_entry alpha example/missing
	add_entry beta example/beta
	run_clone
	expect_status 1
	expect_output "failed.*alpha"
	expect_file beta one
	expect_output "cloned.*beta"
}

test_failing_pull_exits_non_zero_after_the_other_repos() {
	make_remote alpha
	make_remote beta
	make_home alpha beta
	run_clone
	rm -rf "$tmp/remotes/example/alpha.git"
	push_remote beta two
	run_clone
	expect_status 1
	expect_output "failed.*alpha"
	expect_file beta two
}

test_folder_that_is_not_a_clone_fails() {
	make_remote alpha
	make_home alpha
	mkdir "$home/alpha"
	run_clone
	expect_status 1
	expect_output "failed.*alpha"
}

passed=0
failed=0
for test in $(declare -F | awk '{print $3}' | grep '^test_'); do
	tmp="$(mktemp -d)"
	if (setup_git && make_gh && "$test"); then
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
