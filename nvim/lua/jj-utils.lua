local M = {}

function M.prevb_info()
    local desc = vim.fn.system(
        "jj log --no-graph -r 'prevb()' -T 'bookmarks.map(|b| b.name()).join(\" \")' --color=never 2>/dev/null"
    )
    desc = vim.trim(desc)
    if desc == '' then
        desc = vim.fn.system(
            "jj log --no-graph -r 'prevb()' -T 'change_id.shortest(8)' --color=never 2>/dev/null"
        )
        desc = vim.trim(desc)
    end
    local count = vim.fn.system(
        "jj log --no-graph -r 'prevb()..@' -T '\"\\n\"' 2>/dev/null | wc -l"
    )
    count = tonumber(vim.trim(count)) or 0
    return desc, count
end

return M
