local function global_on_attach(client, bufnr)
    local function map(modes, lhs, rhs, desc)
        vim.keymap.set(modes, lhs, rhs, {
            silent = true,
            buf = bufnr,
            desc = desc,
        })
    end
    map('n', 'gD', vim.lsp.buf.declaration, 'Go to declaration')
    map('n', 'gd', vim.lsp.buf.definition, 'Go to definition')
    map({ 'n', 'i' }, '<M-k>', vim.lsp.buf.signature_help, 'Show signature')
    map('n', '<M-CR>', vim.lsp.buf.code_action, 'Code action')
    map('n', '<F2>', vim.lsp.buf.rename, 'Rename')

    map('n', '<space>e', vim.diagnostic.open_float, 'Show diagnostic')
    map('n', '[d', function()
        vim.diagnostic.jump { count = -1 }
    end, 'Prev diagnostic')
    map('n', ']d', function()
        vim.diagnostic.jump { count = 1 }
    end, 'Next diagnostic')
    map('n', '<space>lq', vim.diagnostic.setloclist, 'Diagnostics in qf')

    map('n', '<Space>lwa', vim.lsp.buf.add_workspace_folder, 'Add workspace')
    map(
        'n',
        '<Space>lwr',
        vim.lsp.buf.remove_workspace_folder,
        'Remove workspace'
    )
    map('n', '<Space>lwl', function()
        print(vim.inspect(vim.lsp.buf.list_workspace_folders()))
    end, 'List workspaces')

    if client.server_capabilities.documentFormattingProvider then
        map('n', '<space>cF', function()
            vim.lsp.buf.format { async = true }
        end, 'Format')
    elseif client.server_capabilities.documentRangeFormattingProvider then
        map('n', '<space>cF', vim.lsp.buf.range_formatting, 'Format')
    end

    require('lsp_signature').on_attach()
end

local capabilities = require('cmp_nvim_lsp').default_capabilities()

vim.api.nvim_create_autocmd('LspAttach', {
    callback = function(args)
        local client = vim.lsp.get_client_by_id(args.data.client_id)
        global_on_attach(client, args.buf)
    end,
})

vim.lsp.config('*', { capabilities = capabilities })

vim.lsp.config('lua_ls', {
    settings = {
        Lua = {
            runtime = {
                version = 'LuaJIT',
                path = { 'lua/?.lua', 'lua/?/init.lua' },
            },
            diagnostics = { globals = { 'vim' } },
            workspace = {
                checkThirdParty = false,
                library = { vim.env.VIMRUNTIME },
            },
        },
    },
})

vim.lsp.config('cssls', { cmd = { 'vscode-css-languageserver', '--stdio' } })

local servers = {
    'pyright',
    'rust_analyzer',
    'ts_ls',
    'clangd',
    'hls',
    'lua_ls',
    'cssls',
}
for _, lsp in ipairs(servers) do
    vim.lsp.enable(lsp)
end
