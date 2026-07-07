local lazypath = vim.fn.stdpath('data') .. '/lazy/lazy.nvim'
if not vim.uv.fs_stat(lazypath) then
    vim.fn.system {
        'git',
        'clone',
        '--filter=blob:none',
        'https://github.com/folke/lazy.nvim.git',
        '--branch=stable',
        lazypath,
    }
end
vim.opt.rtp:prepend(lazypath)

require('lazy').setup {
    concurrency = 16,
    spec = {
        -- QOL
        {
            'nvim-lualine/lualine.nvim',
            dependencies = 'kyazdani42/nvim-web-devicons',
            config = function()
                require('plugins/lualine').setup()
            end,
        },
        'mhinz/vim-startify',
        'moll/vim-bbye',
        {
            'folke/which-key.nvim',
            config = function()
                local wk = require('which-key')
                wk.add {
                    { '<Space>f', group = 'files' },
                    { '<Space>b', group = 'buffers', icon = '' },
                    { '<Space>c', group = 'code_commands' },
                    { '<Space>l', group = 'lsp', icon = '' },
                    { '<Space>w', group = 'window', proxy = '<C-w>' },
                    { '<Space>h', group = 'hunk', icon = '' },
                    { '<Space>t', group = 'table' },
                }
                vim.keymap.set('n', '<Space>?', function()
                    require('which-key').show { global = true }
                end, { desc = 'Help' })
            end,
        },
        {
            'lukas-reineke/indent-blankline.nvim',
            config = function()
                require('ibl').setup {
                    exclude = { filetypes = { 'NvimTree', 'help', 'startify' } },
                }
            end,
        },
        { 'folke/snacks.nvim' },

        -- Integration
        'christoomey/vim-tmux-navigator',
        'tpope/vim-fugitive',
        {
            'lewis6991/gitsigns.nvim',
            enabled = false,
            config = function()
                require('plugins/gitsigns').setup()
            end,
        },
        {
            'NicolasGB/jj.nvim',
            config = function()
                require('jj').setup {}
            end,
        },
        {
            'algmyr/vcsigns.nvim',
            dependencies = { 'algmyr/vclib.nvim', 'lewis6991/async.nvim' },
            config = function()
                require('plugins/vcsigns').setup()
            end,
        },
        {
            'clabby/difftastic.nvim',
            dependencies = {
                'MunifTanjim/nui.nvim',
                'folke/snacks.nvim',
            },
            config = function()
                require('difftastic-nvim').setup {
                    snacks_picker = { enabled = true },
                }
            end,
        },
        {
            'glacambre/firenvim',
            build = function()
                vim.fn['firenvim#install'](0)
            end,
        },

        -- Text editing
        'justinmk/vim-sneak',
        'tpope/vim-surround',
        'wellle/targets.vim',
        'tpope/vim-characterize',
        'tpope/vim-repeat',
        'tpope/vim-commentary',
        'luochen1990/rainbow',
        'junegunn/vim-easy-align',
        'tommcdo/vim-exchange',
        'dhruvasagar/vim-table-mode',
        {
            'Julian/vim-textobj-variable-segment',
            dependencies = 'kana/vim-textobj-user',
        },
        {
            'windwp/nvim-autopairs',
            config = function()
                require('nvim-autopairs').setup()
            end,
        },

        -- Files
        {
            'kyazdani42/nvim-tree.lua',
            config = function()
                require('plugins/nvim-tree').setup()
            end,
        },
        {
            'ibhagwan/fzf-lua',
            dependencies = { 'nvim-tree/nvim-web-devicons' },
            config = function()
                require('plugins/fzf-lua').setup()
            end,
        },
        'tpope/vim-eunuch',

        -- Syntax
        'tpope/vim-sleuth',
        'AndrewRadev/splitjoin.vim',
        {
            'hedyhli/outline.nvim',
            config = function()
                require('outline').setup()
                vim.keymap.set(
                    'n',
                    '<Space>co',
                    ':Outline<CR>',
                    { desc = 'Toggle outline' }
                )
            end,
        },
        'sbdchd/neoformat',
        {
            'norcalli/nvim-colorizer.lua',
            config = function()
                require('plugins/colorizer').setup()
            end,
        },
        {
            'lervag/vimtex',
            config = function()
                vim.g.tex_flavor = 'lualatex'
                vim.g.vimtex_compiler_method = 'latexrun'
                vim.g.vimtex_compiler_latexrun = {
                    build_dir = 'latex.out',
                    options = { '--verbose-cmds', '--latex-args="-synctex=1"' },
                }
            end,
        },
        'vim-pandoc/vim-pandoc',
        'vim-pandoc/vim-pandoc-syntax',
        {
            'nvim-treesitter/nvim-treesitter',
            branch = 'main',
            build = ':TSUpdate',
            config = function()
                require('plugins/treesitter').setup()
            end,
        },
        { 'nvim-treesitter/nvim-treesitter-context' },
        { 'nvim-treesitter/nvim-treesitter-textobjects' },
        {
            'ThePrimeagen/refactoring.nvim',
            dependencies = { 'lewis6991/async.nvim' },
        },

        -- Completion
        {
            'neovim/nvim-lspconfig',
            event = 'BufEnter',
            config = function()
                require('plugins/lsp').setup()
            end,
        },
        {
            'hrsh7th/nvim-cmp',
            dependencies = {
                'hrsh7th/cmp-vsnip',
                'hrsh7th/cmp-nvim-lsp',
                'hrsh7th/cmp-omni',
                'hrsh7th/cmp-buffer',
            },
            config = function()
                require('plugins/cmp').setup()
            end,
        },
        {
            'ray-x/lsp_signature.nvim',
            config = function()
                require('lsp_signature').setup {
                    bind = true,
                    handler_opts = { border = 'rounded' },
                    toggle_key = '<M-p>',
                }
            end,
        },
        'honza/vim-snippets',
        'hrsh7th/vim-vsnip',

        -- AI Completion
        {
            'cursortab/cursortab.nvim',
            build = 'cd server && go build',
            config = function()
                require('cursortab').setup {
                    provider = {
                        type = 'zeta-2',
                        url = 'http://localhost:7995',
                    },
                }
            end,
        },

        -- Colorschemes
        'folke/tokyonight.nvim',
    },
}
