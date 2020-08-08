###############
# Envs and options
###############

SAVEHIST=50000
HISTFILE=~/.zsh_history
HISTSIZE=50000
HISTORY_IGNORE='(ls|cd|exit|q|nvim|htop)'
setopt HIST_IGNORE_DUPS

export LC_CTYPE=en_US.UTF-8
export LS_COLORS=$LS_COLORS:"di=1;33:ex=1;31:ln=4;36"
export LESS=iMRj5
export BROWSER=/usr/bin/firefox
export EDITOR=/usr/bin/nvim

export CHEATCOLORS=true
export FZF_DEFAULT_COMMAND='rg --files --hidden'
export IDEA_JDK=/usr/lib/jvm/java-11-openjdk
export ANDROID_HOME=$HOME/Android/Sdk/

export _JAVA_OPTIONS="$_JAVA_OPTIONS -Dawt.useSystemAAFontSettings=on -Dswing.aatext=true"
export _JAVA_AWT_WM_NONREPARENTING=1

# pyenv
export PYENV_ROOT="$HOME/.pyenv"
export PATH="$PYENV_ROOT/bin":$PATH

# Virtualenv
export WORKON_HOME=$HOME/.virtualenvs
export PROJECT_HOME=$HOME/devel

# Add home bins
export PATH=$HOME/.local/bin:$HOME/.ghcup/bin:$HOME/.cabal/bin:$PATH


###############
# External sources
###############

# pyenv
if command -v pyenv 1>/dev/null 2>&1; then
    eval "$(pyenv init -)"
fi

# z jump around
[[ -r "/usr/share/z/z.sh" ]] && source "/usr/share/z/z.sh"


###############
# User defined functions
###############

function man {
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

function dirsize {
    # View disk usage of a directory
    du --all --total --human-readable --max-depth=1 $1 | sort -hr | less
}


###############
# Aliases
###############

alias zreload=". $HOME/.zshrc"
alias sudo="sudo "
alias q="exit"
alias ls="ls --color=auto"
alias adb="$HOME/.local/share/android/sdk/platform-tools/adb "

alias fvim='nvim $(fzf)'
alias fcd='cd $(FZF_DEFAULT_COMMAND="fd --hidden --type d" fzf)'

alias lock="swaylock -c 000000"
alias cppass="keepassxc-cli clip $HOME/passwords.kdbx "
alias labs='curl --silent http://liis.ro/hosted/activitati/2013/laboratoare/labs.pdf | zathura -'


###############
# Bindings
###############

# Vi mode
bindkey -v
export KEYTIMEOUT=1

autoload history-search-end
zle -N history-beginning-search-backward-end history-search-end
zle -N history-beginning-search-forward-end history-search-end

bindkey "^P"   history-beginning-search-backward-end
bindkey "^N"   history-beginning-search-forward-end
bindkey "^[[A" up-line-or-history
bindkey "^[[B" down-line-or-history

bindkey "^?"   backward-delete-char
bindkey "^H"   backward-kill-word

autoload edit-command-line
zle -N edit-command-line
bindkey "^E" edit-command-line


# Completion
autoload -Uz compinit
compinit

# Prompt
export PS1="%F{yellow} %~  %f"
export RPS1="%(?..%F{red}[%?])"
