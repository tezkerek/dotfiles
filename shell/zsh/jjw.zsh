# jjw — workspace-wide VCS sweeps over sibling repos.
#
#   jjw [st|pull] [dir ...]
#
# With no subcommand, defaults to `st` (read-only status, sequential, no network).
# `pull` updates each repo in parallel (see the design note above `_jjw_pull`).
# Optional dir args are only accepted when a subcommand is given explicitly;
# otherwise every immediate child directory of PWD that is a repo is used.
# Non-repo children are silently skipped.
#
# See .agents/plans/jjw.md for the full design.

# --- primitives -------------------------------------------------------------

# Trunk precedence order.
typeset -ga _JJW_TRUNKS=(main master develop)

# Classify a ref name: prints "trunk" if it's a trunk-like name (a trunk or a
# release/* branch), else "feature". An empty name is treated as trunk-like
# (nothing to switch away from).
function _jjw_classify {
    local name=$1
    [[ -z $name ]] && { print trunk; return }
    [[ $name == release/* ]] && { print trunk; return }
    local t
    for t in $_JJW_TRUNKS; do
        [[ $name == $t ]] && { print trunk; return }
    done
    print feature
}

# Repo type of a directory: prints "jj", "git" or nothing (not a repo).
# .jj takes precedence (may be colocated).
function _jjw_repo_type {
    local dir=$1
    [[ -d $dir/.jj ]] && { print jj; return }
    [[ -d $dir/.git ]] && { print git; return }
    return 1
}

# --- git helpers ------------------------------------------------------------

# Current git branch of a repo dir (empty if detached).
function _jjw_git_ref {
    git -C "$1" branch --show-current 2>/dev/null
}

# Trunk branch for a git repo dir. If the current branch's upstream tracks a
# trunk, use that trunk; otherwise the first existing local branch in precedence
# order. Prints nothing if none found.
function _jjw_git_trunk {
    local dir=$1
    local upstream t
    # Upstream of the current branch, e.g. "origin/main" -> "main".
    upstream=$(git -C "$dir" rev-parse --abbrev-ref '@{upstream}' 2>/dev/null)
    upstream=${upstream#*/}
    if [[ -n $upstream ]]; then
        for t in $_JJW_TRUNKS; do
            [[ $upstream == $t ]] && { print $t; return }
        done
    fi
    for t in $_JJW_TRUNKS; do
        if git -C "$dir" show-ref --verify --quiet "refs/heads/$t"; then
            print $t
            return
        fi
    done
}

# --- jj helpers -------------------------------------------------------------

# Closest bookmark of the working copy (current jj "ref"); empty if none.
function _jjw_jj_ref {
    jj -R "$1" log --no-graph --ignore-working-copy -n1 -r 'closest_bookmark(@)' \
        -T 'bookmarks.map(|b| b.name()).join(" ")' --color=never 2>/dev/null
}

# Whether a jj remote bookmark <name>@origin exists in repo dir.
function _jjw_jj_remote_exists {
    jj -R "$1" log --no-graph --ignore-working-copy -n1 -r "$2@origin" \
        -T 'commit_id.short()' --color=never >/dev/null 2>&1
}

# Whether a jj local bookmark <name> exists in repo dir.
function _jjw_jj_bookmark_exists {
    jj -R "$1" log --no-graph --ignore-working-copy -n1 -r "$2" \
        -T 'commit_id.short()' --color=never >/dev/null 2>&1
}

# Trunk bookmark for a jj repo dir: first existing <name>@origin in precedence
# order. Prints nothing if none found.
function _jjw_jj_trunk {
    local dir=$1 t
    for t in $_JJW_TRUNKS; do
        if _jjw_jj_remote_exists "$dir" "$t"; then
            print $t
            return
        fi
    done
}

# --- repo discovery ---------------------------------------------------------

# Emit the repo directories to act on. With explicit dirs, use them (skipping
# non-repos); otherwise every immediate child dir of PWD that is a repo.
function _jjw_discover {
    local -a candidates
    if (( $# )); then
        candidates=("$@")
    else
        candidates=(*(/N))
    fi
    local d
    for d in $candidates; do
        _jjw_repo_type "$d" >/dev/null && print -r -- "$d"
    done
}

# --- st ---------------------------------------------------------------------

# Print status for a single repo dir (read-only, no network).
function _jjw_st_repo {
    local dir=$1
    local name=${dir:t}
    local type
    type=$(_jjw_repo_type "$dir") || return

    local ref trunk cls
    if [[ $type == jj ]]; then
        ref=$(_jjw_jj_ref "$dir")
        trunk=$(_jjw_jj_trunk "$dir")
    else
        ref=$(_jjw_git_ref "$dir")
        trunk=$(_jjw_git_trunk "$dir")
    fi

    cls=$(_jjw_classify "$ref")

    # Header: bold-cyan name; ref green on trunk, yellow on a feature. Raw ANSI
    # (not print -P) so a '%' in a repo/branch name cannot corrupt the output.
    local bold=$'\e[1m' reset=$'\e[0m' cyan=$'\e[36m' green=$'\e[32m' yellow=$'\e[33m'
    local rc
    [[ $cls == trunk ]] && rc=$green || rc=$yellow
    print -r -- "${bold}${cyan}${name}${reset}  [${rc}${ref:-?}${reset}]"

    # On a trunk (or unknown), nothing more to show.
    [[ $cls == trunk ]] && return
    [[ -z $trunk ]] && return

    if [[ $type == jj ]]; then
        # The real graph, colored: the stack (trunk..@, incl. the empty @) plus
        # the trunk tip as a base anchor. Indented; ANSI passes through untouched.
        # Anchor on jj's built-in trunk() alias, which resolves to the remote
        # trunk head (e.g. main@origin) rather than a possibly-stale local
        # bookmark, so the graph stops where plain `jj log` stops. The [[ -z
        # $trunk ]] guard above still short-circuits the no-trunk case, sparing
        # us trunk()'s root() fallback (which would dump the entire history).
        jj -R "$dir" log --ignore-working-copy --color=always -r "trunk()..@ | trunk()" \
            2>/dev/null | while IFS= read -r line; do
                print -r -- "    $line"
            done
    else
        git -C "$dir" log --color=always --format='%C(auto)%h%Creset %s' "${trunk}..HEAD" 2>/dev/null \
            | while IFS= read -r line; do
                print -r -- "    $line"
            done
    fi
}

function _jjw_st {
    local -a repos
    repos=("$@")
    local dir
    for dir in $repos; do
        _jjw_st_repo "$dir"
    done
}

# --- pull -------------------------------------------------------------------

# Update a single repo. Emits EXACTLY ONE NUL-terminated record to stdout:
#   "<dir>\t<status>\t<name>\t<message>\0"
# where status is one of: changed / noop / failed (resolved to a glyph later).
# The leading <dir> lets the collector key results by directory regardless of
# completion order. The NUL terminator delimits records from parallel jobs whose
# writes to the shared pipe may interleave at line granularity but not mid-record
# (each record is a single small write). VCS progress chatter is silenced at the
# source (jj --quiet / git -q) and each command's stdout is sent to /dev/null so
# it cannot corrupt the record stream; genuine errors still reach the terminal on
# stderr, complementing the ✗ record.
function _jjw_pull_repo {
    local dir=$1
    local name=${dir:t}
    local type line
    type=$(_jjw_repo_type "$dir") || {
        print -rn -- "${dir}"$'\tnoop\t'"${name}"$'\tnot a repo\0'
        return
    }

    if [[ $type == jj ]]; then
        line=$(_jjw_pull_repo_jj "$dir" "$name")
    else
        line=$(_jjw_pull_repo_git "$dir" "$name")
    fi
    print -rn -- "${dir}"$'\t'"${line}"$'\0'
}

function _jjw_pull_repo_jj {
    local dir=$1 name=$2
    local cur trunk cls
    cur=$(_jjw_jj_ref "$dir")
    trunk=$(_jjw_jj_trunk "$dir")
    cls=$(_jjw_classify "$cur")

    if ! jj -R "$dir" git fetch --quiet >/dev/null; then
        print -r -- $'failed\t'"${name}"$'\tjj git fetch failed'
        return
    fi

    if [[ -z $trunk ]]; then
        print -r -- $'noop\t'"${name}"$'\tno trunk on origin; fetched only'
        return
    fi

    # Advance to trunk iff we were on a trunk, or the feature bookmark no longer
    # exists after fetch (merged upstream => tracking bookmark dropped).
    local advance=0
    if [[ $cls == trunk ]]; then
        advance=1
    elif ! _jjw_jj_bookmark_exists "$dir" "$cur"; then
        advance=1
    fi

    if (( advance )); then
        if jj -R "$dir" new "${trunk}@origin" --quiet >/dev/null; then
            print -r -- $'changed\t'"${name}"$'\tnew '"${trunk}@origin"
        else
            print -r -- $'failed\t'"${name}"$'\tjj new '"${trunk}@origin"$' failed'
        fi
    else
        print -r -- $'noop\t'"${name}"$'\tfetched; left on '"${cur}"
    fi
}

function _jjw_pull_repo_git {
    local dir=$1 name=$2
    local ref trunk cls
    ref=$(_jjw_git_ref "$dir")
    trunk=$(_jjw_git_trunk "$dir")
    cls=$(_jjw_classify "$ref")

    if [[ -z $trunk ]]; then
        print -r -- $'noop\t'"${name}"$'\tno trunk branch found'
        return
    fi

    if [[ $cls == trunk ]]; then
        if git -C "$dir" pull --ff-only -q >/dev/null; then
            print -r -- $'changed\t'"${name}"$'\tpulled '"${ref}"
        else
            print -r -- $'failed\t'"${name}"$'\tgit pull --ff-only failed'
        fi
        return
    fi

    # On a feature branch.
    if [[ -n $(git -C "$dir" status --porcelain 2>/dev/null) ]]; then
        # Dirty: fast-forward local trunk ref only, stay put.
        if git -C "$dir" fetch origin "${trunk}:${trunk}" -q >/dev/null; then
            print -r -- $'noop\t'"${name}"$'\tdirty; fetched trunk only'
        else
            print -r -- $'failed\t'"${name}"$'\tgit fetch origin '"${trunk}"$' failed'
        fi
        return
    fi

    # Clean feature: switch to trunk and pull.
    if git -C "$dir" switch "$trunk" --quiet >/dev/null && git -C "$dir" pull --ff-only -q >/dev/null; then
        print -r -- $'changed\t'"${name}"$'\tswitched to '"${trunk}"$' + pulled'
    else
        print -r -- $'failed\t'"${name}"$'\tswitch/pull '"${trunk}"$' failed'
    fi
}

# Map an internal status word to a display glyph.
function _jjw_glyph {
    case $1 in
        changed) print -n $'✓' ;;   # ✓
        failed)  print -n $'✗' ;;    # ✗
        *)       print -n $'·' ;;    # ·
    esac
}

# Parallel pull over repos.
#
# Design note (deviation from the plan, see the report): the plan prescribed
# mafredri/zsh-async. That library delivers job results through a ZLE fd-watcher
# that only runs between interactive prompts; a synchronous blocking drain loop
# (as the plan describes) therefore deadlocks — ZLE never gets to run while the
# `jjw` function blocks the prompt, and non-interactively results are not
# delivered at all. Verified empirically (incl. a real PTY via `expect`).
#
# Instead we fan out one background subshell per repo inside a pipeline. Each job
# writes a single NUL-terminated record to the shared pipe; the reader on the
# right side of the pipe collects them into an assoc array keyed by dir, then
# prints in stable directory order. This is genuinely parallel, needs no temp
# files, no external dependency, and works both interactively and in scripts (so
# it is unit-testable). A single failing repo prints its ✗ record and never
# aborts the sweep. The reader runs in a subshell, so it does the final printing.
function _jjw_pull {
    local -a repos
    repos=("$@")
    (( ${#repos} )) || return

    {
        local dir
        for dir in $repos; do
            _jjw_pull_repo "$dir" &
        done
        wait
    } | {
        local -A results
        local rec key
        while IFS= read -r -d '' rec; do
            key=${rec%%$'\t'*}
            results[$key]=${rec#*$'\t'}
        done

        # Print in stable directory order.
        local status_word rest glyph line
        for dir in $repos; do
            line=$results[$dir]
            [[ -z $line ]] && continue
            status_word=${line%%$'\t'*}
            rest=${line#*$'\t'}
            glyph=$(_jjw_glyph "$status_word")
            print -r -- "${glyph} ${rest//$'\t'/  }"
        done
    }
}

# --- entry point ------------------------------------------------------------

function jjw {
    emulate -L zsh
    setopt local_options extended_glob null_glob

    local sub=st
    local -a dirs
    if (( $# )); then
        case $1 in
            st|pull)
                sub=$1
                shift
                dirs=("$@")
                ;;
            *)
                print -u2 "jjw: unknown subcommand '$1' (expected st|pull)"
                return 2
                ;;
        esac
    fi

    local -a repos
    repos=("${(@f)$(_jjw_discover "${dirs[@]}")}")
    # Filter out the empty element that a no-output subshell can leave.
    repos=("${(@)repos:#}")

    if (( ! ${#repos} )); then
        print -u2 "jjw: no repos found"
        return 1
    fi

    case $sub in
        st)   _jjw_st "${repos[@]}" ;;
        pull) _jjw_pull "${repos[@]}" ;;
    esac
}
