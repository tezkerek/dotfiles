#!/usr/bin/env zsh

source ${0:A:h}/jjw.zsh

TEST_DIR=$(mktemp -d)
trap "rm -rf $TEST_DIR" EXIT

typeset -gi FAILS=0

# Strip ANSI CSI (color) escape sequences so assertions compare content, not color.
function strip_ansi {
    print -r -- "$1" | sed $'s/\e\\[[0-9;]*m//g'
}

# assert_eq <label> <expected> <actual>
function assert_eq {
    local label=$1 expected=$2 actual=$3
    if [[ $expected == $actual ]]; then
        print "PASS: $label"
    else
        print "FAIL: $label"
        print "    expected: [$expected]"
        print "    actual:   [$actual]"
        (( FAILS++ ))
    fi
}

# Make a minimal git repo with an initial commit on branch $2 (default main).
# Usage: mkgit <dir> [branch]
function mkgit {
    local dir=$1 branch=${2:-main}
    mkdir -p "$dir"
    git -C "$dir" init -q -b "$branch"
    git -C "$dir" config user.email test@example.com
    git -C "$dir" config user.name test
    print "init" > "$dir/README"
    git -C "$dir" add -A
    git -C "$dir" commit -qm "initial"
}

# --- _jjw_classify ----------------------------------------------------------

assert_eq "classify main -> trunk"        trunk   "$(_jjw_classify main)"
assert_eq "classify master -> trunk"      trunk   "$(_jjw_classify master)"
assert_eq "classify develop -> trunk"     trunk   "$(_jjw_classify develop)"
assert_eq "classify release/* -> trunk"   trunk   "$(_jjw_classify release/1.0)"
assert_eq "classify empty -> trunk"       trunk   "$(_jjw_classify '')"
assert_eq "classify feature -> feature"   feature "$(_jjw_classify my-feature)"
assert_eq "classify releasey -> feature"  feature "$(_jjw_classify releasey)"

# --- _jjw_repo_type ---------------------------------------------------------

mkgit "$TEST_DIR/plain-git"
assert_eq "repo_type git"      git "$(_jjw_repo_type "$TEST_DIR/plain-git")"
mkdir -p "$TEST_DIR/not-a-repo"
assert_eq "repo_type non-repo" ""  "$(_jjw_repo_type "$TEST_DIR/not-a-repo")"

# --- git trunk detection: precedence ---------------------------------------

# only develop exists
mkgit "$TEST_DIR/only-develop" develop
assert_eq "git_trunk develop only" develop "$(_jjw_git_trunk "$TEST_DIR/only-develop")"

# master + develop -> master wins
mkgit "$TEST_DIR/master-dev" master
git -C "$TEST_DIR/master-dev" branch develop
assert_eq "git_trunk master over develop" master "$(_jjw_git_trunk "$TEST_DIR/master-dev")"

# main + master + develop -> main wins
mkgit "$TEST_DIR/all-three" main
git -C "$TEST_DIR/all-three" branch master
git -C "$TEST_DIR/all-three" branch develop
assert_eq "git_trunk main over all" main "$(_jjw_git_trunk "$TEST_DIR/all-three")"

# --- git trunk detection: upstream preference -------------------------------

# A repo has both main and master locally; current branch's upstream is master.
# Set up an "origin" bare repo to track.
git init -q --bare "$TEST_DIR/upstream.git"
mkgit "$TEST_DIR/up-pref" main
git -C "$TEST_DIR/up-pref" branch master
git -C "$TEST_DIR/up-pref" remote add origin "$TEST_DIR/upstream.git"
git -C "$TEST_DIR/up-pref" push -q origin main master
# Put HEAD on master with upstream origin/master.
git -C "$TEST_DIR/up-pref" switch -q master
git -C "$TEST_DIR/up-pref" branch --set-upstream-to=origin/master master
# Even though main has higher precedence, upstream says master -> master.
assert_eq "git_trunk upstream preference" master "$(_jjw_git_trunk "$TEST_DIR/up-pref")"

# --- git ref detection ------------------------------------------------------

mkgit "$TEST_DIR/ref-check" main
git -C "$TEST_DIR/ref-check" switch -qc my-feature
assert_eq "git_ref feature" my-feature "$(_jjw_git_ref "$TEST_DIR/ref-check")"

# --- st: git trunk case -----------------------------------------------------

mkgit "$TEST_DIR/st-trunk" main
out=$(strip_ansi "$(_jjw_st_repo "$TEST_DIR/st-trunk")")
assert_eq "st git trunk single line" "st-trunk  [main]" "$out"

# --- st: git feature case with extra commits --------------------------------

mkgit "$TEST_DIR/st-feat" main
git -C "$TEST_DIR/st-feat" switch -qc my-feature
print a > "$TEST_DIR/st-feat/a"
git -C "$TEST_DIR/st-feat" add -A
git -C "$TEST_DIR/st-feat" commit -qm "add a"
print b > "$TEST_DIR/st-feat/b"
git -C "$TEST_DIR/st-feat" add -A
git -C "$TEST_DIR/st-feat" commit -qm "add b"
out=$(strip_ansi "$(_jjw_st_repo "$TEST_DIR/st-feat")")
# First line is the header, then two commit lines (newest first from git log).
header=${out%%$'\n'*}
assert_eq "st git feature header" "st-feat  [my-feature]" "$header"
# Both commit subjects present, indented.
if [[ $out == *$'\n    '*"add a"* && $out == *$'\n    '*"add b"* ]]; then
    print "PASS: st git feature lists extra commits"
else
    print "FAIL: st git feature lists extra commits"
    print "    actual: [$out]"
    (( FAILS++ ))
fi

# --- discovery --------------------------------------------------------------

mkdir -p "$TEST_DIR/ws"
mkgit "$TEST_DIR/ws/repo-a" main
mkgit "$TEST_DIR/ws/repo-b" main
mkdir -p "$TEST_DIR/ws/plain-dir"
(
    cd "$TEST_DIR/ws"
    found=$(_jjw_discover)
    # Should list repo-a and repo-b, not plain-dir. Order is glob (sorted).
    print "$found"
) > "$TEST_DIR/discover.out"
disc=$(<"$TEST_DIR/discover.out")
if [[ $disc == *repo-a* && $disc == *repo-b* && $disc != *plain-dir* ]]; then
    print "PASS: discover finds child repos, skips non-repos"
else
    print "FAIL: discover finds child repos, skips non-repos"
    print "    actual: [$disc]"
    (( FAILS++ ))
fi

# --- pull: git paths (offline, using local bare remotes) -------------------

# Helper: make a working repo + its own bare origin, pushed on main.
# Usage: mkgit_origin <workdir> <originbare>
function mkgit_origin {
    local work=$1 origin=$2
    git init -q --bare "$origin"
    mkgit "$work" main
    git -C "$work" remote add origin "$origin"
    git -C "$work" push -q -u origin main
}

PULLWS="$TEST_DIR/pullws"
mkdir -p "$PULLWS"

# (1) trunk, behind origin -> should ff-pull.
mkgit_origin "$PULLWS/on-trunk" "$TEST_DIR/on-trunk.git"
# advance origin from a second clone
git clone -q "$TEST_DIR/on-trunk.git" "$TEST_DIR/on-trunk-clone"
git -C "$TEST_DIR/on-trunk-clone" config user.email t@e.com
git -C "$TEST_DIR/on-trunk-clone" config user.name t
print more > "$TEST_DIR/on-trunk-clone/extra"
git -C "$TEST_DIR/on-trunk-clone" add -A
git -C "$TEST_DIR/on-trunk-clone" commit -qm "upstream commit"
git -C "$TEST_DIR/on-trunk-clone" push -q origin main

# (2) clean feature -> should switch to main + pull.
mkgit_origin "$PULLWS/clean-feat" "$TEST_DIR/clean-feat.git"
git -C "$PULLWS/clean-feat" switch -qc my-feature

# (3) dirty feature -> should fetch trunk only, stay put.
mkgit_origin "$PULLWS/dirty-feat" "$TEST_DIR/dirty-feat.git"
git -C "$PULLWS/dirty-feat" switch -qc my-feature
print dirty > "$PULLWS/dirty-feat/uncommitted"   # untracked => dirty

# jjw sends all VCS chatter to stderr (the pull collector reads only stdout);
# silence it here so the test output stays clean.
pull_out=$(cd "$PULLWS" && jjw pull on-trunk clean-feat dirty-feat 2>/dev/null)

# Assert output ordering + glyphs + messages.
if [[ $pull_out == *"✓ on-trunk"*"pulled"* ]]; then
    print "PASS: pull trunk ff-pull line"
else
    print "FAIL: pull trunk ff-pull line"; print "    actual: [$pull_out]"; (( FAILS++ ))
fi
if [[ $pull_out == *"✓ clean-feat"*"switched to main"* ]]; then
    print "PASS: pull clean feature switches to trunk"
else
    print "FAIL: pull clean feature switches to trunk"; print "    actual: [$pull_out]"; (( FAILS++ ))
fi
if [[ $pull_out == *"· dirty-feat"*"fetched trunk only"* ]]; then
    print "PASS: pull dirty feature fetches trunk only"
else
    print "FAIL: pull dirty feature fetches trunk only"; print "    actual: [$pull_out]"; (( FAILS++ ))
fi
# Effects: on-trunk advanced, clean-feat now on main, dirty-feat still on feature.
assert_eq "pull effect: clean-feat on trunk" main "$(_jjw_git_ref "$PULLWS/clean-feat")"
assert_eq "pull effect: dirty-feat stays on feature" my-feature "$(_jjw_git_ref "$PULLWS/dirty-feat")"
# on-trunk should now contain the upstream commit.
if git -C "$PULLWS/on-trunk" log --oneline | grep -q "upstream commit"; then
    print "PASS: pull effect: on-trunk fast-forwarded"
else
    print "FAIL: pull effect: on-trunk fast-forwarded"; (( FAILS++ ))
fi
# Stable ordering: on-trunk before clean-feat before dirty-feat.
line_order=$(print -r -- "$pull_out" | grep -n -e on-trunk -e clean-feat -e dirty-feat | cut -d: -f1 | tr '\n' ' ')
assert_eq "pull output in stable dir order" "1 2 3 " "$line_order"

# ============================================================================
# jj-path tests — only if jj is installed.
# ============================================================================

if command -v jj >/dev/null 2>&1; then
    # Build a jj fixture with a "main" bookmark tracked on an origin remote.
    # Create an origin repo, then a working repo that fetches from it.
    JJ_ORIGIN="$TEST_DIR/jj-origin"
    mkdir -p "$JJ_ORIGIN"
    ( cd "$JJ_ORIGIN"
      jj git init . >/dev/null 2>&1
      print init > f
      jj describe -m "initial" >/dev/null 2>&1
      jj bookmark create main -r @ >/dev/null 2>&1
      # Make main non-empty so the working copy after fetch is stable.
      jj new main >/dev/null 2>&1
    )

    JJ_WORK="$TEST_DIR/jj-work"
    jj git clone "$JJ_ORIGIN" "$JJ_WORK" >/dev/null 2>&1

    if [[ -d "$JJ_WORK/.jj" ]]; then
        assert_eq "jj repo_type" jj "$(_jjw_repo_type "$JJ_WORK")"
        # trunk detection: main@origin should exist after clone.
        assert_eq "jj_trunk main@origin" main "$(_jjw_jj_trunk "$JJ_WORK")"

        # Create a feature bookmark with an extra commit + empty @ on top.
        ( cd "$JJ_WORK"
          jj new main -m "feat 1" >/dev/null 2>&1
          print x > x
          jj bookmark create my-feature -r @ >/dev/null 2>&1
          jj new >/dev/null 2>&1   # empty @ on top of feature
        )
        assert_eq "jj_ref feature" my-feature "$(_jjw_jj_ref "$JJ_WORK")"
        assert_eq "jj classify feature" feature "$(_jjw_classify "$(_jjw_jj_ref "$JJ_WORK")")"

        # st on the feature: header + commit lines including the empty @.
        out=$(strip_ansi "$(_jjw_st_repo "$JJ_WORK")")
        header=${out%%$'\n'*}
        assert_eq "jj st feature header" "jj-work  [my-feature]" "$header"
        if [[ $out == *"feat 1"* && $out == *"(empty)"* ]]; then
            print "PASS: jj st lists commits incl empty @"
        else
            print "FAIL: jj st lists commits incl empty @"
            print "    actual: [$out]"
            (( FAILS++ ))
        fi

        # bookmark existence helpers
        if _jjw_jj_bookmark_exists "$JJ_WORK" my-feature; then
            print "PASS: jj bookmark_exists true"
        else
            print "FAIL: jj bookmark_exists true"; (( FAILS++ ))
        fi
        if _jjw_jj_bookmark_exists "$JJ_WORK" nope-nonexistent; then
            print "FAIL: jj bookmark_exists false"; (( FAILS++ ))
        else
            print "PASS: jj bookmark_exists false"
        fi
    else
        print "SKIP: jj clone fixture failed to build"
    fi
else
    print "SKIP: jj not installed — jj-path tests skipped"
fi

# ============================================================================

print ""
if (( FAILS )); then
    print "FAILED: $FAILS test(s) failed."
    exit 1
else
    print "All tests passed!"
fi
