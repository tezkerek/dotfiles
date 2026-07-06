local M = {}

--- @alias Motion {forward: fun(), backward: fun()}
--- @type Motion?
local last_motion = nil
local last_was_forward = true

--- @param fwd_lhs string
---@param bwd_lhs string
---@param forward_fn fun()
---@param backward_fn fun()
---@param desc string
---@param opts table?
function M.map_motion(fwd_lhs, bwd_lhs, forward_fn, backward_fn, desc, opts)
    opts = opts or {}
    local fwd_opts = vim.tbl_extend('force', {
        desc = desc and ('Next ' .. desc) or nil,
        silent = true,
        noremap = true,
    }, opts)
    local bwd_opts = vim.tbl_extend('force', {
        desc = desc and ('Prev ' .. desc) or nil,
        silent = true,
        noremap = true,
    }, opts)

    vim.keymap.set('n', fwd_lhs, function()
        last_motion = { forward = forward_fn, backward = backward_fn }
        last_was_forward = true
        forward_fn()
    end, fwd_opts)

    vim.keymap.set('n', bwd_lhs, function()
        last_motion = { forward = forward_fn, backward = backward_fn }
        last_was_forward = false
        backward_fn()
    end, bwd_opts)
end

---@param forward boolean
---@param motion Motion?
---@param fallback string
local function move(forward, motion, fallback)
    if motion then
        if forward then
            motion.forward()
        else
            motion.backward()
        end
    else
        local cmd = vim.v.count > 0 and ('normal! ' .. vim.v.count .. fallback)
            or 'normal! ' .. fallback
        vim.cmd(cmd)
    end
end

function M.setup()
    vim.keymap.set('n', ';', function()
        move(last_was_forward, last_motion, ';')
    end, { desc = 'Repeat last motion' })

    vim.keymap.set('n', ',', function()
        move(not last_was_forward, last_motion, ',')
    end, { desc = 'Reverse repeat last motion' })

    local ns = vim.api.nvim_create_namespace('nvim-motions-clear')
    vim.on_key(function(key)
        if key == 'f' or key == 'F' or key == 't' or key == 'T' then
            last_motion = nil
        end
    end, ns)
end

return M
