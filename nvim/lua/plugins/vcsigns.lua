local M = {}

function M.setup()
    require('vcsigns').setup {
        diffview_editable_side = 'right',
        target_commit = 1,
        signs = {
            text = {
                add = '┃',
                change = '┃',
                delete_below = '▁',
                delete_above = '▔',
                delete_above_below = '▁',
            },
        },
    }

    local function map(mode, lhs, rhs, desc, opts)
        local options = { noremap = true, silent = true, desc = desc }
        if opts then
            options = vim.tbl_extend('force', options, opts)
        end
        vim.keymap.set(mode, lhs, rhs, options)
    end

    map('n', '[r', function()
        require('vcsigns.actions').target_older_commit(0, vim.v.count1)
    end, 'Move diff target back')
    map('n', ']r', function()
        require('vcsigns.actions').target_newer_commit(0, vim.v.count1)
    end, 'Move diff target forward')
    map('n', '[c', function()
        require('vcsigns.actions').hunk_prev(0, vim.v.count1)
    end, 'Go to previous hunk')
    map('n', ']c', function()
        require('vcsigns.actions').hunk_next(0, vim.v.count1)
    end, 'Go to next hunk')
    map('n', '[C', function()
        require('vcsigns.actions').hunk_prev(0, 9999)
    end, 'Go to first hunk')
    map('n', ']C', function()
        require('vcsigns.actions').hunk_next(0, 9999)
    end, 'Go to last hunk')
    map('n', '<Space>hr', function()
        require('vcsigns.actions').hunk_undo(0)
    end, 'Undo hunks under cursor')
    map('v', '<Space>hr', function()
        require('vcsigns.actions').hunk_undo(0)
    end, 'Undo hunks in range')
    map('n', '<Space>hp', function()
        require('vcsigns.actions').toggle_hunk_diff(0)
    end, 'Show hunk diffs inline in the current buffer')
    map('n', '<Space>hd', function()
        require('vcsigns.actions').diffview(0)
    end, 'Open native side-by-side diff view')
    map('n', '<Space>hf', function()
        require('vcsigns.actions').toggle_fold(0)
    end, 'Fold outside hunks')
end

return M
