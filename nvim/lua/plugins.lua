local install_path = vim.fn.stdpath('data')
    .. '/site/pack/packer/start/packer.nvim'

if vim.fn.empty(vim.fn.glob(install_path)) > 0 then
    vim.api.nvim_command(
        '!git clone https://github.com/wbthomason/packer.nvim ' .. install_path
    )
    vim.api.nvim_command('packadd packer.nvim')
end

vim.cmd([[packadd packer.nvim]])

local packer = require('packer')

packer.init { max_jobs = 16 }

return packer.startup(function(use)
    use('wbthomason/packer.nvim')

    -- QOL
    use {
        'nvim-lualine/lualine.nvim',
        requires = 'kyazdani42/nvim-web-devicons',
        config = function()
            vim.opt.fillchars:append { stl = '─', stlnc = '─' }

            require('lualine').setup {
                options = { theme = 'auto', icons_enabled = true },
                sections = {
                    lualine_x = {
                        'lsp_status',
                        'encoding',
                        'fileformat',
                        'filetype',
                    },
                },
                extensions = { 'fzf', 'fugitive', 'nvim-tree' },
            }
        end,
    }
    use('mhinz/vim-startify')
    use('moll/vim-bbye')
    use('embear/vim-localvimrc')
    use {
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
    }
    use {
        'lukas-reineke/indent-blankline.nvim',
        config = function()
            require('ibl').setup {
                exclude = { filetypes = { 'NvimTree', 'help', 'startify' } },
            }
        end,
    }

    -- Integration
    use('christoomey/vim-tmux-navigator')
    use('tpope/vim-fugitive')
    use {
        'lewis6991/gitsigns.nvim',
        config = function()
            require('plugins/gitsigns').setup()
        end,
    }
    use {
        'NicolasGB/jj.nvim',
        config = function()
            require('jj').setup {}
        end,
    }
    use {
        'glacambre/firenvim',
        run = function()
            vim.fn['firenvim#install'](0)
        end,
    }

    -- Text editing
    use('justinmk/vim-sneak')
    use('tpope/vim-surround')
    use('wellle/targets.vim')
    use('tpope/vim-characterize')
    use('tpope/vim-repeat')
    use('tpope/vim-commentary')
    use('luochen1990/rainbow')
    use('junegunn/vim-easy-align')
    use('tommcdo/vim-exchange')
    use('dhruvasagar/vim-table-mode')
    use {
        'Julian/vim-textobj-variable-segment',
        requires = 'kana/vim-textobj-user',
    }
    use {
        'windwp/nvim-autopairs',
        after = { 'nvim-cmp' },
        config = function()
            require('nvim-autopairs').setup()
        end,
    }

    -- Files
    use {
        'kyazdani42/nvim-tree.lua',
        config = function()
            require('plugins/nvim-tree').setup()
        end,
    }
    use {
        'ibhagwan/fzf-lua',
        requires = { 'nvim-tree/nvim-web-devicons' },
        config = function()
            require('plugins/fzf-lua').setup()
        end,
    }
    use('tpope/vim-eunuch')

    -- Syntax
    use('tpope/vim-sleuth')
    use('AndrewRadev/splitjoin.vim')
    use('pechorin/any-jump.vim')
    use('sbdchd/neoformat')
    use {
        'norcalli/nvim-colorizer.lua',
        config = function()
            require('plugins/colorizer').setup()
        end,
    }
    use {
        'lervag/vimtex',
        config = function()
            vim.g.tex_flavor = 'lualatex'
            vim.g.vimtex_compiler_method = 'latexrun'
            vim.g.vimtex_compiler_latexrun = {
                build_dir = 'latex.out',
                options = { '--verbose-cmds', '--latex-args="-synctex=1"' },
            }
        end,
    }
    use('vim-pandoc/vim-pandoc')
    use('vim-pandoc/vim-pandoc-syntax')
    use {
        'nvim-treesitter/nvim-treesitter',
        branch = 'main',
        run = ':TSUpdate',
        config = function()
            require('plugins/treesitter').setup()
        end,
    }
    use { 'nvim-treesitter/nvim-treesitter-context' }
    use { 'nvim-treesitter/nvim-treesitter-textobjects' }

    -- Completion
    use {
        'neovim/nvim-lspconfig',
        event = 'BufEnter',
        config = function()
            require('plugins/lsp').setup()
        end,
    }
    use {
        'hrsh7th/nvim-cmp',
        requires = {
            'hrsh7th/cmp-vsnip',
            'hrsh7th/cmp-nvim-lsp',
            'hrsh7th/cmp-omni',
            'hrsh7th/cmp-buffer',
        },
        after = { 'vimtex' },
        config = function()
            require('plugins/cmp').setup()
        end,
    }
    use {
        'ray-x/lsp_signature.nvim',
        config = function()
            require('lsp_signature').setup {
                bind = true,
                handler_opts = { border = 'rounded' },
                toggle_key = '<M-p>',
            }
        end,
    }
    use('honza/vim-snippets')
    use('hrsh7th/vim-vsnip')

    -- AI Completion
    use {
        'cursortab/cursortab.nvim',
        run = 'cd server && go build',
        config = function()
            require('cursortab').setup {
                provider = {
                    type = 'zeta-2',
                    url = 'http://localhost:7995',
                },
            }
        end,
    }

    -- Colorschemes
    use('folke/tokyonight.nvim')
end)
