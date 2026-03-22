-- Leader key
vim.g.mapleader = " "

-- Bootstrap lazy.nvim
local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not (vim.uv or vim.loop).fs_stat(lazypath) then
    vim.fn.system({
        "git", "clone", "--filter=blob:none", "--branch=stable",
        "https://github.com/folke/lazy.nvim.git",
        lazypath,
    })
end
vim.opt.rtp:prepend(lazypath)

-- Plugins (auto-imports lua/plugins/*.lua)
require("lazy").setup("plugins")

-- UI
vim.opt.number = true
vim.opt.relativenumber = true
vim.opt.termguicolors = true
vim.opt.expandtab = true
vim.opt.shiftwidth = 4
vim.opt.tabstop = 4
vim.opt.mouse = "a"
vim.opt.signcolumn = "yes"

-- Clipboard
vim.opt.clipboard = "unnamedplus"

-- LSP keymaps
vim.keymap.set("n", "gd", vim.lsp.buf.definition, { desc = "Go to definition" })
vim.keymap.set("n", "K", vim.lsp.buf.hover, { desc = "Hover docs" })
vim.keymap.set("n", "gr", vim.lsp.buf.references, { desc = "Find references" })
vim.keymap.set("n", "<leader>rn", vim.lsp.buf.rename, { desc = "Rename symbol" })
vim.keymap.set("n", "<leader>ca", vim.lsp.buf.code_action, { desc = "Code action" })

-- Diagnostics keymaps
vim.keymap.set("n", "[d", vim.diagnostic.goto_prev, { desc = "Previous diagnostic" })
vim.keymap.set("n", "]d", vim.diagnostic.goto_next, { desc = "Next diagnostic" })
vim.keymap.set("n", "<leader>e", vim.diagnostic.open_float, { desc = "Show diagnostic" })
vim.keymap.set("n", "<leader>q", vim.diagnostic.setloclist, { desc = "Diagnostics list" })

-- Telescope keymaps
local builtin = require("telescope.builtin")
vim.keymap.set("n", "<leader>ff", builtin.find_files, { desc = "Find files" })
vim.keymap.set("n", "<leader>fg", builtin.live_grep, { desc = "Find text" })
vim.keymap.set("n", "<leader>fb", builtin.buffers, { desc = "Find buffers" })
vim.keymap.set("n", "<leader>fh", builtin.help_tags, { desc = "Help tags" })

-- Terminal
vim.keymap.set("n", "<leader>t1", ":ToggleTerm 1<CR>")
vim.keymap.set("n", "<leader>t2", ":ToggleTerm 2<CR>")
vim.keymap.set("n", "<leader>t3", ":ToggleTerm 3<CR>")
vim.keymap.set("t", "<Esc>", [[<C-\><C-n>]], { desc = "Exit terminal mode" })

-- Tree map
vim.keymap.set("n", "<leader>n", ":Neotree filesystem reveal left toggle<CR>", { desc = "Workspace tree" })

-- Debugger bindings
vim.keymap.set("n", "<leader>db", function()
    require("dap").toggle_breakpoint()
end, { desc = "Toggle breakpoint" })

vim.keymap.set("n", "<leader>dc", function()
    require("dap").continue()
end, { desc = "Debug continue" })

vim.keymap.set("n", "<leader>do", function()
    require("dap").step_over()
end, { desc = "Debug step over" })

vim.keymap.set("n", "<leader>di", function()
    require("dap").step_into()
end, { desc = "Debug step into" })

vim.keymap.set("n", "<leader>dO", function()
    require("dap").step_out()
end, { desc = "Debug step out" })

vim.keymap.set("n", "<leader>du", function()
    require("dapui").toggle()
end, { desc = "Debug UI" })

vim.keymap.set("n", "<leader>dt", function()
    require("dap").terminate()
end, { desc = "Debug terminate" })

vim.keymap.set("n", "<leader>dw", function()
    local expr = vim.fn.input("Watch: ")
    if expr ~= "" then
        require("dapui").elements.watches.add(expr)
    end
end, { desc = "Add watch" })

-- Diagnostics display
vim.diagnostic.config({
    virtual_text = true,
    signs = true,
    underline = true,
    update_in_insert = false,
    severity_sort = true,
})

-- Format on save (Rust and C/C++)
vim.api.nvim_create_autocmd("BufWritePre", {
    pattern = { "*.rs", "*.c", "*.cpp", "*.h", "*.hpp" },
    callback = function()
        vim.lsp.buf.format({ async = false })
    end,
})

-- DAP signs (debugger icons in gutter)
vim.fn.sign_define("DapBreakpoint", {
    text = "●",
    texthl = "Error",
    linehl = "",
    numhl = "",
})

vim.fn.sign_define("DapBreakpointCondition", {
    text = "◆",
    texthl = "WarningMsg",
})

vim.fn.sign_define("DapLogPoint", {
    text = "▶",
    texthl = "Identifier",
})

vim.fn.sign_define("DapStopped", {
    text = "→",
    texthl = "String",
    linehl = "Visual",
    numhl = "",
})
