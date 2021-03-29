scriptencoding utf-8

" ==================
"  Options
" ==================
  set hidden cursorline mouse=a scrolloff=5
  set tabstop=4 softtabstop=0 expandtab shiftwidth=4
  " Status bar
  set noshowmode shortmess+=c " Disable completion status spam
  set list listchars=tab:»\ ,extends:›,precedes:‹,nbsp:·,space:·
  set wildignore+=lib,generated,.git,vendor,node_modules
  set wildmode=longest:full,full " Shell-like tab completion
  set foldmethod=indent foldlevelstart=5
  set number relativenumber signcolumn=yes
  set updatetime=300 " For highlighting text under cursor faster
  set ignorecase smartcase inccommand="nosplit"
  set splitright

  set guifont=FiraCode:h14

  let g:tex_fast = "bMmpr" " Better performance in tex
  let g:python_host_prog = '/usr/bin/python2' | let g:python3_host_prog = '/usr/bin/python3'


" ==================
"  Plugins
" ==================
call plug#begin(stdpath('data') . '/plugged')
  " QOL
  Plug 'itchyny/lightline.vim'
    let g:Powerline_symbols = 'fancy'
    let g:lightline =
    \ { 'colorscheme': 'wombat'
    \ , 'active':
    \   { 'left':
    \     [ ['mode', 'paste']
    \     , ['readonly', 'buffnumber', 'filename', 'modified'] ] }
    \   , 'component':
    \       { 'readonly': '%{&readonly?"":""}'
    \       , 'buffnumber': '%n' }
    \   , 'separator': { 'left': '', 'right': '' }
    \   , 'subseparator': { 'left': '', 'right': '' } }
  Plug 'mhinz/vim-startify'
    let g:startify_change_to_dir = 0
    let g:startify_change_to_vcs_root = 1
  Plug 'moll/vim-bbye'
  Plug 'embear/vim-localvimrc'
  Plug 'liuchengxu/vim-which-key'
  Plug 'lukas-reineke/indent-blankline.nvim', {'branch': 'lua'}
    let g:indent_blankline_space_char = '·'
    let g:indent_blankline_space_char_blankline = ' '
    let g:indent_blankline_show_trailing_blankline_indent = v:false

  " Integration
  Plug 'christoomey/vim-tmux-navigator'
  Plug 'tpope/vim-fugitive'
  Plug 'nvim-lua/plenary.nvim' " lua helper lib
  Plug 'lewis6991/gitsigns.nvim'
  Plug 'glacambre/firenvim', { 'do': { _ -> firenvim#install(0) } }
    let g:firenvim_config =
    \ {'localSettings': {'.*': {'takeover': 'never'}}}

  " Text editing
  Plug 'justinmk/vim-sneak'
  Plug 'tpope/vim-surround'
  Plug 'wellle/targets.vim'
  Plug 'tpope/vim-characterize'
  Plug 'tpope/vim-repeat'
  Plug 'tpope/vim-commentary'
  Plug 'luochen1990/rainbow'
  Plug 'junegunn/vim-easy-align'
  Plug 'tommcdo/vim-exchange'
  Plug 'dhruvasagar/vim-table-mode'
  Plug 'kana/vim-textobj-user'
  Plug 'Julian/vim-textobj-variable-segment'

  " Files
  Plug 'preservim/nerdtree'
  Plug 'junegunn/fzf'
  Plug 'junegunn/fzf.vim'
    let g:fzf_layout =
    \ { 'window':
    \   { 'width': 1
    \   , 'height': 0.8
    \   , 'yoffset': 0.01
    \   , 'highlight': 'GruvboxGreen' } }
  Plug 'tpope/vim-eunuch'

  " Completion
  Plug 'neoclide/coc.nvim', { 'branch': 'release' }
  Plug 'honza/vim-snippets'

  " Syntax
  Plug 'vim-scripts/taglist.vim'
  Plug 'AndrewRadev/splitjoin.vim'
  Plug 'pechorin/any-jump.vim'
  Plug 'sbdchd/neoformat'
  Plug 'aouelete/sway-vim-syntax'
  Plug 'jackguo380/vim-lsp-cxx-highlight'
  Plug 'ap/vim-css-color'
  Plug 'lervag/vimtex'
    let g:tex_flavor = 'lualatex'
    let g:vimtex_compiler_method = 'latexrun'
    let g:vimtex_compiler_latexrun =
    \ { 'build_dir': 'latex.out'
    \ , 'options': ['--verbose-cmds', '--latex-args="-synctex=1"'] }
  Plug 'vim-pandoc/vim-pandoc'
  Plug 'vim-pandoc/vim-pandoc-syntax'
  Plug 'OmniSharp/omnisharp-vim'
  Plug 'sheerun/vim-polyglot'
    let g:polyglot_disabled = ['c++11']
    let g:haskell_enable_quantification = 1   "  highlighting of `forall`
    let g:haskell_enable_recursivedo = 1      "  highlighting of `mdo` and `rec`
    let g:haskell_enable_arrowsyntax = 1      "  highlighting of `proc`
    let g:haskell_enable_pattern_synonyms = 1 "  highlighting of `pattern`
    let g:haskell_enable_typeroles = 1        "  highlighting of type roles
    let g:haskell_enable_static_pointers = 1  "  highlighting of `static`
    let g:haskell_backpack = 1                "  highlighting of backpack keywords
  Plug 'nvim-treesitter/nvim-treesitter', {'do': ':TSUpdate'}

  " Colorschemes
  Plug 'gruvbox-community/gruvbox'
  Plug 'sainnhe/gruvbox-material'
call plug#end()

" ==================
"  Colors
" ==================
  set termguicolors
  let g:gruvbox_material_background='hard'
  colorscheme gruvbox-material

" ==================
"  Autocmd
" ==================
augroup autococ
  autocmd!
  " Highlight the symbol and its references when holding the cursor.
  autocmd CursorHold * silent call CocActionAsync('highlight')
  " Setup formatexpr specified filetype(s).
  autocmd FileType typescript,json setl formatexpr=CocAction('formatSelected')
  " Update signature help on jump placeholder.
  autocmd User CocJumpPlaceholder call CocActionAsync('showSignatureHelp')
augroup end
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
" coc.nvim
" ---------
  " Use TAB for completion
  inoremap <silent><expr> <TAB>
      \ pumvisible() ? "\<C-n>" :
      \ <SID>check_back_space() ? "\<TAB>" :
      \ coc#refresh()
  inoremap <expr><S-TAB> pumvisible() ? "\<C-p>" : "\<C-h>"
  inoremap <silent><expr> <c-space> coc#refresh()
  inoremap <expr> <cr> complete_info()["selected"] != "-1" ? "\<C-y>" : "\<C-g>u\<CR>"

  function! s:check_back_space() abort
    let col = col('.') - 1
    return !col || getline('.')[col - 1]  =~# '\s'
  endfunction

  " Scroll popup
  inoremap <silent><nowait><expr> <C-f> coc#float#has_scroll() ? "\<c-r>=coc#float#scroll(1)\<cr>" : "\<Right>"
  inoremap <silent><nowait><expr> <C-b> coc#float#has_scroll() ? "\<c-r>=coc#float#scroll(0)\<cr>" : "\<Left>"

  " Snippet jump
  let g:coc_snippet_next = '<M-j>'
  let g:coc_snippet_prev = '<M-k>'

  " Use `[g` and `]g` to navigate diagnostics
  nmap <silent> [g <Plug>(coc-diagnostic-prev)
  nmap <silent> ]g <Plug>(coc-diagnostic-next)

  " GoTo code navigation.
  nmap <silent> gd <Plug>(coc-definition)
  " Go to definition in split window
  nmap <silent> <leader>wgd :vsplit<CR>:norm gd<CR>
  nmap <silent> gy <Plug>(coc-type-definition)
  nmap <silent> gi <Plug>(coc-implementation)
  nmap <silent> gr <Plug>(coc-references)

  " Use K to show documentation in preview window.
  nnoremap <silent> K :call <SID>show_documentation()<CR>
  function! s:show_documentation()
      if (index(['vim','help'], &filetype) >= 0)
          execute 'vert h '.expand('<cword>')
      else
          call CocAction('doHover')
      endif
  endfunction

  " Symbol renaming.
  nmap <F2> <Plug>(coc-rename)

  " Formatting selected code.
  xmap <leader>cf  <Plug>(coc-format-selected)
  nmap <leader>cf  <Plug>(coc-format-selected)

  " Applying codeAction to the selected region.
  " Example: `<leader>aap` for current paragraph
  xmap <leader>ca  <Plug>(coc-codeaction-selected)
  nmap <leader>ca  <Plug>(coc-codeaction-selected)

  " Apply codeAction to the current line.
  nmap <leader>cal  <Plug>(coc-codeaction)
  " Apply AutoFix to problem on the current line.
  nmap <leader>cqf  <Plug>(coc-fix-current)

  " Introduce function text object
  " NOTE: Requires 'textDocument.documentSymbol' support from the language server.
  xmap if <Plug>(coc-funcobj-i)
  xmap af <Plug>(coc-funcobj-a)
  omap if <Plug>(coc-funcobj-i)
  omap af <Plug>(coc-funcobj-a)

  " Use <TAB> for selections ranges.
  " NOTE: Requires 'textDocument/selectionRange' support from the language server.
  " coc-tsserver, coc-python are the examples of servers that support it.
  nmap <silent> <TAB> <Plug>(coc-range-select)
  xmap <silent> <TAB> <Plug>(coc-range-select)

  " Add `:Format` command to format current buffer.
  command! -nargs=0 Format :call CocAction('format')
  " Add `:Fold` command to fold current buffer.
  command! -nargs=? Fold   :call CocAction('fold', <f-args>)
  " Add `:OR` command for organize imports of the current buffer.
  command! -nargs=0 OR     :call CocAction('runCommand', 'editor.action.organizeImport')
  " Manage extensions.
  command! -nargs=0 CocExtensions  :<C-u>CocList extensions<cr>

  " Mappings using CocList:
  " Show Coc commands.
  nnoremap <silent> <space>cc  :<C-u>CocList commands<cr>
  " Find symbols in current document.
  nnoremap <silent> <space>co  :<C-u>CocList outline<cr>
  " Quickly reopen last CocList screen.
  nnoremap <silent> <space>cl  :<C-u>CocListResume<CR>

" ---------
" vim-easy-align
" ---------
nmap <leader>a <Plug>(EasyAlign)
xmap <leader>a <Plug>(EasyAlign)


" ==================
"  Lua
" ==================
lua <<EOF
-- treesitter
require'nvim-treesitter.configs'.setup {
  highlight = {
    enable = true
  },
  indent = {
    enable = true
  }
}
require'gitsigns'.setup()
EOF
