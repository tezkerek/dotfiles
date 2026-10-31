local motion = require('motions')

local M = {}

---@param filetype string
---@return string|nil
local function filetype_to_ts_lang(filetype)
    if filetype == '' then
        return
    end
    local lang = vim.treesitter.language.get_lang(filetype)
    if lang and lang:match('^[%w_]+$') then
        return lang
    end
end

---@param lang string
---@return boolean
local function is_parser_installed(lang)
    return #vim.api.nvim_get_runtime_file('parser/' .. lang .. '.*', false) > 0
end

---@type table<string, boolean>|nil
local available_parsers_cache

---@param lang string
---@return boolean
local function is_parser_available(lang)
    if not available_parsers_cache then
        available_parsers_cache = {}
        for _, l in ipairs(require('nvim-treesitter').get_available()) do
            available_parsers_cache[l] = true
        end
    end
    return available_parsers_cache[lang] == true
end

local warned = {}

---@param filetype string
---@param lang string
local function warn_missing_parser(filetype, lang)
    if warned[filetype] then
        return
    end
    warned[filetype] = true

    -- Look up parser asynchronously
    vim.schedule(function()
        if not is_parser_available(lang) then
            return
        end
        vim.notify(
            string.format(
                "No treesitter parser for '%s' (parser: %s). Run :TSInstall %s",
                filetype,
                lang,
                lang
            ),
            vim.log.levels.WARN
        )
    end)
end

--- Check that a parser is installed for `filetype`, warning if it is not.
---@param filetype string
---@return boolean
local function assert_parser_for_filetype(filetype)
    local lang = filetype_to_ts_lang(filetype)
    if not lang then
        return false
    end

    if is_parser_installed(lang) then
        return true
    end

    warn_missing_parser(filetype, lang)
    return false
end

function M.setup()
    require('nvim-treesitter').setup {}

    vim.api.nvim_create_autocmd('FileType', {
        pattern = '*',
        desc = 'Enable treesitter, warning about missing parsers',
        callback = function(args)
            -- Skip special buffers, like help
            if vim.bo[args.buf].buftype ~= '' then
                return
            end

            local filetype = vim.bo[args.buf].filetype
            if not assert_parser_for_filetype(filetype) then
                return
            end

            vim.treesitter.start(args.buf)
            vim.wo.foldexpr = 'v:lua.vim.treesitter.foldexpr()'
            vim.wo.foldmethod = 'expr'
            vim.bo.indentexpr = "v:lua.require'nvim-treesitter'.indentexpr()"
        end,
    })

    require('treesitter-context').setup { multiwindow = true }

    require('nvim-treesitter-textobjects').setup {}
    local move = require('nvim-treesitter-textobjects.move')

    vim.keymap.set({ 'x', 'o' }, '[f', function()
        move.goto_previous_start('@function.outer', 'textobjects')
    end)
    vim.keymap.set({ 'x', 'o' }, ']f', function()
        move.goto_next_start('@function.outer', 'textobjects')
    end)

    motion.map_motion(']f', '[f', function()
        move.goto_next_start('@function.outer', 'textobjects')
    end, function()
        move.goto_previous_start('@function.outer', 'textobjects')
    end, 'function start')
end

return M
