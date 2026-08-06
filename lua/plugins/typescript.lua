-- typescript-language-server via native vim.lsp.config. Also checks plain
-- JavaScript: buildless frontends opt in with a jsconfig.json ("checkJs")
-- at the project root (e.g. air-app) — no build step, types stay dev-only.
-- Install: npm install -g --prefix ~/.local typescript typescript-language-server
-- (binaries land in ~/.local/bin: typescript-language-server, tsc)
vim.lsp.config("ts_ls", {
    cmd = { "typescript-language-server", "--stdio" },
    root_markers = {
        "jsconfig.json",
        "tsconfig.json",
        "package.json",
        ".git",
    },
    filetypes = {
        "javascript",
        "javascriptreact",
        "typescript",
        "typescriptreact",
    },
    capabilities = (function()
        local caps = vim.lsp.protocol.make_client_capabilities()
        local ok, cmp_lsp = pcall(require, "cmp_nvim_lsp")
        if ok then
            caps = vim.tbl_deep_extend("force", caps, cmp_lsp.default_capabilities())
        end
        return caps
    end)(),
})

vim.lsp.enable("ts_ls")

return {}
