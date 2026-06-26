--- @return number? bufnr The most recently focused file buffer in the current tab, if it exists
local function most_recent_tab_buffer()
    local buffers = vim.fn.getbufinfo { buflisted = 1 }

    table.sort(buffers, function(a, b)
        return a.lastused > b.lastused
    end)

    for i = 1, #buffers do
        local bufnr = buffers[i].bufnr
        local name = vim.api.nvim_buf_get_name(bufnr)
        local buftype =
            vim.api.nvim_get_option_value('buftype', { buf = bufnr })

        local is_real_file = buftype == ''
            and name ~= ''
            and vim.api.nvim_buf_is_loaded(bufnr)

        if is_real_file then
            return bufnr
        end
    end
end

--- @param win integer
--- @return boolean
local function is_nvimtree_window(win)
    local buf = vim.api.nvim_win_get_buf(win)
    local ft = vim.api.nvim_get_option_value('filetype', { buf = buf })
    return ft == 'NvimTree'
end

local function close_nontree_windows()
    local current = vim.api.nvim_get_current_win()
    for _, win in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
        if win ~= current then
            if not is_nvimtree_window(win) then
                vim.api.nvim_win_close(win, false)
            end
        end
    end
end

local M = {}

function M.setup()
    require('nvim-tree').setup {
        on_attach = function(bufnr)
            local api = require('nvim-tree.api')
            api.map.on_attach.default(bufnr)
            vim.keymap.set('n', 'go', function()
                local target_bufnr = most_recent_tab_buffer()
                api.tree.find_file {
                    buf = target_bufnr,
                    open = true,
                    focus = true,
                }
            end, {
                desc = 'Focus current file',
                buffer = bufnr,
                noremap = true,
            })
        end,
    }

    vim.keymap.set('n', '<Space>ft', function()
        require('nvim-tree.api').tree.open { find_file = true }
    end, { desc = 'File tree' })

    vim.keymap.set(
        'n',
        '<C-w>o',
        close_nontree_windows,
        { desc = 'Close other windows (keep nvim-tree)', remap = true }
    )
end

return M
