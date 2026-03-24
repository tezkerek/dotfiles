local colors = require('tokyonight.colors')

vim.api.nvim_set_hl(0, 'TreesitterContextBottom', {
    underline = true,
    sp = colors.styles.moon.blue
})

return {}
