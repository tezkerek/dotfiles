local M = {}

function M.setup()
    vim.opt.fillchars:append { stl = '─', stlnc = '─' }

    require('lualine').setup {
        options = { theme = 'auto', icons_enabled = true },
        sections = {
            lualine_b = {
                'filename',
            },
            lualine_c = {
                'branch',
                'diff',
                'diagnostics',
            },
            lualine_x = {
                'lsp_status',
                'encoding',
                'fileformat',
                'filetype',
            },
        },
        extensions = { 'fzf', 'fugitive', 'nvim-tree' },
    }
end

return M
