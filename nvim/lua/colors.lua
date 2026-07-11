local colors = require('tokyonight.colors')

---@return vim.api.keyset.win_config_ret
local function focusable_wins()
    return vim.tbl_filter(function(w)
        return vim.api.nvim_win_get_config(w).focusable
    end, vim.api.nvim_tabpage_list_wins(0))
end

---@param name string
---@param val vim.api.keyset.highlight
---@return nil
local function hl(name, val)
    return vim.api.nvim_set_hl(0, name, val)
end

local function hex2rgb(h)
    h = h:gsub('#', '')
    return tonumber(h:sub(1, 2), 16),
        tonumber(h:sub(3, 4), 16),
        tonumber(h:sub(5, 6), 16)
end

local function blend(fg, bg, alpha)
    local fr, fg_, fb = hex2rgb(fg)
    local br, bg_, bb = hex2rgb(bg)
    return string.format(
        '#%02x%02x%02x',
        math.floor(fr * alpha + br * (1 - alpha)),
        math.floor(fg_ * alpha + bg_ * (1 - alpha)),
        math.floor(fb * alpha + bb * (1 - alpha))
    )
end

local function create_window_hl_groups()
    local editor_bg = vim.api.nvim_get_hl(0, { name = 'Normal' }).bg
    local gray_fg = colors.styles.moon.comment

    hl('WinSeparator', { fg = gray_fg })
    hl('NvimTreeWinSeparator', { fg = gray_fg })
    hl('CursorLineNC', { underdotted = true, sp = gray_fg })
    hl('WinBorder', { link = 'Statusline' })
    hl('ActiveSignColumn', {
        bg = colors.styles.moon.bg_highlight,
        fg = colors.styles.moon.fg_gutter,
    })
    hl('IBLHiddenExtmark', {})
    hl('IBLHiddenText', { fg = editor_bg })
end

local IBL_INACTIVE =
    '@ibl.scope.char.1:IBLHiddenText,@ibl.scope.underline.1:IBLHiddenExtmark,@ibl.indent.char.1:IBLHiddenText,@ibl.whitespace.char.1:IBLHiddenText'
local WINBORDER_HL = 'WinSeparator:WinBorder,SignColumn:ActiveSignColumn'

local function setup_window_autocmds()
    local augroup =
        vim.api.nvim_create_augroup('config_curwin_border', { clear = true })

    --- @param event vim.api.keyset.events|vim.api.keyset.events[]
    --- @param callback fun()
    local function autocmd(event, callback)
        vim.api.nvim_create_autocmd(event, {
            group = augroup,
            callback = callback,
        })
    end

    autocmd({ 'VimEnter', 'WinEnter' }, function()
        vim.cmd('setlocal winhighlight-=CursorLine:CursorLineNC')
    end)

    autocmd('WinLeave', function()
        vim.cmd('setlocal winhighlight+=CursorLine:CursorLineNC')
        vim.cmd('setlocal winhighlight-=' .. WINBORDER_HL)
        vim.cmd('setlocal winhighlight+=' .. IBL_INACTIVE)
    end)

    autocmd('WinEnter', function()
        vim.cmd('setlocal winhighlight+=' .. WINBORDER_HL)
        vim.cmd('setlocal winhighlight-=' .. IBL_INACTIVE)
    end)

    -- No border highlights for a single window
    autocmd('WinResized', function()
        if #focusable_wins() == 1 then
            vim.cmd('setlocal winhighlight-=' .. WINBORDER_HL)
        end
    end)
end

local function setup_active_window_indicators()
    create_window_hl_groups()
    setup_window_autocmds()
end

local M = {}

function M.setup()
    vim.cmd('colorscheme tokyonight')

    hl('TreesitterContextBottom', {
        underline = true,
        sp = colors.styles.moon.blue,
    })

    hl('DiagnosticUnnecessary', {
        link = 'Underline',
    })

    hl('TabLine', {
        fg = colors.styles.moon.comment,
        bg = vim.api.nvim_get_hl(0, { name = 'TabLine' }).bg,
    })

    local subtle = 0.1
    hl(
        'DifftAdded',
        { bg = blend(colors.styles.moon.green, colors.styles.moon.bg, subtle) }
    )
    hl(
        'DifftRemoved',
        { bg = blend(colors.styles.moon.red, colors.styles.moon.bg, subtle) }
    )

    setup_active_window_indicators()
end

return M
