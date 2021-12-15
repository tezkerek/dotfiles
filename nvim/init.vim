scriptencoding utf-8

" ==================
"  Options
" ==================
  set hidden cursorline mouse=a scrolloff=5
  set tabstop=4 softtabstop=0 expandtab shiftwidth=4
  " Status bar
  set noshowmode shortmess+=c " Disable completion status spam
  set list listchars=tab:┄┄⇥,extends:›,precedes:‹,nbsp:·,lead:⠀,space:·
  set wildignore+=lib,generated,.git,vendor,node_modules
  set wildmode=longest:full,full " Shell-like tab completion
  set foldmethod=indent foldlevelstart=5
  set number relativenumber signcolumn=yes
  set updatetime=300 " For highlighting text under cursor faster
  set ignorecase smartcase inccommand="nosplit"
  set splitright
  set completeopt=menu,menuone,noselect

  set guifont=monospace:h15

  let g:tex_fast = "bMmpr" " Better performance in tex
  let g:python_host_prog = '/usr/bin/python2' | let g:python3_host_prog = '/usr/bin/python3'


" ==================
"  Plugins
" ==================
  lua vim.lsp.set_log_level("debug")
  lua require('plugins')

  let g:startify_change_to_dir = 0
  let g:startify_change_to_vcs_root = 1

  let g:firenvim_config =
  \ {'localSettings': {'.*': {'takeover': 'never'}}}

  let g:fzf_layout =
  \ { 'window':
  \   { 'width': 1
  \   , 'height': 0.8
  \   , 'yoffset': 0.01
  \   , 'highlight': 'GruvboxGreen' } }

  let g:pandoc#spell#default_langs = ['en', 'ro']

  let g:polyglot_disabled = ['c++11']
  let g:haskell_enable_quantification = 1   "  highlighting of `forall`
  let g:haskell_enable_recursivedo = 1      "  highlighting of `mdo` and `rec`
  let g:haskell_enable_arrowsyntax = 1      "  highlighting of `proc`
  let g:haskell_enable_pattern_synonyms = 1 "  highlighting of `pattern`
  let g:haskell_enable_typeroles = 1        "  highlighting of type roles
  let g:haskell_enable_static_pointers = 1  "  highlighting of `static`
  let g:haskell_backpack = 1                "  highlighting of backpack keywords

" ==================
"  Colors
" ==================
  set termguicolors
  let g:gruvbox_material_background='hard'
  let g:onedark_style = 'darker'
  colorscheme tokyonight

" ==================
"  Autocmd
" ==================
augroup omnisharp
  autocmd!

  autocmd CursorHold *.cs OmniSharpTypeLookup

  autocmd FileType cs nmap <silent> <buffer> K <Plug>(omnisharp_documentation)
  autocmd FileType cs nmap <silent> <buffer> gd <Plug>(omnisharp_go_to_definition)
  autocmd FileType cs nmap <silent> <buffer> <leader>ca <Plug>(omnisharp_code_actions)
augroup end
augroup indent
  autocmd!
  autocmd FileType haskell setlocal shiftwidth=2 softtabstop=2 expandtab
augroup end
augroup linenum
  autocmd!
  autocmd BufEnter,FocusGained,InsertLeave * if &number | set relativenumber
  autocmd BufLeave,FocusLost,InsertEnter   * set norelativenumber
augroup end
augroup sigwinch
  autocmd!
  autocmd VimEnter * silent exec "!kill -s SIGWINCH" getpid()
augroup end

" ==================
"  Keyboard mapping
" ==================
  let g:mapleader = "\<Space>"

" ---------
" which-key
" ---------
  nnoremap <silent> <leader> :<C-U>WhichKey '<Space>'<CR>

" ---------
" Misc
" ---------
  cnoreabbrev h vert h

  nnoremap j gj
  nnoremap gj j
  nnoremap k gk
  nnoremap gk k

  " Delete word with ctrl+backspace
  inoremap <C-H> <C-W>

  " Quickly disable hlsearch
  nnoremap <silent> <Esc> :nohlsearch<CR>

  " Substitute word under cursor
  nnoremap <leader>s :%s/\<<C-r><C-w>\>//g<Left><Left>
  " Substitute visual selection
  vnoremap <leader>s "sy:%s/\<<C-r>s\>//g<Left><Left>

  " Indent all and return to position
  nnoremap g= gg=G``

  nnoremap <silent> <leader>cf :Neoformat<CR>

  " Insert line under cursor
  nnoremap <silent> + :call InsertEmptyLine()<CR>
  function! InsertEmptyLine()
    let cursor = getpos(".")
    exec "normal o\<Esc>"
    call setpos(".", cursor)
  endfunction

  " Toggle semicolon at end of line
  nnoremap <silent> <M-;> :call ToggleSemicolon()<CR>
  inoremap <silent> <M-;> <C-O>:call ToggleSemicolon()<CR>
  function! ToggleSemicolon()
    let lnum = line(".")
    let l = getline(".")
    let linelen = strchars(l)
    let c = nr2char(strgetchar(l, linelen-1))
    if c == ';'
      call setline(lnum, strcharpart(l, 0, linelen-1))
    else
      call setline(lnum, l .. ';')
    endif
    "call setpos(".", initialpos)
  endfunction

  " Better leader for window management
  nnoremap <leader>w <C-W>

  " Split navigation
  nnoremap <C-H> <C-W>h
  nnoremap <C-J> <C-W>j
  nnoremap <C-K> <C-W>k
  nnoremap <C-L> <C-W>l

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

  " Remap jumplist commands because of completion <TAB> conflict
  nnoremap <M-i> <C-I>
  nnoremap <M-o> <C-O>

" ---------
" Files
" ---------
  nnoremap <silent> <leader>fw :w<CR>
  nnoremap <silent> <leader>ff :Files<CR>
  nnoremap <silent> <leader>ft :NERDTreeToggle<CR>
  " Browse buffers
  nnoremap <silent> <leader>, :Buffers<CR>
  " Jump to window if possible
  let g:fzf_buffers_jump = 1

  " Search with rg
  nnoremap <silent> <leader>fg :Rg<CR>
  " Search in current buffer
  nnoremap <silent> <leader>/ :BLines<CR>

" ---------
" vim-easy-align
" ---------
nmap <leader>a <Plug>(EasyAlign)
xmap <leader>a <Plug>(EasyAlign)
