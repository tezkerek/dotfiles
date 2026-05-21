[[ -d $HOME/.rd/bin ]] && path=($HOME/.rd/bin $path)
[[ -d $HOME/.cargo/bin ]] && path=($HOME/.cargo/bin $path)
[[ -d /opt/homebrew/opt/pnpm@10/bin ]] && path=(/opt/homebrew/opt/pnpm@10/bin $path)
(( $+commands[brew] )) && path=($(brew --prefix rustup)/bin $path)

# Homebrew completions
if type brew &>/dev/null; then
    local brewpath=$(brew --prefix)/share/zsh-completions
    FPATH=$brewpath:$FPATH
fi
