return {
    {
        "mfussenegger/nvim-dap",
        config = function()
            local dap = require("dap")

            -- codelldb adapter (shared by Rust via rustaceanvim and C/C++)
            dap.adapters.codelldb = {
                type = "server",
                port = "${port}",
                executable = {
                    command = vim.fn.expand("~/.local/opt/codelldb/extension/adapter/codelldb"),
                    args = { "--port", "${port}" },
                },
            }

            -- C/C++ debug configuration
            dap.configurations.c = {
                {
                    name = "Launch (codelldb)",
                    type = "codelldb",
                    request = "launch",
                    program = function()
                        return vim.fn.input("Executable: ", vim.fn.getcwd() .. "/build/", "file")
                    end,
                    cwd = "${workspaceFolder}",
                    stopOnEntry = false,
                },
            }
            dap.configurations.cpp = dap.configurations.c
        end,
    },
    {
        "rcarriga/nvim-dap-ui",
        dependencies = {
            "mfussenegger/nvim-dap",
            "nvim-neotest/nvim-nio",
        },
        config = function()
            local dap = require("dap")
            local dapui = require("dapui")

            dapui.setup({
                layouts = {
                    {
                        elements = {
                            { id = "scopes", size = 0.35 },
                            { id = "watches", size = 0.20 },
                            { id = "breakpoints", size = 0.20 },
                            { id = "stacks", size = 0.25 },
                        },
                        size = 40,
                        position = "right",
                    },
                    {
                        elements = {
                            { id = "repl", size = 1 },
                        },
                        size = 10,
                        position = "bottom",
                    },
                },
            })

            local function close_terminals()
                for _, win in ipairs(vim.api.nvim_list_wins()) do
                    local buf = vim.api.nvim_win_get_buf(win)
                    if vim.api.nvim_buf_is_valid(buf) and vim.bo[buf].buftype == "terminal" then
                        pcall(vim.api.nvim_win_close, win, false)
                    end
                end
            end
            dap.listeners.before.attach.dapui_config = function()
                close_terminals()
                dapui.open()
            end
            dap.listeners.before.launch.dapui_config = function()
                close_terminals()
                dapui.open()
            end
            dap.listeners.before.event_terminated.dapui_config = function()
                dapui.close()
            end
            dap.listeners.before.event_exited.dapui_config = function()
                dapui.close()
            end
        end,
    },
}
