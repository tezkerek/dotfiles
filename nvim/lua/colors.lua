local colors = require('tokyonight.colors')

local M = {}

function M.setup()
    vim.api.nvim_set_hl(0, 'TreesitterContextBottom', {
        underline = true,
        sp = colors.styles.moon.blue,
    })

    vim.api.nvim_set_hl(0, 'DiagnosticUnnecessary', {
        link = 'Underline',
    })
end

return M
