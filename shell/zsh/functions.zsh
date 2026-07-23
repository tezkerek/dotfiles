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
    local bold reset cyan yellow
    local -a entries file_stat

    if [[ -o interactive ]]; then
        bold=$'\e[1m'
        reset=$'\e[0m'
        cyan=$'\e[36m'
        yellow=$'\e[33m'
    fi

    while IFS= read -r -d '' file; do
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
        entries+=("${sort_key}"$'\t'"${file_stat[1]}"$'\t'"${file#./}")
    done < <(
        fd --hidden --no-ignore --type f --extension md \
            --exclude .git --exclude .jj \
            --exclude node_modules \
            --exclude .venv --exclude venv \
            --exclude vendor --exclude target \
            --exclude dist --exclude build --exclude out \
            --print0 . |
            git check-ignore --stdin -z
    )

    for entry in "${(@o)entries}"; do
        entry="${entry#*$'\t'}"
        file="${entry#*$'\t'}"
        strftime -s timestamp '%Y-%m-%d %H:%M:%S' "${entry%%$'\t'*}"
        print -r -- "${yellow}[${timestamp}]${reset} ${bold}${cyan}${file}${reset}"
    done
}
