#!/usr/bin/env bash
# Tests for scripts/protect.sh against a fake GitHub.
# Each test runs the script as the operator would, in a temporary home
# with its own manifest. A fake `gh` on PATH keeps each repo's branches
# and their protection in folders, and logs each change. The tests check
# those folders, the summary and the exit code.
set -euo pipefail

script="$(cd "$(dirname "$0")/.." && pwd)/scripts/protect.sh"

# The five required checks of Core ADR-0017.
checks='["Format check with StyLua","Spell check with typos","Tests (Neovim stable)","Tests (Neovim v0.11.7)","Type check with lua-language-server"]'

# Isolate the tests from the operator's Git config.
setup_git() {
	export GIT_CONFIG_NOSYSTEM=1
	export GIT_CONFIG_GLOBAL="$tmp/gitconfig"
	git config --global init.defaultBranch main
}

# make_gh: a fake `gh api` that serves $github/<owner>/<repo>/<branch>/.
make_gh() {
	github="$tmp/github"
	mkdir -p "$tmp/bin" "$github"
	cat >"$tmp/bin/gh" <<'GH'
#!/usr/bin/env bash
# Fake `gh api [--method M] repos/<o>/<r>/branches/<b>[/protection]
# [--silent] [--input -]`. A file `fail` in a branch folder makes each
# GET of its protection fail with that file's text.
set -euo pipefail
[[ $1 == api ]] || exit 99
shift
method=GET path=
while (($#)); do
	case $1 in
	--method) method=$2 && shift ;;
	--silent) ;;
	--input) [[ $2 == - ]] || exit 99 && shift ;;
	repos/*) path=$1 ;;
	*) echo "fake gh: unknown argument $1" >&2 && exit 99 ;;
	esac
	shift
done
[[ $path =~ ^repos/([^/]+/[^/]+)/branches/([^/]+)(/protection)?$ ]] || exit 99
dir="$FAKE_GITHUB/${BASH_REMATCH[1]}/${BASH_REMATCH[2]}"
if [[ ! -d $dir ]]; then
	echo "gh: Branch not found (HTTP 404)" >&2
	exit 1
fi
[[ -n ${BASH_REMATCH[3]} ]] || exit 0
case $method in
GET)
	if [[ -e $dir/fail ]]; then
		cat "$dir/fail" >&2
		exit 1
	elif [[ ! -e $dir/protection.json ]]; then
		echo "gh: Branch not protected (HTTP 404)" >&2
		exit 1
	fi
	cat "$dir/protection.json"
	;;
PUT)
	jq '{
		required_status_checks: (.required_status_checks | {strict, checks,
			contexts: [.checks[].context]}),
		enforce_admins: {enabled: .enforce_admins}
	} + (with_entries(select(.key | IN("required_linear_history",
		"allow_force_pushes", "allow_deletions", "block_creations",
		"required_conversation_resolution", "lock_branch", "allow_fork_syncing")))
		| map_values({enabled: (. // false)}))
	+ (if .required_pull_request_reviews then
		{required_pull_request_reviews: .required_pull_request_reviews}
		else {} end)' >"$dir/protection.json"
	echo "${BASH_REMATCH[1]} ${BASH_REMATCH[2]}" >>"$FAKE_GITHUB/writes"
	;;
esac
GH
	chmod +x "$tmp/bin/gh"
	export FAKE_GITHUB="$github" PATH="$tmp/bin:$PATH"
}

# make_repo <owner/repo> <branch>...: a GitHub repo with these branches.
make_repo() {
	local repo=$1 branch
	shift
	for branch in "$@"; do mkdir -p "$github/$repo/$branch"; done
}

# make_home <owner/repo>...: a home whose manifest lists these repos.
make_home() {
	home="$tmp/home"
	git init -q "$home"
	mkdir "$home/scripts"
	cp "$script" "$home/scripts/protect.sh"
	: >"$home/repos.txt"
	local repo
	for repo in "$@"; do add_entry "$repo"; done
}

add_entry() { echo "${1#*/} https://github.com/$1.git" >>"$home/repos.txt"; }

# run_protect: runs the script from outside the home; sets $out and
# $status.
run_protect() {
	status=0
	out="$(cd "$tmp" && bash "$home/scripts/protect.sh" 2>&1)" || status=$?
}

fail() {
	echo "  $*"
	echo "  output was:"
	sed 's/^/    /' <<<"$out"
	exit 1
}

writes() { cat "$github/writes" 2>/dev/null || true; }

expect_status() { [[ $status -eq $1 ]] || fail "expected exit $1, got $status"; }
expect_output() { grep -qE "$1" <<<"$out" || fail "expected output matching: $1"; }

# expect_protected <owner/repo> <branch>: the branch requires the five
# checks, from GitHub Actions, also for admins.
expect_protected() {
	local file="$github/$1/$2/protection.json"
	[[ -e $file ]] || fail "$1 $2 is not protected"
	jq -e --argjson checks "$checks" '
		([.required_status_checks.checks[].context] | sort) == $checks
		and all(.required_status_checks.checks[]; .app_id == 15368)
		and .enforce_admins.enabled' "$file" >/dev/null ||
		fail "$1 $2 has the wrong protection: $(cat "$file")"
}

test_unprotected_repo_gets_the_five_checks_on_main_and_develop() {
	make_gh
	make_repo example/alpha main develop
	make_home example/alpha
	run_protect
	expect_status 0
	expect_protected example/alpha main
	expect_protected example/alpha develop
	expect_output "^protected: alpha main$"
	expect_output "^protected: alpha develop$"
}

test_second_run_changes_nothing() {
	make_gh
	make_repo example/alpha main develop
	make_home example/alpha
	run_protect
	local before
	before="$(writes)"
	run_protect
	expect_status 0
	[[ "$(writes)" == "$before" ]] || fail "the second run changed protection"
	expect_output "^up to date: alpha main$"
	expect_output "^up to date: alpha develop$"
}

test_new_manifest_line_is_protected_on_next_run() {
	make_gh
	make_repo example/alpha main develop
	make_repo example/beta main develop
	make_home example/alpha
	run_protect
	add_entry example/beta
	run_protect
	expect_status 0
	expect_protected example/beta main
	expect_protected example/beta develop
	expect_output "^protected: beta main$"
	expect_output "^up to date: alpha main$"
}

test_changed_protection_is_set_again() {
	make_gh
	make_repo example/alpha main develop
	make_home example/alpha
	run_protect
	jq '.allow_force_pushes.enabled = true | .required_status_checks.checks |= .[1:]' \
		"$github/example/alpha/main/protection.json" >"$tmp/changed.json"
	mv "$tmp/changed.json" "$github/example/alpha/main/protection.json"
	run_protect
	expect_status 0
	expect_protected example/alpha main
	jq -e '.allow_force_pushes.enabled == false' "$github/example/alpha/main/protection.json" >/dev/null ||
		fail "force pushes are still allowed"
	expect_output "^protected: alpha main$"
	expect_output "^up to date: alpha develop$"
}

test_missing_branch_fails_after_the_other_repos() {
	make_gh
	make_repo example/alpha main
	make_repo example/beta main develop
	make_home example/alpha example/beta
	run_protect
	expect_status 1
	expect_output "^failed: alpha develop"
	expect_protected example/alpha main
	expect_protected example/beta develop
}

test_ssh_url_and_comments_in_the_manifest() {
	make_gh
	make_repo example/alpha main develop
	make_home
	printf '# The codestyle repos\n\n  alpha  git@github.com:example/alpha.git  # the first\n' \
		>"$home/repos.txt"
	run_protect
	expect_status 0
	expect_protected example/alpha main
	expect_output "^protected: alpha develop$"
}

test_url_that_is_not_on_github_fails() {
	make_gh
	make_repo example/beta main develop
	make_home
	echo "alpha https://example.com/alpha.git" >>"$home/repos.txt"
	add_entry example/beta
	run_protect
	expect_status 1
	expect_output "^failed: alpha .*not a GitHub"
	expect_protected example/beta main
}

test_rule_set_by_hand_is_turned_off() {
	make_gh
	make_repo example/alpha main develop
	make_home example/alpha
	run_protect
	jq '.required_linear_history.enabled = true' \
		"$github/example/alpha/main/protection.json" >"$tmp/changed.json"
	mv "$tmp/changed.json" "$github/example/alpha/main/protection.json"
	run_protect
	expect_status 0
	jq -e '.required_linear_history.enabled == false' "$github/example/alpha/main/protection.json" >/dev/null ||
		fail "linear history is still required"
	expect_output "^protected: alpha main$"
}

test_failing_read_of_protection_fails_without_a_change() {
	make_gh
	make_repo example/alpha main develop
	make_home example/alpha
	echo "gh: Must have admin rights to Repository. (HTTP 403)" >"$github/example/alpha/main/fail"
	run_protect
	expect_status 1
	expect_output "^failed: alpha main \\(gh: Must have admin rights"
	[[ "$(writes)" != *"example/alpha main"* ]] || fail "main was changed"
	expect_protected example/alpha develop
}

test_manifest_line_without_url_fails() {
	make_gh
	make_home
	echo "alpha" >"$home/repos.txt"
	run_protect
	expect_status 1
	expect_output "^failed: alpha \\(no GitHub URL\\)$"
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
