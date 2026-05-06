function {
    local fzf_bindings="alt-j:preview-down,alt-k:preview-up,\
ctrl-alt-d:preview-half-page-down,ctrl-alt-u:preview-half-page-up,\
alt-p:toggle-preview,alt-w:toggle-preview-wrap-word"
    export FZF_PREVIEW_BAT='bat --style=numbers --color=always'
    export FZF_PREVIEW_EZA='eza -l --no-permissions --no-user --color=always --git --icons'

    # Fzf options
    export FZF_DEFAULT_OPTS="--bind=$fzf_bindings"
    export FZF_DEFAULT_COMMAND="rg --files --hidden --glob '!\.git'"

    # Fzf aliases
    alias fvim='nvim $(fd --hidden | fzf)'
    alias fcd='cd $(fd --hidden --type d | fzf)'
    function fzo {
        local fzf_header="Enter: open file    CTRL-O: cd dir    CTRL-F: open dir\n\n"
        local result=$(fd --follow --type f . $@ | fzf --reverse --expect=ctrl-o,ctrl-f --header $fzf_header)
        local file=$(tail -n1 <<< $result)
        local cmd=$(head -n1 <<< $result)
        case $cmd in
            ctrl-o)
                zsh -c "cd $(dirname $file); zsh -i"
                ;;
            ctrl-f)
                (o $(dirname $file) & disown) > /dev/null 2>&1
                ;;
            *)
                (o $file & disown) > /dev/null 2>&1
                ;;
        esac
    }

    # Fzf file completion
    function fzf-select-files {
        local selected=$(fd . | fzf --multi \
            --preview '
                if [ -d {} ]; then
                    '$FZF_PREVIEW_EZA' {}
                else
                    '$FZF_PREVIEW_BAT' {}
                fi
            ' \
            --header "Tab to select") || return 0
        local escaped=$(printf '%q ' ${(f)selected})
        LBUFFER+="$escaped"
    }
    zle -N fzf-select-files
    bindkey "^F" fzf-select-files

    # Fzf tab completion
    zstyle ':fzf-tab:*' fzf-flags --preview-window=wrap-word --bind=$fzf_bindings
    zstyle ':fzf-tab:complete:*' fzf-preview '
        local resolvedpath="$realpath"
        if [[ -z "$resolvedpath" ]]; then
            # Completions can mix paths and arguments
            # Try parsing the completion as a path
            if [[ -a "$desc" ]]; then
                resolvedpath="$desc"
            else
                echo "$desc" | sed "s/\s\s\+/ /g"
                return
            fi
        fi

        if [[ -d "$resolvedpath" ]]; then
            '$FZF_PREVIEW_EZA' "$resolvedpath"
        else
            local type=$(file --brief --dereference --mime -- "$resolvedpath")
            if [[ "$type" =~ image/ ]]; then
                kitten icat --clear --transfer-mode=memory --unicode-placeholder --stdin=no \
                    --place="${FZF_PREVIEW_COLUMNS}x${FZF_PREVIEW_LINES}@0x0" \
                    "$resolvedpath"
            else
                '$FZF_PREVIEW_BAT' "$resolvedpath"
            fi
        fi
    '
}
