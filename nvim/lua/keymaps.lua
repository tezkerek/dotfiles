local set_opfunc = vim.fn[vim.api.nvim_exec2(
    [[
    func! s:set_opfunc(val)
        let &opfunc = a:val
    endfunc
    echon get(function('s:set_opfunc'), 'name')
    ]],
    { output = true }
).output]

local function is_empty_line(line)
    return vim.fn.getline(line):match('^%s*$')
end

local function select_indent_block(around)
    local line = vim.fn.line('.')
    local indent = vim.fn.indent(line)
    local last_line = vim.fn.line('$')

    if is_empty_line(line) then
        return
    end

    local start_line = line
    local end_line = line

    while start_line > 1 do
        local above_line = start_line - 1
        if is_empty_line(above_line) then
            break
        end
        if vim.fn.indent(above_line) < indent then
            if around then
                start_line = above_line
            end
            break
        end
        start_line = above_line
    end

    while end_line < last_line do
        local below_line = end_line + 1
        if is_empty_line(below_line) or vim.fn.indent(below_line) < indent then
            if around then
                end_line = below_line
            end
            break
        end
        end_line = below_line
    end

    vim.api.nvim_win_set_cursor(0, { start_line, 0 })
    vim.cmd('normal! V')
    vim.api.nvim_win_set_cursor(0, { end_line, 0 })
end

-- Mappings
local function select_indent_block_wrapper(around)
    return function()
        vim.cmd('normal! \27')
        select_indent_block(around)
    end
end
--- Dimisses various temporary popups, in sequence
--- @param window_id integer
local function is_dismissable_window(window_id)
    if vim.api.nvim_win_get_config(window_id).relative == '' then
        return false
    end
    return not (
        vim.w[window_id].treesitter_context
        or vim.w[window_id].treesitter_context_line_number
    )
end

local function sequential_dismiss()
    local dismissed = false
    for _, window_id in ipairs(vim.api.nvim_list_wins()) do
        if is_dismissable_window(window_id) then
            vim.api.nvim_win_close(window_id, false)
            dismissed = true
        end
    end

    if dismissed then
        return
    end

    vim.api.nvim_exec2('nohlsearch', {})
    vim.api.nvim_exec2('cclose', {})
end

local M = {}

function M.setup()
    vim.keymap.set(
        'x',
        'ig',
        select_indent_block_wrapper(false),
        { desc = 'inner indent group' }
    )
    vim.keymap.set(
        'x',
        'ag',
        select_indent_block_wrapper(true),
        { desc = 'indent group' }
    )
    vim.keymap.set(
        'o',
        'ig',
        ':<C-U>normal vig<CR>',
        { silent = true, desc = 'inner indent group' }
    )
    vim.keymap.set(
        'o',
        'ag',
        ':<C-U>normal vag<CR>',
        { silent = true, desc = 'indent group' }
    )

    vim.keymap.set('n', 'gs', function()
        set_opfunc(function()
            vim.cmd("'[,']sort")
        end)
        return 'g@'
    end, { expr = true, desc = 'Sort' })
    vim.keymap.set(
        'v',
        'gs',
        ":'<,'>sort<CR>",
        { silent = true, desc = 'Sort range' }
    )

    vim.keymap.set(
        'n',
        '<Esc>',
        sequential_dismiss,
        { desc = 'Close all floating windows', remap = false }
    )

    vim.keymap.set(
        { 'n', 'x' },
        'Y',
        '"+y',
        { desc = 'Yank to system clipboard' }
    )
    vim.keymap.set('o', 'Y', 'y', { desc = 'Linewise Y (YY)' })
end

return M
