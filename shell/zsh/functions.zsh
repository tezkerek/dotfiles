function mvp {
    local last="${@: -1}"
    if [[ "$last" == */ ]]; then
        mkdir -p "$last"
    else
        mkdir -p "$last:h"
    fi
    mv "$@"
}
