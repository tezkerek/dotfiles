local M = {}

function M.setup()
    require('nvim-treesitter').setup {}

    vim.api.nvim_create_autocmd('FileType', {
        pattern = {
            'lua',
            'vim',
            'python',
            'bash',
            'zsh',
            'haskell',
            'yaml',
            'toml',
            'css',
            'markdown',
            'kdl',
            'ron',
            'gitignore',
            'rust',
            'javascript',
            'typescript',
            'c',
            'cpp',
            'go',
        },
        callback = function()
            vim.treesitter.start()
            vim.wo.foldexpr = 'v:lua.vim.treesitter.foldexpr()'
            vim.wo.foldmethod = 'expr'
            vim.bo.indentexpr = "v:lua.require'nvim-treesitter'.indentexpr()"
        end,
    })

    require('treesitter-context').setup { multiwindow = true }

    require('nvim-treesitter-textobjects').setup {}
    local move = require('nvim-treesitter-textobjects.move')

    vim.keymap.set({ 'n', 'x', 'o' }, '[f', function()
        move.goto_previous_start('@function.outer', 'textobjects')
    end)
    vim.keymap.set({ 'n', 'x', 'o' }, ']f', function()
        move.goto_next_start('@function.outer', 'textobjects')
    end)
end

return M
