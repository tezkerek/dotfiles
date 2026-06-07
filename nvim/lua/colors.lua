local colors = require('tokyonight.colors')

vim.api.nvim_set_hl(0, 'TreesitterContextBottom', {
    underline = true,
    sp = colors.styles.moon.blue,
})

vim.api.nvim_set_hl(0, 'DiagnosticUnnecessary', {
    link = "Underline",
})

return {}
