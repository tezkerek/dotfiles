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
  set foldmethod=indent foldlevelstart=5
  set number relativenumber signcolumn=yes
  set updatetime=300 " For highlighting text under cursor faster
  set ignorecase smartcase inccommand="nosplit"

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
  Plug 'moll/vim-bbye'
  Plug 'embear/vim-localvimrc'

  " Integration
  Plug 'christoomey/vim-tmux-navigator'
  Plug 'glacambre/firenvim', { 'do': { _ -> firenvim#install(0) } }
    let g:firenvim_config =
    \ {'localSettings': {'.*': {'takeover': 'never'}}}

  " Text editing
  Plug 'justinmk/vim-sneak'
  Plug 'tpope/vim-surround'
  Plug 'tpope/vim-characterize'
  Plug 'tpope/vim-repeat'
  Plug 'tpope/vim-commentary'
  Plug 'luochen1990/rainbow'
  Plug 'junegunn/vim-easy-align'
  Plug 'tommcdo/vim-exchange'
  Plug 'dhruvasagar/vim-table-mode'

  " Files
  Plug 'jeetsukumaran/vim-filebeagle'
  Plug 'preservim/nerdtree'
  Plug 'junegunn/fzf'
  Plug 'junegunn/fzf.vim'
    let g:fzf_layout =
    \ { 'window':
    \   { 'width': 1
    \   , 'height': 0.8
    \   , 'yoffset': 0.01
    \   , 'highlight': 'GruvboxGreen' } }
  Plug 'tpope/vim-fugitive'
  Plug 'tpope/vim-eunuch'

  " Completion
  Plug 'neoclide/coc.nvim', { 'branch': 'release' }
  Plug 'honza/vim-snippets'

  " Syntax
  Plug 'vim-scripts/taglist.vim'
  Plug 'AndrewRadev/splitjoin.vim'
  Plug 'pechorin/any-jump.vim'
  Plug 'sbdchd/neoformat'
  Plug 'jackguo380/vim-lsp-cxx-highlight'
  Plug 'ap/vim-css-color'
  Plug 'lervag/vimtex'
    let g:tex_flavor = 'lualatex'
    let g:vimtex_compiler_method = 'latexrun'
    let g:vimtex_compiler_latexrun =
    \ { 'build_dir': 'latex.out'
    \ , 'options': ['--verbose-cmds', '--latex-args="-synctex=1"'] }
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

  " Colorschemes
  Plug 'gruvbox-community/gruvbox'
  Plug 'sainnhe/gruvbox-material'
call plug#end()

" ==================
"  Colors
" ==================
  set termguicolors
  let g:gruvbox_material_background='hard'
  colorscheme gruvbox

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
  autocmd FileType cs nmap <silent> <buffer> <Space>ca <Plug>(omnisharp_code_actions)
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
" ---------
" Misc
" ---------
  nnoremap j gj
  nnoremap gj j
  nnoremap k gk
  nnoremap gk k

  " Delete word with ctrl+backspace
  inoremap <C-H> <C-W>

  " Quickly disable hlsearch
  nnoremap <silent> <Esc> :nohlsearch<CR>

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
  nnoremap <silent> + :call InsertEmptyLine()<CR>

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
" fzf
" ---------
  nnoremap <silent> <C-P> :Files<CR>
  " Browse buffers
  nnoremap <silent> <Space>b :Buffers<CR>
  " Jump to window if possible
  let g:fzf_buffers_jump = 1

  " Search with rg
  nnoremap <silent> <Space>g :Rg<CR>
  " Search in current buffer
  nnoremap <silent> <Space>/ :BLines<CR>

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

  " Snippet jump
  let g:coc_snippet_next = '<M-j>'
  let g:coc_snippet_prev = '<M-k>'

  " Use `[g` and `]g` to navigate diagnostics
  nmap <silent> [g <Plug>(coc-diagnostic-prev)
  nmap <silent> ]g <Plug>(coc-diagnostic-next)

  " GoTo code navigation.
  nmap <silent> gd <Plug>(coc-definition)
  " Go to definition in split window
  nmap <silent> <Space>wgd :vsplit<CR>:norm gd<CR>
  nmap <silent> gy <Plug>(coc-type-definition)
  nmap <silent> gi <Plug>(coc-implementation)
  nmap <silent> gr <Plug>(coc-references)

  " Use K to show documentation in preview window.
  nnoremap <silent> K :call <SID>show_documentation()<CR>
  function! s:show_documentation()
      if (index(['vim','help'], &filetype) >= 0)
          execute 'h '.expand('<cword>')
      else
          call CocAction('doHover')
      endif
  endfunction

  " Symbol renaming.
  nmap <F2> <Plug>(coc-rename)

  " Formatting selected code.
  xmap <leader>f  <Plug>(coc-format-selected)
  nmap <leader>f  <Plug>(coc-format-selected)

  " Applying codeAction to the selected region.
  " Example: `<leader>aap` for current paragraph
  xmap <leader>a  <Plug>(coc-codeaction-selected)
  nmap <leader>a  <Plug>(coc-codeaction-selected)

  " Remap keys for applying codeAction to the current line.
  nmap <leader>ac  <Plug>(coc-codeaction)
  nmap <silent> <Space>ca   :CocAction<CR>
  " Apply AutoFix to problem on the current line.
  nmap <leader>qf  <Plug>(coc-fix-current)

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

  " Mappings using CoCList:
  " Manage extensions.
  nnoremap <silent> <space>e  :<C-u>CocList extensions<cr>
  " Show commands.
  nnoremap <silent> <space>c  :<C-u>CocList commands<cr>
  " Find symbol of current document.
  nnoremap <silent> <space>o  :<C-u>CocList outline<cr>
  " Search workspace symbols.
  nnoremap <silent> <space>s  :<C-u>CocList -I symbols<cr>
  " Do default action for next item.
  nnoremap <silent> <space>j  :<C-u>CocNext<CR>
  " Do default action for previous item.
  nnoremap <silent> <space>k  :<C-u>CocPrev<CR>
  " Resume latest coc list.
  nnoremap <silent> <space>p  :<C-u>CocListResume<CR>

" ---------
" vim-easy-align
" ---------
nmap <Space>a <Plug>(EasyAlign)
xmap <Space>a <Plug>(EasyAlign)
