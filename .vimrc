scriptencoding utf-8

set nocompatible

set runtimepath+=~/.vim/

call plug#begin('~/.vim/plugged')

" ==================
"  Plugins
" ==================

Plug 'itchyny/lightline.vim'
Plug 'scrooloose/syntastic'

Plug 'justinmk/vim-sneak'
Plug 'jiangmiao/auto-pairs'
Plug 'tpope/vim-surround'
Plug 'tpope/vim-fugitive'
Plug 'tpope/vim-characterize'
Plug 'tpope/vim-repeat'
Plug 'tpope/vim-commentary'

" Files
Plug 'jeetsukumaran/vim-filebeagle'
Plug 'junegunn/fzf'
Plug 'junegunn/fzf.vim'

" QOL
Plug 'mhinz/vim-startify'
Plug 'christoomey/vim-tmux-navigator'
Plug 'moll/vim-bbye'

" Completion
Plug 'Shougo/deoplete.nvim'
Plug 'zchee/deoplete-jedi'
Plug 'carlitux/deoplete-ternjs'
Plug 'lvht/phpcd.vim', { 'for': 'php', 'do': 'composer install' }

" Syntax
Plug 'kovetskiy/sxhkd-vim'
"Plugin 'lilydjwg/colorizer'
Plug 'walm/jshint.vim'
"Plug 'shawncplus/phpcomplete.vim'
Plug 'cakebaker/scss-syntax.vim'
Plug 'nono/jquery.vim'
Plug 'Quramy/vim-js-pretty-template'
Plug 'lervag/vimtex'
Plug 'vim-scripts/taglist.vim'
Plug 'jwalton512/vim-blade'
Plug 'mustache/vim-mustache-handlebars'
Plug 'pangloss/vim-javascript'
Plug 'ElmCast/elm-vim'
Plug 'Vimjas/vim-python-pep8-indent'

" Colorschemes
Plug 'sjl/badwolf'
Plug 'altercation/vim-colors-solarized'
Plug 'morhetz/gruvbox'
Plug 'jansenfuller/crayon'

call plug#end()

" ==================
"  Plugin config
" ==================

" Lightline
let g:Powerline_symbols = 'fancy'
let g:lightline = {
    \   'colorscheme': 'wombat',
    \   'active': {
    \       'left': [ [ 'mode', 'paste' ],
    \               [ 'readonly', 'buffnumber', 'filename', 'modified' ] ]
    \   },
    \   'component': {
    \       'readonly': '%{&readonly?"":""}',
    \       'buffnumber': '%n'
    \   },
    \   'separator': { 'left': '', 'right': '' },
    \   'subseparator': { 'left': '', 'right': '' }
    \ }

" Syntastic recommended settings
let g:syntastic_always_populate_loc_list = 1
let g:syntastic_auto_loc_list = 1
let g:syntastic_check_on_open = 1
let g:syntastic_enable_signs = 1
let g:syntastic_check_on_wq = 0

let g:tex_fast = "bMmpr"

" Syntastic checkers
let g:syntastic_javascript_checkers = ['jshint']
let g:syntastic_php_checkers = ['php', 'phplint']
let g:syntastic_cpp_checkers = ['clang_check']

" Conceal
let g:indentLine_fileTypeExclude = ['json', 'latex']
let g:indentLine_char = '▏'

" |-----------------------------------------
" | Neovim
" |-----------------------------------------
" Python in virtualenv
let g:python_host_prog = '/usr/bin/python2'
let g:python3_host_prog = '/usr/bin/python3'

" Use deoplete.
let g:deoplete#enable_at_startup = 1
" Use smartcase.
let g:deoplete#enable_smart_case = 1
" Hide preview window after leaving insert
autocmd InsertLeave,CompleteDone * if pumvisible() == 0 | pclose | endif

" deoplete-ternjs
let g:deoplete#sources#ternjs#types = 1
let g:deoplete#sources#ternjs#docs = 1

" deoplete with phpcd
let g:deoplete#ignore_sources = get(g:, 'deoplete#ignore_sources', {})
let g:deoplete#ignore_sources.php = ['omni']

" deoplete with vimtex
call deoplete#custom#var('omni', 'input_patterns', {
    \ 'tex': g:vimtex#re#deoplete
    \ })

"autocmd Filetype json let g:indentLine_setConceal = 0

" ==================
"  Bindings
" ==================

" <C-h>, <BS>: close popup and delete backword char.
inoremap <expr><C-h> deoplete#smart_close_popup()."\<C-h>"
inoremap <expr><BS>  deoplete#smart_close_popup()."\<C-h>"

" <CR>: close popup and save indent.
inoremap <silent> <CR> <C-r>=<SID>my_cr_function()<CR>
function! s:my_cr_function() abort
    return deoplete#close_popup() . "\<CR>"
endfunction

" Convert Sass/SCSS to CSS on write
":autocmd BufWritePost *.scss execute ":silent !sass " . expand('%') .  " " . expand('%:r') . ".css"
" HTML syntax highlighting in JS
:autocmd FileType javascript :JsPreTmpl html

" ============================================ Mappings

" Substitute word under cursor
nnoremap <Leader>s :%s/\<<C-r><C-w>\>//g<Left><Left>
" Substitute visual selection
vnoremap <Leader>s "sy:%s/\<<C-r>s\>//g<Left><Left>

" Indent all and return to position
nnoremap g= gg=G``

" Insert line under cursor
function! InsertEmptyLine()
    let cursor = getpos(".")
    exec "normal o\<Esc>"
    call setpos(".", cursor)
endfunction
nnoremap <silent> <CR> :call InsertEmptyLine()<CR>

" Split navigation
nnoremap <C-H> <C-W>h
nnoremap <C-J> <C-W>j
nnoremap <C-K> <C-W>k
nnoremap <C-L> <C-W>l

" Buffer navigation
nnoremap <silent> gb :bnext<CR>
nnoremap <silent> gB :bprevious<CR>

" Tab navigation
nnoremap <M-1> 1gt
nnoremap <M-2> 2gt
nnoremap <M-3> 3gt
nnoremap <M-4> 4gt
nnoremap <M-5> 5gt
nnoremap <M-6> 6gt
nnoremap <M-7> 7gt
nnoremap <M-8> 8gt
nnoremap <silent> <M-9> :tablast<CR>

" =========
" fzf
" =========
nnoremap <C-P> :Files<CR>

" Browse buffers
nnoremap <Space>b :Buffers<CR>
" Jump to window if possible
let g:fzf_buffers_jump = 1

" Search with ag
nnoremap <Space>g :Ag<CR>
" Search in current buffer
nnoremap <Space>/ :BLines<CR>

" ==================
"  Options
" ==================

" Indentation
set tabstop=4 softtabstop=0
set expandtab smarttab
set shiftwidth=4

" For the lightline.vim plugin
set laststatus=2
set noshowmode


" Other settings
filetype plugin indent on
syntax on
set foldmethod=indent
set hidden
set number
set ignorecase
set smartcase
set incsearch
set cursorline
set wildignore+=lib,generated,.git,vendor,node_modules
set showcmd
set scrolloff=5
set mouse=a
set list
set listchars=tab:»\ ,extends:›,precedes:‹,nbsp:·,trail:·

" Colorscheme
colorscheme gruvbox
let g:gruvbox_italic = 1
set background=dark
set t_ut=

" Custom crayon colors
let current_colorscheme = get(g:, "colors_name", "default")
if current_colorscheme ==# "crayon"
    augroup Color
        autocmd!
        autocmd ColorScheme * hi CursorLine ctermbg=10 ctermfg=NONE cterm=NONE guibg=NONE guifg=#383E47 gui=NONE
        autocmd ColorScheme * hi ErrorMsg   ctermbg=NONE ctermfg=9 cterm=NONE guibg=NONE guifg=#383E47 gui=NONE
        "autocmd ColorScheme * hi MatchParen ctermbg=3 ctermfg=10 cterm=NONE guibg=#D8C27A guifg=#282C33 gui=NONE
    augroup END
endif

