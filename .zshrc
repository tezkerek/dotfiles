source $HOME/.zsh_env

# pyenv
if command -v pyenv 1>/dev/null 2>&1; then
    eval "$(pyenv init -)"
fi

# z jump around
[[ -r "/usr/share/z/z.sh" ]] && source "/usr/share/z/z.sh"

man() {
    # Enable colors for manpages
    LESS_TERMCAP_md=$'\e[01;31m' \
    LESS_TERMCAP_me=$'\e[0m' \
    LESS_TERMCAP_se=$'\e[0m' \
    LESS_TERMCAP_so=$'\e[0;44;39m' \
    LESS_TERMCAP_ue=$'\e[0m' \
    LESS_TERMCAP_us=$'\e[01;32m' \
    command man "$@"
}

function md {
    # Faster creation of directories
    mkdir --parents $1 && cd $1
}

source "$HOME/.zsh_alias"

# Vi mode
bindkey -v
export KEYTIMEOUT=1

# Bindings
bindkey "^[[A" history-beginning-search-backward
bindkey "^[OA" history-beginning-search-backward
bindkey "^P"   up-line-or-history
bindkey "^[[B" history-beginning-search-forward
bindkey "^[OB" history-beginning-search-forward
bindkey "^N"   down-line-or-history
bindkey "^[O8" end-of-line
bindkey "^[O7" beginning-of-line
bindkey "^?"   backward-delete-char
bindkey "^H"   backward-kill-word

autoload -Uz compinit
compinit

export PS1="%F{yellow} %~  %f"

export RPS1="%(?..%F{red}[%?])"
