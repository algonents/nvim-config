vim.lsp.config("clangd", {
    cmd = {
        "clangd",
        "--background-index",
        "--clang-tidy",
        "--compile-commands-dir=build",
    },
    root_markers = { "compile_commands.json", ".clangd", "CMakeLists.txt", ".git" },
    filetypes = { "c", "cpp", "objc", "objcpp" },
    capabilities = (function()
        local caps = vim.lsp.protocol.make_client_capabilities()
        local ok, cmp_lsp = pcall(require, "cmp_nvim_lsp")
        if ok then
            caps = vim.tbl_deep_extend("force", caps, cmp_lsp.default_capabilities())
        end
        return caps
    end)(),
})

vim.lsp.enable("clangd")

return {}
