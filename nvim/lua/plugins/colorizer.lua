require('colorizer').setup()
local hl_utils = require('hl-utils')

local ns = vim.api.nvim_create_namespace('colorizer_bare')

local function highlight_all_hex_colors()
    local buf = vim.api.nvim_get_current_buf()
    vim.api.nvim_buf_clear_namespace(buf, ns, 0, -1)
    local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, true)
    for l, line in ipairs(lines) do
        local pos = 1
        while pos <= #line do
            local start = line:find('%f[%x]%x%x%x%x%x%x%f[^%x]', pos)
            if not start then
                break
            end
            local finish = start + 6
            local hex = line:sub(start, finish - 1):lower()
            pos = finish

            -- Skip matches already handled by the plugin
            local should_skip = start > 1
                and line:sub(start - 1, start - 1) == '#'
            if not should_skip then
                local hl_name = hl_utils.make_swatch_hl(hex, 'ColorBare')
                vim.hl.range(
                    buf,
                    ns,
                    hl_name,
                    { l - 1, start - 1 },
                    { l - 1, finish - 1 }
                )
            end
        end
    end
end

vim.api.nvim_create_user_command('Colorize', function()
    highlight_all_hex_colors()
    vim.api.nvim_create_autocmd(
        { 'TextChanged', 'TextChangedI', 'TextChangedP' },
        {
            buffer = 0,
            callback = highlight_all_hex_colors,
        }
    )
end, {})
