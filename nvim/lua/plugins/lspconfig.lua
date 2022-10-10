local is_lspconfig_present, lspconfig = pcall(require, "lspconfig")
if not is_lspconfig_present then
    return
end

local borders = {
    {"╭", "FloatBorder"},
    {"─", "FloatBorder"},
    {"╮", "FloatBorder"},
    {"│", "FloatBorder"},
    {"╯", "FloatBorder"},
    {"─", "FloatBorder"},
    {"╰", "FloatBorder"},
    {"│", "FloatBorder"},
}

local function on_attach(client, bufnr)
    -- Set borders
    vim.lsp.handlers["textDocument/hover"] = vim.lsp.with(vim.lsp.handlers.hover, {border = borders})
    vim.lsp.handlers["textDocument/signatureHelp"] = vim.lsp.with(vim.lsp.handlers.hover, {border = borders})

    vim.api.nvim_buf_set_option(bufnr, "omnifunc", "v:lua.vim.lsp.omnifunc")

    local opts = {noremap = true, silent = true}

    local function buf_set_keymap(...)
        vim.api.nvim_buf_set_keymap(bufnr, ...)
    end

    -- Mappings.
    buf_set_keymap("n", "gD", "<cmd>lua vim.lsp.buf.declaration()<CR>", opts)
    buf_set_keymap("n", "gd", "<cmd>lua vim.lsp.buf.definition()<CR>", opts)
    buf_set_keymap("n", "gi", "<cmd>lua vim.lsp.buf.implementation()<CR>", opts)
    buf_set_keymap("n", "K", "<cmd>lua vim.lsp.buf.hover()<CR>", opts)
    buf_set_keymap("n", "<M-k>", "<cmd>lua vim.lsp.buf.signature_help()<CR>", opts)
    buf_set_keymap("n", "<M-CR>", "<cmd>lua vim.lsp.buf.code_action()<CR>", opts)
    buf_set_keymap("n", "<space>wa", "<cmd>lua vim.lsp.buf.add_workspace_folder()<CR>", opts)
    buf_set_keymap("n", "<space>wr", "<cmd>lua vim.lsp.buf.remove_workspace_folder()<CR>", opts)
    buf_set_keymap("n", "<space>wl", "<cmd>lua print(vim.inspect(vim.lsp.buf.list_workspace_folders()))<CR>", opts)
    buf_set_keymap("n", "<space>D", "<cmd>lua vim.lsp.buf.type_definition()<CR>", opts)
    buf_set_keymap("n", "<F2>", "<cmd>lua vim.lsp.buf.rename()<CR>", opts)
    buf_set_keymap("n", "gr", "<cmd>lua vim.lsp.buf.references()<CR>", opts)
    buf_set_keymap("n", "<space>e", "<cmd>lua vim.diagnostic.open_float({scope = \"line\"})<CR>", opts)
    buf_set_keymap("n", "[d", "<cmd>lua vim.diagnostic.goto_prev()<CR>", opts)
    buf_set_keymap("n", "]d", "<cmd>lua vim.diagnostic.goto_next()<CR>", opts)
    buf_set_keymap("n", "<space>q", "<cmd>lua vim.diagnostic.set_loclist()<CR>", opts)

    -- Set some keybinds conditional on server capabilities
    if client.server_capabilities.document_formatting then
        buf_set_keymap("n", "<space>cF", "<cmd>lua vim.lsp.buf.formatting()<CR>", opts)
    elseif client.server_capabilities.document_range_formatting then
        buf_set_keymap("n", "<space>cF", "<cmd>lua vim.lsp.buf.range_formatting()<CR>", opts)
    end


    require("lsp_signature").on_attach()
end

local capabilities = vim.lsp.protocol.make_client_capabilities()
capabilities.textDocument.completion.completionItem.snippetSupport = true
capabilities = require('cmp_nvim_lsp').update_capabilities(capabilities)

local function setup_servers()
    local servers = {"pyright", "rust_analyzer", "tsserver", "clangd", "hls"}
    for _, lsp in ipairs(servers) do
        lspconfig[lsp].setup {
            on_attach = on_attach,
            capabilities = capabilities,
            -- root_dir = vim.loop.cwd,
            -- flags = {
            --     debounce_text_changes = 150,
            -- }
        }
    end

    lspconfig.sumneko_lua.setup {
        on_attach = on_attach,
        capabilities = capabilities,
        cmd = { "lua-language-server" },
        settings = {
            Lua = {
                diagnostics = {
                    globals = { "vim" },
                },
                workspace = {
                    -- Make the server aware of Neovim runtime files
                    library = vim.api.nvim_get_runtime_file('', true),
                },
            },
        },
    }

    lspconfig.cssls.setup {
        on_attach = on_attach,
        capabilities = capabilities,
        cmd = {"vscode-css-languageserver", "--stdio"},
    }
end

setup_servers()
