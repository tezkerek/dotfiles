local dotter = require('dotter')
local hl_utils = require('hl-utils')
local M = {}

--- @return string?
local function find_dotfiles_root()
    local filepath = vim.api.nvim_buf_get_name(vim.api.nvim_get_current_buf())
    if filepath == '' then
        return
    end
    return dotter.find_root_dir(vim.fn.fnamemodify(filepath, ':h'))
end

---@param buf integer
---@param ns integer
---@param lnum integer
---@param start integer 1-based inclusive
---@param finish integer 1-based exclusive
---@param hex string
local function apply_color_template_hl(buf, ns, lnum, start, finish, hex)
    local hl_name = hl_utils.make_swatch_hl(hex, 'DotfilesColor')
    vim.hl.range(buf, ns, hl_name, { lnum, start - 1 }, { lnum, finish - 1 })
end

---@param buf integer
---@param ns integer
---@param lnum integer
---@param start integer 1-based inclusive
---@param finish integer 1-based exclusive
local function apply_generic_template_hl(buf, ns, lnum, start, finish)
    vim.hl.range(
        buf,
        ns,
        'DotfilesTemplate',
        { lnum, start - 1 },
        { lnum, finish - 1 }
    )
end

--- @param buf integer
--- @param colors table<string,string>
--- @param ns integer
local function apply_highlights(buf, colors, ns)
    vim.api.nvim_buf_clear_namespace(buf, ns, 0, -1)
    local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, true)

    for l, line in ipairs(lines) do
        for start, finish, template in dotter.find_template_matches(line) do
            local color_name = template:match('^colors%.([%w_%-]+)$')
            local color_start = start + 7
            if color_name and colors[color_name] then
                apply_color_template_hl(
                    buf,
                    ns,
                    l - 1,
                    color_start,
                    finish,
                    colors[color_name]
                )
            else
                apply_generic_template_hl(buf, ns, l - 1, start, finish)
            end
        end
    end
end

function M.setup()
    local ns = vim.api.nvim_create_namespace('dotfiles_templates')
    vim.api.nvim_set_hl(0, 'DotfilesTemplate', { link = 'Special' })

    vim.api.nvim_create_autocmd({ 'BufRead', 'BufNewFile' }, {
        callback = function()
            local root = find_dotfiles_root()
            if not root then
                return
            end

            dotter.load_colors_async(root, function(dotter_colors)
                local buf = vim.api.nvim_get_current_buf()
                vim.b[buf].dotfiles_colormap = dotter_colors
                apply_highlights(buf, dotter_colors, ns)
            end)
        end,
    })

    vim.api.nvim_create_autocmd(
        { 'TextChanged', 'TextChangedI', 'TextChangedP' },
        {
            callback = function()
                if vim.b.dotfiles_colormap then
                    apply_highlights(0, vim.b.dotfiles_colormap, ns)
                end
            end,
        }
    )
end

return M
