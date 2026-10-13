# jjw wip — summary of local work in progress, per repo.
#
#   jjw wip [--no-gh] [dir ...]
#
# Inside a repo, shows only that repo; otherwise every child repo of PWD.
# Workspaces of the same repo are shown once. Per repo, in order:
#   No PR             bookmarks without an open PR (closed/merged PRs are noted)
#   Open PRs          bookmarks with an open PR, with draft/review/CI state
#   Without bookmark  (jj only) mutable commits of the user that no bookmark
#                     contains, grouped by fork point
# PR data comes from `gh pr list`; --no-gh skips it.

typeset -gA _JJW_WIP_C=(
    reset $'\e[0m' bold $'\e[1m' dim $'\e[2m'
    red $'\e[31m' green $'\e[32m' yellow $'\e[33m' blue $'\e[34m' magenta $'\e[35m' cyan $'\e[36m'
)

typeset -g _JJW_WIP_EMPTY='(empty() & description(exact:""))'
typeset -g _JJW_WIP_MARKS='(bookmarks() & mine() & mutable())'
typeset -g _JJW_WIP_TPL='separate(" ",
    change_id.shortest(8),
    if(description, description.first_line(), label("description placeholder", "(no description)")),
    if(empty, label("empty", "(empty)")),
    if(conflict, label("conflict", "(conflict)")),
    working_copies,
    label("timestamp", committer.timestamp().ago())
) ++ "\n"'

# --- helpers ----------------------------------------------------------------

# Indent stdin by $1 spaces and shorten relative ages ("2 weeks ago" -> "2w").
function _jjw_wip_fmt {
    local pad=${(l:$1:: :)}
    sed -E \
        -e 's/([0-9]+) years?(, [0-9]+ months?)? ago/\1y/g' \
        -e 's/([0-9]+) months? ago/\1mo/g' \
        -e 's/([0-9]+) weeks? ago/\1w/g' \
        -e 's/([0-9]+) days? ago/\1d/g' \
        -e 's/([0-9]+) hours? ago/\1h/g' \
        -e 's/([0-9]+) minutes? ago/\1m/g' \
        -e 's/([0-9]+) seconds? ago/\1s/g' \
        -e "s/^/$pad/"
}

# Quote a name as a jj revset string literal.
function _jjw_wip_quote {
    local s=${1//\\/\\\\}
    print -r -- "\"${s//\"/\\\"}\""
}

# Absolute path of the repo store, to detect workspaces of the same repo.
function _jjw_wip_store {
    local dir=$1 p
    if [[ -d $dir/.jj ]]; then
        p=$dir/.jj/repo
        if [[ -f $p ]]; then
            p=$(<"$p")
            [[ $p == /* ]] || p=$dir/.jj/$p
        fi
        print -r -- ${p:A}
    else
        git -C "$dir" rev-parse --path-format=absolute --git-common-dir 2>/dev/null
    fi
}

# Drop directories whose repo store was already seen.
function _jjw_wip_dedupe {
    local -A seen
    local dir store
    for dir in "$@"; do
        store=$(_jjw_wip_store "$dir")
        [[ -n $store && -n ${seen[$store]} ]] && continue
        seen[$store]=1
        print -r -- "$dir"
    done
}

# GitHub "owner/repo" of the origin remote; fails if origin is not on GitHub.
function _jjw_wip_slug {
    local dir=$1 type=$2 url
    if [[ $type == jj ]]; then
        url=$(jj -R "$dir" git remote list --ignore-working-copy --color=never 2>/dev/null \
            | awk '$1 == "origin" { print $2 }')
    else
        url=$(git -C "$dir" remote get-url origin 2>/dev/null)
    fi
    [[ $url == *github.com(:|/)* ]] || return 1
    url=${url#*github.com(:|/)}
    print -r -- ${url%.git}
}

# PRs of the user in GitHub repo $1, one per line, newest first:
#   <head>\t<number>\t<state>\t<draft>\t<review decision>\t<ci: pass|fail|pending|>
function _jjw_wip_prs {
    local slug=$1
    local ci='[.statusCheckRollup[]? | (.conclusion // .state // "") | ascii_upcase] as $s
        | if ($s | length) == 0 then ""
          elif any($s[]; . == "FAILURE" or . == "ERROR" or . == "TIMED_OUT" or . == "CANCELLED"
                         or . == "ACTION_REQUIRED" or . == "STARTUP_FAILURE") then "fail"
          elif any($s[]; . == "" or . == "PENDING" or . == "QUEUED" or . == "IN_PROGRESS"
                         or . == "EXPECTED" or . == "WAITING" or . == "REQUESTED") then "pending"
          else "pass" end'
    local open_out pid
    open_out=$(mktemp)
    gh pr list -R "$slug" --author @me --state open --limit 100 \
        --json headRefName,number,isDraft,reviewDecision,statusCheckRollup \
        --jq ".[] | [.headRefName, .number, \"OPEN\", .isDraft, .reviewDecision, ($ci)] | @tsv" \
        >"$open_out" &
    pid=$!
    local rest rc_rest rc_open
    rest=$(gh pr list -R "$slug" --author @me --state all --limit 100 --json headRefName,number,state \
        --jq '.[] | select(.state != "OPEN") | [.headRefName, .number, .state, false, "", ""] | @tsv')
    rc_rest=$?
    wait $pid
    rc_open=$?
    cat "$open_out"
    rm -f "$open_out"
    [[ -n $rest ]] && print -r -- "$rest"
    (( rc_open == 0 && rc_rest == 0 ))
}

# Annotation for a bookmark from its PR record (see _jjw_wip_prs).
function _jjw_wip_pr_label {
    local -a f
    f=("${(@ps:\t:)1}")
    local num=$f[2] state=$f[3] draft=$f[4] review=$f[5] ci=$f[6]
    local -a out
    if [[ $state != OPEN ]]; then
        print -r -- "${_JJW_WIP_C[dim]}#${num} ${(L)state}${_JJW_WIP_C[reset]}"
        return
    fi
    out+=("${_JJW_WIP_C[blue]}#${num}${_JJW_WIP_C[reset]}")
    [[ $draft == true ]] && out+=("${_JJW_WIP_C[dim]}draft${_JJW_WIP_C[reset]}")
    case $review in
        APPROVED)          out+=("${_JJW_WIP_C[green]}approved${_JJW_WIP_C[reset]}") ;;
        CHANGES_REQUESTED) out+=("${_JJW_WIP_C[red]}changes requested${_JJW_WIP_C[reset]}") ;;
    esac
    case $ci in
        pass)    out+=("${_JJW_WIP_C[green]}✓ ci${_JJW_WIP_C[reset]}") ;;
        fail)    out+=("${_JJW_WIP_C[red]}✗ ci${_JJW_WIP_C[reset]}") ;;
        pending) out+=("${_JJW_WIP_C[yellow]}● ci${_JJW_WIP_C[reset]}") ;;
    esac
    print -r -- "${(j:  :)out}"
}

# Push state label from counts of commits only on local / only on origin.
function _jjw_wip_push_label {
    local ahead=$1 behind=$2
    local -a out
    (( ahead ))  && out+=("${_JJW_WIP_C[cyan]}↑${ahead}${_JJW_WIP_C[reset]}")
    (( behind )) && out+=("${_JJW_WIP_C[magenta]}↓${behind}${_JJW_WIP_C[reset]}")
    print -r -- "${(j: :)out}"
}

typeset -g _JJW_WIP_UNPUSHED="${_JJW_WIP_C[cyan]}↑ not pushed${_JJW_WIP_C[reset]}"

# --- jj ---------------------------------------------------------------------

# Bookmarks of the user, one per line: <name>\t<push/conflict label>.
function _jjw_wip_jj_bookmarks {
    local dir=$1
    local -a names
    local -A conflict on_origin ahead behind
    local name remote conf a b
    while IFS=$'\t' read -r name remote conf a b; do
        if [[ $remote == . ]]; then
            names+=("$name")
            conflict[$name]=$conf
        elif [[ $remote == origin ]]; then
            on_origin[$name]=1
            ahead[$name]=$b
            behind[$name]=$a
        fi
    done < <(jj -R "$dir" bookmark list -a --ignore-working-copy --color=never -r 'mine() & mutable()' \
        -T 'name ++ "\t" ++ if(remote, remote, ".") ++ "\t" ++ if(conflict, "1", "0") ++ "\t"
            ++ if(tracked, tracking_ahead_count.exact() ++ "\t" ++ tracking_behind_count.exact(), "0\t0") ++ "\n"' \
        2>/dev/null)

    local label
    for name in $names; do
        if (( conflict[$name] )); then
            label="${_JJW_WIP_C[red]}✗ conflict${_JJW_WIP_C[reset]}"
        elif [[ -z $on_origin[$name] ]]; then
            label=$_JJW_WIP_UNPUSHED
        else
            label=$(_jjw_wip_push_label "${ahead[$name]:-0}" "${behind[$name]:-0}")
        fi
        print -r -- "${name}"$'\t'"${label}"
    done
}

function _jjw_wip_jj_log {
    local dir=$1 revset=$2
    shift 2
    jj -R "$dir" log --ignore-working-copy --color=always -r "$revset" -T "$_JJW_WIP_TPL" "$@" 2>/dev/null
}

# A bookmark header line and its commits; commits above it are marked with "+".
function _jjw_wip_jj_bookmark_block {
    local dir=$1 name=$2 labels=$3
    local b="bookmarks(exact:$(_jjw_wip_quote "$name"))"
    local below="((::$b & $_JJW_WIP_MARKS) ~ $b)"
    local above="(($b+:: ~ ::$_JJW_WIP_MARKS ~ ($b+:: & $_JJW_WIP_MARKS)::) ~ $_JJW_WIP_EMPTY)"

    local parent
    parent=$(jj -R "$dir" log --ignore-working-copy --no-graph --color=never -r "heads($below)" \
        -T 'local_bookmarks.map(|b| b.name()).join(", ") ++ "\n"' 2>/dev/null)
    parent=${(j:, :)${(f)parent}}

    local line="${_JJW_WIP_C[yellow]}${name}${_JJW_WIP_C[reset]}"
    [[ -n $labels ]] && line+="  $labels"
    [[ -n $parent ]] && line+="  ${_JJW_WIP_C[dim]}on ${parent}${_JJW_WIP_C[reset]}"
    print -r -- "    $line"

    _jjw_wip_jj_log "$dir" "$above" --no-graph | sed "s/^/${_JJW_WIP_C[dim]}+${_JJW_WIP_C[reset]} /" | _jjw_wip_fmt 6
    _jjw_wip_jj_log "$dir" "(::$b & mutable()) ~ ::$below" --no-graph | _jjw_wip_fmt 8
}

# Mutable commits of the user outside bookmarks, grouped by fork point.
function _jjw_wip_jj_loose {
    local dir=$1
    local x="((mine() & mutable()) ~ ::$_JJW_WIP_MARKS ~ $_JJW_WIP_MARKS:: ~ $_JJW_WIP_EMPTY)"
    local -a forks
    forks=(${(f)"$(jj -R "$dir" log --ignore-working-copy --no-graph --color=never \
        -r "roots($x)-" -T 'commit_id ++ "\n"' 2>/dev/null)"})
    local f
    for f in $forks; do
        jj -R "$dir" log --ignore-working-copy --no-graph --color=always -r "$f" \
            -T '"from " ++ separate(" ", commit_id.shortest(8), bookmarks,
                if(!immutable, description.first_line()), label("timestamp", committer.timestamp().ago())) ++ "\n"' \
            2>/dev/null | _jjw_wip_fmt 4
        _jjw_wip_jj_log "$dir" "(roots($x) & $f+):: & $x" \
            | sed -E $'/^(\e\\[[0-9;]*m|[│~ ])+$/d' | _jjw_wip_fmt 6
    done
}

# --- git --------------------------------------------------------------------

# Base ref of a git repo: origin/<trunk> if present, else <trunk>.
function _jjw_wip_git_base {
    local dir=$1 trunk
    trunk=$(_jjw_git_trunk "$dir")
    [[ -z $trunk ]] && return 1
    if git -C "$dir" rev-parse --verify -q "refs/remotes/origin/$trunk" >/dev/null; then
        print -r -- "origin/$trunk"
    else
        print -r -- "$trunk"
    fi
}

# Unmerged local feature branches, one per line: <name>\t<push label>.
function _jjw_wip_git_branches {
    local dir=$1 base=$2 name counts
    for name in ${(f)"$(git -C "$dir" for-each-ref --format='%(refname:short)' refs/heads)"}; do
        [[ $(_jjw_classify "$name") == trunk ]] && continue
        git -C "$dir" merge-base --is-ancestor "$name" "$base" 2>/dev/null && continue
        if counts=$(git -C "$dir" rev-list --left-right --count "$name...origin/$name" 2>/dev/null); then
            print -r -- "${name}"$'\t'"$(_jjw_wip_push_label ${=counts})"
        else
            print -r -- "${name}"$'\t'"${_JJW_WIP_UNPUSHED}"
        fi
    done
}

function _jjw_wip_git_branch_block {
    local dir=$1 base=$2 name=$3 labels=$4
    shift 4
    local -a others=("$@") excl
    local o parent best=-1 n
    for o in $others; do
        [[ $o == $name ]] && continue
        git -C "$dir" merge-base --is-ancestor "$o" "$name" || continue
        [[ $(git -C "$dir" rev-parse "$o") == $(git -C "$dir" rev-parse "$name") ]] && continue
        excl+=("$o")
        n=$(git -C "$dir" rev-list --count "$o..$name")
        if (( best < 0 || n < best )); then
            best=$n
            parent=$o
        fi
    done

    local line="${_JJW_WIP_C[yellow]}${name}${_JJW_WIP_C[reset]}"
    [[ $(git -C "$dir" branch --show-current) == $name ]] && line+=" ${_JJW_WIP_C[green]}(HEAD)${_JJW_WIP_C[reset]}"
    [[ -n $labels ]] && line+="  $labels"
    [[ -n $parent ]] && line+="  ${_JJW_WIP_C[dim]}on ${parent}${_JJW_WIP_C[reset]}"
    print -r -- "    $line"

    git -C "$dir" log --color=always --format='%C(yellow)%h%C(reset) %s %C(dim)%cr%C(reset)' \
        "$name" --not "$base" $excl 2>/dev/null | _jjw_wip_fmt 8
}

# --- per repo ---------------------------------------------------------------

# Print the wip summary of one repo; prints nothing if there is no wip.
function _jjw_wip_repo {
    local dir=$1
    local type slug base
    type=$(_jjw_repo_type "$dir") || return
    if [[ $type == git ]]; then
        base=$(_jjw_wip_git_base "$dir") || return
    fi

    local prs_file gh_pid
    if (( _jjw_wip_gh )) && slug=$(_jjw_wip_slug "$dir" "$type"); then
        prs_file=$(mktemp)
        _jjw_wip_prs "$slug" >"$prs_file" 2>/dev/null &
        gh_pid=$!
    fi

    local -a marks
    if [[ $type == jj ]]; then
        marks=(${(f)"$(_jjw_wip_jj_bookmarks "$dir")"})
    else
        marks=(${(f)"$(_jjw_wip_git_branches "$dir" "$base")"})
    fi

    local -A pr
    local gh_failed=0 rec head
    if [[ -n $gh_pid ]]; then
        wait $gh_pid || gh_failed=1
        while IFS= read -r rec; do
            head=${rec%%$'\t'*}
            [[ -n ${pr[$head]} && ${pr[$head]} == *$'\t'OPEN$'\t'* ]] && continue
            [[ -n ${pr[$head]} && $rec != *$'\t'OPEN$'\t'* ]] && continue
            pr[$head]=$rec
        done <"$prs_file"
        rm -f "$prs_file"
    fi

    local -a branch_names=(${marks%%$'\t'*})
    local no_pr="" open="" m name labels block
    for m in $marks; do
        name=${m%%$'\t'*}
        labels=${m#*$'\t'}
        [[ -n ${pr[$name]} ]] && labels="$(_jjw_wip_pr_label "${pr[$name]}")${labels:+  $labels}"
        if [[ $type == jj ]]; then
            block=$(_jjw_wip_jj_bookmark_block "$dir" "$name" "$labels")
        else
            block=$(_jjw_wip_git_branch_block "$dir" "$base" "$name" "$labels" $branch_names)
        fi
        if [[ ${pr[$name]} == *$'\t'OPEN$'\t'* ]]; then
            open+="${block}"$'\n'
        else
            no_pr+="${block}"$'\n'
        fi
    done

    local loose=""
    [[ $type == jj ]] && loose=$(_jjw_wip_jj_loose "$dir")

    [[ -z $no_pr$open$loose ]] && return

    local header="${_JJW_WIP_C[bold]}${_JJW_WIP_C[cyan]}${dir:A:t}${_JJW_WIP_C[reset]}"
    (( gh_failed )) && header+="  ${_JJW_WIP_C[red]}(gh failed)${_JJW_WIP_C[reset]}"
    print -r -- "$header"
    local -a sections
    [[ -n $no_pr ]] && sections+=("  ${_JJW_WIP_C[bold]}No PR${_JJW_WIP_C[reset]}"$'\n'"${no_pr%$'\n'}")
    [[ -n $open ]]  && sections+=("  ${_JJW_WIP_C[bold]}Open PRs${_JJW_WIP_C[reset]}"$'\n'"${open%$'\n'}")
    [[ -n $loose ]] && sections+=("  ${_JJW_WIP_C[bold]}Without bookmark${_JJW_WIP_C[reset]}"$'\n'"${loose}")
    print -r -- "${(pj:\n\n:)sections}"
}

# --- entry ------------------------------------------------------------------

# Run _jjw_wip_repo on each repo in parallel; print in the given order.
function _jjw_wip {
    local -a repos
    repos=("$@")
    (( ${#repos} )) || return
    local tmp
    tmp=$(mktemp -d "${TMPDIR:-/tmp}/jjw-wip.XXXXXX")
    {
        (
            local i
            for i in {1..${#repos}}; do
                _jjw_wip_repo "$repos[$i]" >"$tmp/$i" &
            done
            wait
        )
        local i out first=1
        for i in {1..${#repos}}; do
            out=$(<"$tmp/$i")
            [[ -z $out ]] && continue
            (( first )) || print
            first=0
            print -r -- "$out"
        done
        (( first )) && print -r -- "${_JJW_WIP_C[dim]}nothing in progress${_JJW_WIP_C[reset]}"
    } always {
        rm -rf "$tmp"
    }
}

# Resolve the repos for `jjw wip` and run it. Uses the current repo if PWD is in one.
function _jjw_wip_main {
    local _jjw_wip_gh=1
    if [[ $1 == --no-gh ]]; then
        _jjw_wip_gh=0
        shift
    fi
    local -a repos
    if (( $# )); then
        repos=("${(@f)$(_jjw_discover "$@")}")
    else
        local root
        root=$(jj root --ignore-working-copy 2>/dev/null) || root=$(git rev-parse --show-toplevel 2>/dev/null)
        if [[ -n $root ]]; then
            repos=("$root")
        else
            repos=("${(@f)$(_jjw_discover)}")
        fi
    fi
    repos=("${(@)repos:#}")
    if (( ! ${#repos} )); then
        print -u2 "jjw: no repos found"
        return 1
    fi
    repos=("${(@f)$(_jjw_wip_dedupe "${repos[@]}")}")
    _jjw_wip "${repos[@]}"
}
