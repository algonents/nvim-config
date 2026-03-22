return {
    {
        "mrcjkb/rustaceanvim",
        version = "^6",
        ft = { "rust" },
        init = function()
            vim.g.rustaceanvim = {
                server = {
                    capabilities = (function()
                        local caps = vim.lsp.protocol.make_client_capabilities()
                        local ok, cmp_lsp = pcall(require, "cmp_nvim_lsp")
                        if ok then
                            caps = vim.tbl_deep_extend("force", caps, cmp_lsp.default_capabilities())
                        end
                        return caps
                    end)(),
                    default_settings = {
                        ["rust-analyzer"] = {
                            cargo = { allFeatures = true },
                            check = { command = "clippy" },
                        },
                    },
                },
                dap = {
                    adapter = {
                        type = "server",
                        port = "${port}",
                        executable = {
                            command = vim.fn.expand("~/.local/opt/codelldb/extension/adapter/codelldb"),
                            args = { "--port", "${port}" },
                        },
                    },
                },
            }
        end,
    },
}
