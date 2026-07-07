local jj_utils = require('jj-utils')
local motion = require('motions')

local M = {}

function M.toggle_base()
    local actions = require('vcsigns.actions')
    local state_m = require('vcsigns.state')
    local bufnr = vim.api.nvim_get_current_buf()
    local repo_root = state_m.get(bufnr).vcs.vcs.root
    local rs = state_m.repo_get(repo_root)

    if rs.revset == 'prevb()' then
        rs.revset = nil
        rs.offset = 1
        require('vcsigns.updates').deep_update(bufnr, true)
        vim.notify('Diffing from HEAD~1', vim.log.levels.INFO)
    else
        actions.target_revset(0, 'prevb()')
        local desc, count = jj_utils.prevb_info()
        vim.notify(
            string.format('Diffing from %s (%d commits)', desc, count),
            vim.log.levels.INFO
        )
    end
end

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

    motion.map_motion(']c', '[c', function()
        require('vcsigns.actions').hunk_next(0, vim.v.count1)
    end, function()
        require('vcsigns.actions').hunk_prev(0, vim.v.count1)
    end, 'hunk')
    motion.map_motion(']C', '[C', function()
        require('vcsigns.actions').hunk_next(0, 9999)
    end, function()
        require('vcsigns.actions').hunk_prev(0, 9999)
    end, 'hunk extreme')

    map('n', '[r', function()
        require('vcsigns.actions').target_older_commit(0, vim.v.count1)
    end, 'Move diff target back')
    map('n', ']r', function()
        require('vcsigns.actions').target_newer_commit(0, vim.v.count1)
    end, 'Move diff target forward')
    map('n', '<Space>hr', function()
        require('vcsigns.actions').hunk_undo(0)
    end, 'Undo hunks under cursor')
    map('v', '<Space>hr', function()
        require('vcsigns.actions').hunk_undo(0)
    end, 'Undo hunks in range')
    map('n', '<Space>hp', function()
        require('vcsigns.actions').toggle_hunk_diff(0)
    end, 'Show hunk diffs inline in the current buffer')
    map('n', '<Space>hD', function()
        require('vcsigns.actions').diffview(0)
    end, 'Open native side-by-side diff view')
    map(
        'n',
        '<Space>hb',
        M.toggle_base,
        'Toggle diff target between prevb() and HEAD~1'
    )
    map('n', '<Space>hf', function()
        require('vcsigns.actions').toggle_fold(0)
    end, 'Fold outside hunks')
end

return M
