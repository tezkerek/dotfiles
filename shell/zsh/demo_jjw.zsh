#!/usr/bin/env zsh
# demo_jjw.zsh — build a throwaway multi-repo workspace and run jjw against it,
# so you can eyeball the real (colored) output without needing your own repos.
#
#   zsh demo_jjw.zsh        # build fixtures, then run: st -> pull -> st
#   zsh demo_jjw.zsh -i     # ...and afterwards drop into an interactive shell
#                           #    inside the workspace, with jjw already sourced
#
# Nothing is auto-deleted: the workspace path is printed at the end so you can
# cd back in and keep poking. Delete it yourself when done (rm -rf <path>).

emulate -L zsh
setopt local_options

local SRC=${0:A:h}/jjw.zsh
source "$SRC"

local interactive=0
[[ $1 == -i || $1 == --interactive ]] && interactive=1

local WS=$(mktemp -d /tmp/jjw-demo.XXXXXX)

# --- fixture helpers (mirrors test_jjw.zsh) ---------------------------------

function _demo_git {           # _demo_git <dir> [branch]
    local dir=$1 branch=${2:-main}
    mkdir -p "$dir"
    git -C "$dir" init -q -b "$branch"
    git -C "$dir" config user.email demo@example.com
    git -C "$dir" config user.name demo
    print init > "$dir/README"
    git -C "$dir" add -A
    git -C "$dir" commit -qm "initial"
}

function _demo_git_origin {    # _demo_git_origin <workdir> <originbare>
    local work=$1 origin=$2
    git init -q --bare "$origin"
    _demo_git "$work" main
    git -C "$work" remote add origin "$origin"
    git -C "$work" push -q -u origin main
}

# Advance origin/main by one commit, via a scratch clone (simulates teammates).
function _demo_advance_origin {  # _demo_advance_origin <originbare> <msg>
    local origin=$1 msg=$2
    local clone=$WS/.scratch-${origin:t}
    git clone -q "$origin" "$clone"
    git -C "$clone" config user.email demo@example.com
    git -C "$clone" config user.name demo
    print more > "$clone/upstream-$RANDOM"
    git -C "$clone" add -A
    git -C "$clone" commit -qm "$msg"
    git -C "$clone" push -q origin main
    rm -rf "$clone"
}

# --- build the workspace ----------------------------------------------------

print "Building mock workspace at: $WS"

# git: on a trunk that is behind origin  -> pull should fast-forward.
_demo_git_origin "$WS/git-on-trunk" "$WS/.origins/git-on-trunk.git"
_demo_advance_origin "$WS/.origins/git-on-trunk.git" "upstream work"

# git: on a trunk that is already up to date -> pull is a no-op-ish "changed".
_demo_git_origin "$WS/git-uptodate" "$WS/.origins/git-uptodate.git"

# git: clean feature branch -> pull should switch to main + pull.
_demo_git_origin "$WS/git-clean-feat" "$WS/.origins/git-clean-feat.git"
git -C "$WS/git-clean-feat" switch -qc my-feature
print a > "$WS/git-clean-feat/a"
git -C "$WS/git-clean-feat" add -A
git -C "$WS/git-clean-feat" commit -qm "feature work"

# git: dirty feature branch -> pull should fetch trunk only, stay put.
_demo_git_origin "$WS/git-dirty-feat" "$WS/.origins/git-dirty-feat.git"
git -C "$WS/git-dirty-feat" switch -qc my-feature
print wip > "$WS/git-dirty-feat/uncommitted"    # untracked => dirty

# plain dir (not a repo) -> should be silently skipped by discovery.
mkdir -p "$WS/not-a-repo"

# jj: a feature stack with main@origin, if jj is available.
if command -v jj >/dev/null 2>&1; then
    local jj_origin=$WS/.origins/jj-origin
    mkdir -p "$jj_origin"
    ( cd "$jj_origin"
      jj git init . >/dev/null 2>&1
      print init > f
      jj describe -m "initial" >/dev/null 2>&1
      jj bookmark create main -r @ >/dev/null 2>&1
      jj new main >/dev/null 2>&1
    )
    jj git clone "$jj_origin" "$WS/jj-feat" >/dev/null 2>&1
    ( cd "$WS/jj-feat"
      jj new main -m "feat 1" >/dev/null 2>&1
      print x > x
      jj bookmark create my-feature -r @ >/dev/null 2>&1
      jj new >/dev/null 2>&1        # empty @ on top of the feature
    )
else
    print "  (jj not installed — skipping jj fixture)"
fi

# --- run jjw live -----------------------------------------------------------

local rule=$'\e[2m'"$(printf '%.0s─' {1..70})"$'\e[0m'
print "\n$rule\n\e[1mjjw st\e[0m  (before)\n$rule"
( cd "$WS" && jjw st )

print "\n$rule\n\e[1mjjw pull\e[0m\n$rule"
( cd "$WS" && jjw pull )

print "\n$rule\n\e[1mjjw st\e[0m  (after)\n$rule"
( cd "$WS" && jjw st )

print "\n$rule"
print "Workspace kept at: \e[36m$WS\e[0m"
print "Re-run manually:   \e[2mcd $WS && source $SRC && jjw st\e[0m"
print "Clean up with:     \e[2mrm -rf $WS\e[0m"

# --- optional interactive sandbox -------------------------------------------

if (( interactive )); then
    local zd=$(mktemp -d /tmp/jjw-demo-zdot.XXXXXX)
    cat > "$zd/.zshrc" <<RC
source "$SRC"
cd "$WS"
PROMPT='%F{magenta}jjw-demo%f %~ %# '
print ""
print "jjw sandbox — try:  jjw st  |  jjw pull  |  jjw pull git-clean-feat"
print "exit this shell to return."
RC
    print "\nDropping into interactive sandbox (exit to leave)…\n"
    ZDOTDIR="$zd" exec zsh -i
fi
