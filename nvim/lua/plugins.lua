local install_path = vim.fn.stdpath('data') .. '/site/pack/packer/start/packer.nvim'

if vim.fn.empty(vim.fn.glob(install_path)) > 0 then
    vim.api.nvim_command('!git clone https://github.com/wbthomason/packer.nvim ' .. install_path)
    vim.api.nvim_command 'packadd packer.nvim'
end

vim.cmd [[packadd packer.nvim]]

return require('packer').startup(function(use)
    use 'wbthomason/packer.nvim'

    -- QOL
    use {
        'hoob3rt/lualine.nvim',
        requires = 'kyazdani42/nvim-web-devicons',
        config = function()
            require('lualine').setup {
                options = {
                    theme = 'tokyonight',
                    icons_enabled = true,
                },
                extensions = {'fzf', 'fugitive', 'nerdtree'}
            }
        end
    }
    use 'mhinz/vim-startify'
    use 'moll/vim-bbye'
    use 'embear/vim-localvimrc'
    use 'liuchengxu/vim-which-key'
    use {
        'lukas-reineke/indent-blankline.nvim',
        config = function()
            vim.g.indent_blankline_filetype_exclude = {"NvimTree", "help"}
        end
    }


    -- Integration
    use 'christoomey/vim-tmux-navigator'
    use 'tpope/vim-fugitive'
    use 'nvim-lua/plenary.nvim'
    use {
        'lewis6991/gitsigns.nvim',
        requires = 'nvim-lua/plenary.nvim',
        config = function ()
            require('gitsigns').setup()
        end
    }
    use {
        'glacambre/firenvim',
        run = function() vim.fn['firenvim#install'](0) end
    }

    -- Text editing
    use 'justinmk/vim-sneak'
    use 'tpope/vim-surround'
    use 'wellle/targets.vim'
    use 'tpope/vim-characterize'
    use 'tpope/vim-repeat'
    use 'tpope/vim-commentary'
    use 'luochen1990/rainbow'
    use 'junegunn/vim-easy-align'
    use 'tommcdo/vim-exchange'
    use 'dhruvasagar/vim-table-mode'
    use 'kana/vim-textobj-user'
    use 'Julian/vim-textobj-variable-segment'
    use {
        'windwp/nvim-autopairs',
        config = function()
            require('nvim-autopairs').setup()
            require('nvim-autopairs.completion.compe').setup({
                    map_cr = true,
                    map_complete = true
                })
        end
    }

    -- Files
    use 'preservim/nerdtree'
    use 'kyazdani42/nvim-tree.lua'
    use 'junegunn/fzf'
    use 'junegunn/fzf.vim'
    use 'tpope/vim-eunuch'

    -- Completion
    use {
        'neovim/nvim-lspconfig',
        event = "BufEnter",
        config = function() require("plugins/lspconfig") end
    }
    use {
        'hrsh7th/nvim-compe',
        config = function() require("plugins/compe") end
    }
    use 'ray-x/lsp_signature.nvim'
    use 'honza/vim-snippets'
    use 'hrsh7th/vim-vsnip'

    -- Syntax
    use 'vim-scripts/taglist.vim'
    use 'AndrewRadev/splitjoin.vim'
    use 'pechorin/any-jump.vim'
    use 'sbdchd/neoformat'
    use 'ap/vim-css-color'
    use 'lervag/vimtex'
    use 'vim-pandoc/vim-pandoc'
    use 'vim-pandoc/vim-pandoc-syntax'
    use 'OmniSharp/omnisharp-vim'
    use 'sheerun/vim-polyglot'
    use {
        'nvim-treesitter/nvim-treesitter',
        run = ':TSUpdate',
        config = function ()
            require('nvim-treesitter.configs').setup {
                highlight = {enable = true},
                indent = {enable = true}
            }
        end
    }

    -- Colorschemes
    use 'gruvbox-community/gruvbox'
    use 'sainnhe/gruvbox-material'
    use 'navarasu/onedark.nvim'
    use 'folke/tokyonight.nvim'
end)
