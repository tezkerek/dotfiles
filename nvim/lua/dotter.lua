local M = {}

--- @param start string
--- @return string?
function M.find_root_dir(start)
    local dir = start
    while dir do
        local target_path = vim.fs.joinpath(dir, '.dotter', 'global.toml')
        if vim.fn.filereadable(target_path) == 1 then
            return dir
        end
        local parent = vim.fn.fnamemodify(dir, ':h')
        if parent == dir then
            break
        end
        dir = parent
    end
    return nil
end

--- @param content string
--- @param section string
--- @return fun(): string?, string?
local function find_section(content, section)
    local lines = vim.split(content, '\n')
    local i = 1
    local header = '[' .. section .. ']'
    -- skip to section header
    while i <= #lines and not vim.startswith(lines[i], header) do
        i = i + 1
    end
    -- move past the header line
    i = i + 1
    return function()
        while i <= #lines do
            local line = lines[i]
            i = i + 1
            if vim.startswith(line, '[') then
                -- start of new section
                return nil
            end
            local name, val = line:match('^%s*([%w_%-]+)%s*=%s*"([^"]+)"')
            if name and val then
                return name, val
            end
        end
        return nil
    end
end

--- @param root string
--- @param callback fun(colors: table<string,string>)
function M.load_colors_async(root, callback)
    local filepath = vim.fs.joinpath(root, '.dotter', 'global.toml')
    vim.uv.fs_open(filepath, 'r', 438, function(open_err, fd)
        if open_err or not fd then
            return
        end
        vim.uv.fs_read(fd, 65536, 0, function(read_err, data)
            vim.uv.fs_close(fd)
            if read_err or not data then
                return
            end
            local colors = {}
            for k, v in find_section(data, 'colors.variables.colors') do
                colors[k] = v
            end
            vim.schedule(function()
                callback(colors)
            end)
        end)
    end)
end

---@param line string
---@return fun(): integer?, integer?, string?
function M.find_template_matches(line)
    local iter_pos = 1
    return function()
        while iter_pos <= #line do
            local open_pos = line:find('{{', iter_pos)
            if not open_pos then
                return nil
            end
            local close_pos = line:find('}}', open_pos + 2)
            if not close_pos then
                return nil
            end
            local start = open_pos + 2
            local finish = close_pos
            local inner = line:sub(start, finish - 1)
            iter_pos = finish + 2
            return start, finish, inner
        end
    end
end

return M
