local function global_on_attach(client, bufnr)
    vim.bo[bufnr].omnifunc = 'v:lua.vim.lsp.omnifunc'

    local opts = {noremap = true, silent = true}
    vim.keymap.set('n', 'gD', vim.lsp.buf.declaration, opts)
    vim.keymap.set('n', 'gd', vim.lsp.buf.definition, opts)
    vim.keymap.set('n', 'gi', vim.lsp.buf.implementation, opts)
    vim.keymap.set('n', 'K', vim.lsp.buf.hover, opts)
    vim.keymap.set('n', '<M-k>', vim.lsp.buf.signature_help, opts)
    vim.keymap.set('n', '<M-CR>', vim.lsp.buf.code_action, opts)
    vim.keymap.set('n', '<space>wa', vim.lsp.buf.add_workspace_folder, opts)
    vim.keymap.set('n', '<space>wr', vim.lsp.buf.remove_workspace_folder, opts)
    vim.keymap.set('n', '<space>wl', function()
        print(vim.inspect(vim.lsp.buf.list_workspace_folders()))
    end, opts)
    vim.keymap.set('n', '<space>D', vim.lsp.buf.type_definition, opts)
    vim.keymap.set('n', '<F2>', vim.lsp.buf.rename, opts)
    vim.keymap.set('n', 'gr', vim.lsp.buf.references, opts)
    vim.keymap.set('n', '<space>e', vim.diagnostic.open_float, opts)
    vim.keymap.set('n', '[d', function() vim.diagnostic.jump({count = -1}) end,
                   opts)
    vim.keymap.set('n', ']d', function() vim.diagnostic.jump(({count = 1})) end,
                   opts)
    vim.keymap.set('n', '<space>q', vim.diagnostic.setloclist, opts)

    if client.server_capabilities.documentFormattingProvider then
        vim.keymap.set('n', '<space>cF',
                       function() vim.lsp.buf.format({async = true}) end, opts)
    elseif client.server_capabilities.documentRangeFormattingProvider then
        vim.keymap.set('n', '<space>cF', vim.lsp.buf.range_formatting, opts)
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

vim.lsp.config('*', {capabilities = capabilities})

vim.lsp.config('lua_ls', {
    settings = {
        Lua = {
            runtime = {
                version = 'LuaJIT',
                path = {'lua/?.lua', 'lua/?/init.lua'},
            },
            diagnostics = {globals = {'vim'}},
            workspace = {
                checkThirdParty = false,
                library = {vim.env.VIMRUNTIME},
            },
        },
    },
})

vim.lsp.config('cssls', {cmd = {'vscode-css-languageserver', '--stdio'}})

local servers = {
    'pyright',
    'rust_analyzer',
    'ts_ls',
    'clangd',
    'hls',
    'lua_ls',
    'cssls',
}
for _, lsp in ipairs(servers) do vim.lsp.enable(lsp) end
