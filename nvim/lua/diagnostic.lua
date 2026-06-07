vim.diagnostic.config {
    underline = true,
    virtual_lines = false,
    virtual_text = false,
}

vim.keymap.set('n', '<Space>ld', function()
    local current = vim.diagnostic.config().virtual_text
    vim.diagnostic.config { virtual_text = not current }
end, { remap = false, desc = 'Toggle diagnostic virtual text' })

vim.keymap.set('n', '<Space>lD', function()
    local current = vim.diagnostic.config().virtual_lines
    vim.diagnostic.config { virtual_lines = not current }
end, { remap = false, desc = 'Toggle diagnostic virtual lines' })
