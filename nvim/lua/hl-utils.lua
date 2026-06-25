local M = {}

--- @param bg_hex string
--- @return string
local function compute_fg_on_bg(bg_hex)
    local r, g, b =
        tonumber(bg_hex:sub(1, 2), 16),
        tonumber(bg_hex:sub(3, 4), 16),
        tonumber(bg_hex:sub(5, 6), 16)
    return (r * 0.299 + g * 0.587 + b * 0.114 > 127) and '#000000' or '#ffffff'
end

---@param bg_hex string
---@param prefix string Prefix for the highlight group
---@return string
function M.make_swatch_hl(bg_hex, prefix)
    pcall(vim.api.nvim_set_hl, 0, prefix .. '_' .. bg_hex, {
        fg = compute_fg_on_bg(bg_hex),
        bg = '#' .. bg_hex,
    })
    return prefix .. '_' .. bg_hex
end

return M
