local M = {}

function M.setup()
    local fzf_lua = require('fzf-lua')
    fzf_lua.setup {
        winopts = {
            backdrop = 80,
            preview = {
                layout = 'vertical',
                delay = 200,
            },
        },
        keymap = {
            builtin = {
                ['<M-f>'] = 'toggle-fullscreen',
                ['<M-k>'] = 'preview-up',
                ['<M-j>'] = 'preview-down',
                ['<M-u>'] = 'preview-page-up',
                ['<M-d>'] = 'preview-page-down',
                ['<M-p>'] = 'toggle-preview',
                ['<M-w>'] = 'toggle-preview-wrap',
                ['<M-r>'] = 'toggle-preview-cw',
                ['<M-S-r>'] = 'toggle-preview-ccw',
            },
        },
        grep = {
            multiline = 1,
        },
    }

    fzf_lua.register_ui_select()

    vim.keymap.set('n', '<Space>fr', function()
        require('fzf-lua').oldfiles {
            cwd_only = true,
            include_current_session = true,
        }
    end, { desc = 'Recent files' })

    vim.keymap.set('n', '<C-p>', function()
        require('fzf-lua').global()
    end, { desc = 'All files' })

    vim.keymap.set('n', '<Space>,', function()
        require('fzf-lua').buffers()
    end, { desc = 'Buffers' })

    vim.keymap.set('n', '<Space>fa', function()
        require('fzf-lua').builtin()
    end, { desc = 'FZF actions' })

    vim.keymap.set('n', '<Space>ff', function()
        require('fzf-lua').global()
    end, { desc = 'All files' })

    vim.keymap.set('n', '<Space>fh', function()
        require('fzf-lua').history()
    end, { desc = 'File history' })

    vim.keymap.set('n', '<Space>fz', function()
        require('fzf-lua').zoxide()
    end, { desc = 'Jump to dir' })

    vim.keymap.set('n', '<Space>fg', function()
        require('fzf-lua').grep_project()
    end, { desc = 'Grep project' })

    vim.keymap.set('v', '<Space>fg', function()
        require('fzf-lua').grep_visual()
    end, { desc = 'Grep selection' })

    vim.keymap.set('n', '<Space>f/', function()
        require('fzf-lua').blines()
    end, { desc = 'Buffer lines' })

    vim.keymap.set('n', '<Space>fl', function()
        require('fzf-lua').lines()
    end, { desc = 'Lines in all buffers' })

    vim.keymap.set('n', '<Space>f.', function()
        require('fzf-lua').resume()
    end, { desc = 'Repeat' })

    vim.keymap.set('n', '<Space>cc', function()
        require('fzf-lua').commands()
    end, { desc = 'Commands' })

    vim.keymap.set('n', '<Space>ch', function()
        require('fzf-lua').command_history()
    end, { desc = 'Command history' })

    vim.keymap.set('n', '<Space>cs', function()
        require('fzf-lua').lsp_live_workspace_symbols()
    end, { desc = 'Workspace symbols' })

    vim.keymap.set('n', '<Space>cr', function()
        require('fzf-lua').lsp_references()
    end, { desc = 'LSP references' })

    vim.keymap.set('n', '<Space>cR', function()
        require('fzf-lua').lsp_finder()
    end, { desc = 'LSP finder' })

    vim.keymap.set('n', '<Space>ci', function()
        require('fzf-lua').lsp_implementations()
    end, { desc = 'LSP implementations' })
end

return M
