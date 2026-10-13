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

# --- git trunk detection: origin/HEAD preference ----------------------------

# A stale master exists, but origin's default branch is develop.
git init -q --bare "$TEST_DIR/head-pref.git"
mkgit "$TEST_DIR/head-pref-seed" master
git -C "$TEST_DIR/head-pref-seed" branch develop
git -C "$TEST_DIR/head-pref-seed" remote add origin "$TEST_DIR/head-pref.git"
git -C "$TEST_DIR/head-pref-seed" push -q origin master develop
git -C "$TEST_DIR/head-pref.git" symbolic-ref HEAD refs/heads/develop
git clone -q "$TEST_DIR/head-pref.git" "$TEST_DIR/head-pref"
git -C "$TEST_DIR/head-pref" branch -q master origin/master
assert_eq "git_trunk origin/HEAD preference" develop "$(_jjw_git_trunk "$TEST_DIR/head-pref")"

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
# wip
# ============================================================================

# assert_has <label> <needle> <actual>
function assert_has {
    if [[ $3 == *"$2"* ]]; then
        print "PASS: $1"
    else
        print "FAIL: $1"
        print "    missing: [$2]"
        print "    actual:  [$3]"
        (( FAILS++ ))
    fi
}

# assert_lacks <label> <needle> <actual>
function assert_lacks {
    if [[ $3 != *"$2"* ]]; then
        print "PASS: $1"
    else
        print "FAIL: $1"
        print "    unexpected: [$2]"
        print "    actual:     [$3]"
        (( FAILS++ ))
    fi
}

# Commit lines under the branch/bookmark header line that starts with $1.
function wip_block {
    print -r -- "$2" | awk -v name="$1" 'index($0, "    " name) == 1 { f = 1; next } f && /^    [^ ]/ { f = 0 } f'
}

function _jjw_wip_slug { print o/r }
function _jjw_wip_prs {
    print -r -- $'feat-pushed\t7\tOPEN\tfalse\tAPPROVED\tpass'
    print -r -- $'feat-base\t3\tMERGED\tfalse\t\t'
    print -r -- $'g-pushed\t9\tOPEN\ttrue\t\tfail'
}

# --- wip: git ---------------------------------------------------------------

WIPGIT="$TEST_DIR/wip-git"
mkgit_origin "$WIPGIT" "$TEST_DIR/wip-git.git"
function gcommit { print $1 > "$WIPGIT/${1// /-}"; git -C "$WIPGIT" add -A; git -C "$WIPGIT" commit -qm "$1" }
git -C "$WIPGIT" branch -q g-merged
git -C "$WIPGIT" switch -qc g-pushed
gcommit "pushed one"
git -C "$WIPGIT" push -q -u origin g-pushed 2>/dev/null
gcommit "pushed two"
git -C "$WIPGIT" switch -q main
git -C "$WIPGIT" switch -qc g-local
gcommit "local one"
git -C "$WIPGIT" switch -qc g-stack
gcommit "stack one"

out=$(strip_ansi "$(cd "$WIPGIT" && jjw wip)")
assert_has   "wip git: no-PR branch not pushed"  "g-local  ↑ not pushed" "$out"
assert_has   "wip git: stacked branch parent"    "g-stack (HEAD)  ↑ not pushed  on g-local" "$out"
assert_has   "wip git: open PR labels"           "g-pushed  #9  draft  ✗ ci  ↑1" "$out"
assert_lacks "wip git: merged branch hidden"     "g-merged" "$out"
assert_has   "wip git: No PR before Open PRs"    "No PR" "${out%%Open PRs*}"
stack_block=$(wip_block g-stack "$out")
assert_has   "wip git: stack lists own commit"     "stack one" "$stack_block"
assert_lacks "wip git: stack omits parent commits" "local one" "$stack_block"

# --- wip: jj ----------------------------------------------------------------

if command -v jj >/dev/null 2>&1; then
    : > "$TEST_DIR/jj-config.toml"
    export JJ_CONFIG="$TEST_DIR/jj-config.toml" JJ_USER=test JJ_EMAIL=test@example.com

    WIPJJ_WS="$TEST_DIR/wip-jj-ws"
    WIPJJ="$WIPJJ_WS/repo"
    mkgit_origin "$TEST_DIR/wip-jj-seed" "$TEST_DIR/wip-jj.git"
    mkdir -p "$WIPJJ_WS"
    jj git clone "$TEST_DIR/wip-jj.git" "$WIPJJ" >/dev/null 2>&1
    {
        jj -R "$WIPJJ" new main@origin -m "pushed one"
        print p1 > "$WIPJJ/p1"
        jj -R "$WIPJJ" bookmark create feat-pushed -r @
        jj -R "$WIPJJ" bookmark track feat-pushed --remote origin
        jj -R "$WIPJJ" git push -b feat-pushed
        jj -R "$WIPJJ" new -m "pushed two"
        print p2 > "$WIPJJ/p2"
        jj -R "$WIPJJ" bookmark set feat-pushed -r @
        jj -R "$WIPJJ" new -m "above pushed"
        print p3 > "$WIPJJ/p3"
        jj -R "$WIPJJ" new main@origin -m "base one"
        print b1 > "$WIPJJ/b1"
        jj -R "$WIPJJ" bookmark create feat-base -r @
        jj -R "$WIPJJ" new -m "top one"
        print t1 > "$WIPJJ/t1"
        jj -R "$WIPJJ" bookmark create feat-top -r @
        jj -R "$WIPJJ" new main@origin -m "loose one"
        print l1 > "$WIPJJ/l1"
        jj -R "$WIPJJ" new
        jj -R "$WIPJJ" workspace add --name second "$WIPJJ_WS/second"
    } >/dev/null 2>&1

    out=$(strip_ansi "$(cd "$WIPJJ" && jjw wip)")
    assert_has   "wip jj: open PR labels and push state" "feat-pushed  #7  approved  ✓ ci  ↑1" "$out"
    assert_has   "wip jj: unbookmarked commit above bookmark" "+ " "$out"
    assert_has   "wip jj: above commit listed" "above pushed" "$out"
    assert_has   "wip jj: merged PR and not pushed" "feat-base  #3 merged  ↑ not pushed" "$out"
    assert_has   "wip jj: stacked bookmark parent" "feat-top  ↑ not pushed  on feat-base" "$out"
    assert_lacks "wip jj: stacked commits not repeated" "base one" "$(wip_block feat-top "$out")"
    assert_has   "wip jj: loose commit" "loose one" "${out#*Without bookmark}"
    assert_lacks "wip jj: empty undescribed commit hidden" "(no description)" "$out"
    assert_has   "wip jj: No PR before Open PRs" "No PR" "${out%%Open PRs*}"
    assert_has   "wip jj: Open PRs before Without bookmark" "Open PRs" "${out%%Without bookmark*}"

    out=$(strip_ansi "$(cd "$WIPJJ" && jjw wip --no-gh)")
    assert_lacks "wip jj --no-gh: no PR data" "#7" "$out"
    assert_lacks "wip jj --no-gh: no Open PRs section" "Open PRs" "$out"

    out=$(cd "$WIPJJ_WS" && _jjw_wip_dedupe repo second)
    assert_eq "wip: workspaces of one repo shown once" repo "$out"
else
    print "SKIP: jj not installed — wip jj tests skipped"
fi

# ============================================================================

print ""
if (( FAILS )); then
    print "FAILED: $FAILS test(s) failed."
    exit 1
else
    print "All tests passed!"
fi
