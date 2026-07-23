function mvp {
    local last="${@: -1}"
    if [[ "$last" == */ ]]; then
        mkdir -p "$last"
    else
        mkdir -p "$last:h"
    fi
    mv "$@"
}

function lsmd {
    zmodload zsh/stat || return
    zmodload zsh/datetime || return

    local file entry timestamp creation_time sort_key
    local repository repository_root jj_root git_root relative_file
    local bold reset cyan yellow
    local -a entries file_stat repositories git_args check_ignore_args

    if [[ -o interactive ]]; then
        bold=$'\e[1m'
        reset=$'\e[0m'
        cyan=$'\e[36m'
        yellow=$'\e[33m'
    fi

    if jj root >/dev/null 2>&1 || git rev-parse --show-toplevel >/dev/null 2>&1; then
        repositories=(.)
    else
        for repository in ./*(DN/); do
            [[ -e "$repository/.git" || -e "$repository/.jj" ]] &&
                repositories+=("$repository")
        done
    fi

    for repository in "${repositories[@]}"; do
        repository_root="${repository:A}"

        if git -C "$repository_root" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
            git_args=(-C "$repository_root")
            check_ignore_args=()
        else
            jj_root=$(cd -- "$repository_root" && jj root 2>/dev/null) || continue
            git_root=$(jj -R "$jj_root" git root 2>/dev/null) || continue
            git_args=(
                --git-dir="$git_root"
                --work-tree="$jj_root"
                -c core.bare=false
            )
            check_ignore_args=(--no-index)
        fi

        while IFS= read -r -d '' relative_file; do
            file="$relative_file"
            relative_file="${relative_file#$repository_root/}"
            zstat -A file_stat +mtime -- "$file" || continue
            creation_time=$(
                eza --long --created --time-style='+%s' \
                    --no-permissions --no-filesize --no-user \
                    --color=never --icons=never --hyperlink=never \
                    -- "$file"
            ) || continue
            creation_time="${creation_time%% *}"
            [[ $creation_time == <-> ]] || creation_time=0
            printf -v sort_key '%020d%020d' "${file_stat[1]}" "$creation_time"
            if [[ "$repository" == "." ]]; then
                file="${relative_file#./}"
            else
                file="${repository#./}/${relative_file#./}"
            fi
            entries+=("${sort_key}"$'\t'"${file_stat[1]}"$'\t'"$file")
        done < <(
            cd -- "$repository_root" || exit
            fd --hidden --no-ignore --type f --extension md \
                --exclude .git --exclude .jj \
                --exclude node_modules \
                --exclude .venv --exclude venv \
                --exclude vendor --exclude target \
                --exclude dist --exclude build --exclude out \
                --absolute-path --print0 . |
                git "${git_args[@]}" check-ignore "${check_ignore_args[@]}" --stdin -z
        )
    done

    for entry in "${(@o)entries}"; do
        entry="${entry#*$'\t'}"
        file="${entry#*$'\t'}"
        strftime -s timestamp '%Y-%m-%d %H:%M:%S' "${entry%%$'\t'*}"
        print -r -- "${yellow}[${timestamp}]${reset} ${bold}${cyan}${file}${reset}"
    done
}
