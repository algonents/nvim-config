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

return {
    {
        -- Dummy spec so lazy.nvim picks up this file; clangd is configured above via native vim.lsp.config
        dir = ".",
        name = "cpp-keymaps",
        ft = { "c", "cpp", "objc", "objcpp" },
        config = function()
            vim.keymap.set("n", "<leader>ch", "<cmd>LspClangdSwitchSourceHeader<CR>", {
                desc = "Switch header/source",
                buffer = false,
            })
        end,
    },
}
