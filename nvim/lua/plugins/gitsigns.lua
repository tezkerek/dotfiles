require("gitsigns").setup {
  on_attach = function(bufnr)
    local gitsigns = package.loaded.gitsigns

    local function map(mode, lhs, rhs, opts)
      opts = opts or {}
      opts.buffer = bufnr
      vim.keymap.set(mode, lhs, rhs, opts)
    end

    map('n', ']c', function()
      if vim.wo.diff then return ']c' end
      vim.schedule(function() gitsigns.next_hunk() end)
      return '<Ignore>'
    end, {expr=true})

    map('n', '[c', function()
      if vim.wo.diff then return '[c' end
      vim.schedule(function() gitsigns.prev_hunk() end)
      return '<Ignore>'
    end, {expr=true})

    map('n', '<leader>hp', gitsigns.preview_hunk)
    map({'o', 'x'}, 'ih', gitsigns.select_hunk)
  end
}
