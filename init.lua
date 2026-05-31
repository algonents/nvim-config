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
vim.opt.wrap = true
vim.opt.linebreak = true
vim.opt.breakindent = true
vim.opt.signcolumn = "yes"

-- Arrow keys navigate by display line (wrapped rows)
vim.keymap.set({ "n", "v" }, "<Down>", "gj", { desc = "Down (display line)" })
vim.keymap.set({ "n", "v" }, "<Up>", "gk", { desc = "Up (display line)" })
vim.keymap.set({ "n", "v" }, "<Home>", "g<Home>", { desc = "Start of display line" })
vim.keymap.set({ "n", "v" }, "<End>", "g<End>", { desc = "End of display line" })
vim.keymap.set("i", "<Down>", "<C-o>gj", { desc = "Down (display line)" })
vim.keymap.set("i", "<Up>", "<C-o>gk", { desc = "Up (display line)" })
vim.keymap.set("i", "<Home>", "<C-o>g<Home>", { desc = "Start of display line" })
vim.keymap.set("i", "<End>", "<C-o>g<End>", { desc = "End of display line" })

-- Window navigation with Alt+arrows. Terminal mode escapes first so the
-- chord works from inside TUIs (Claude, lazygit) that capture <C-w>.
vim.keymap.set("n", "<A-Up>",    "<C-w><Up>",    { desc = "Window up" })
vim.keymap.set("n", "<A-Down>",  "<C-w><Down>",  { desc = "Window down" })
vim.keymap.set("n", "<A-Left>",  "<C-w><Left>",  { desc = "Window left" })
vim.keymap.set("n", "<A-Right>", "<C-w><Right>", { desc = "Window right" })
vim.keymap.set("t", "<A-Up>",    [[<C-\><C-n><C-w><Up>]],    { desc = "Window up" })
vim.keymap.set("t", "<A-Down>",  [[<C-\><C-n><C-w><Down>]],  { desc = "Window down" })
vim.keymap.set("t", "<A-Left>",  [[<C-\><C-n><C-w><Left>]],  { desc = "Window left" })
vim.keymap.set("t", "<A-Right>", [[<C-\><C-n><C-w><Right>]], { desc = "Window right" })

-- Clipboard
vim.opt.clipboard = "unnamedplus"

-- LSP keymaps
vim.keymap.set("n", "gd", vim.lsp.buf.definition, { desc = "Go to definition" })
vim.keymap.set("n", "K", vim.lsp.buf.hover, { desc = "Hover docs" })
vim.keymap.set("n", "<leader>fr", require("telescope.builtin").lsp_references, { desc = "Find references" })
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

-- Terminal: first one opens as a full-width bottom row (~25% height).
-- Additional ones split vertically next to it, forming a row of terminals.
vim.keymap.set("t", "<Esc>", [[<C-\><C-n>]], { desc = "Exit terminal mode" })

-- Auto-enter Terminal-Job mode when focusing any terminal buffer
vim.api.nvim_create_autocmd({ "BufEnter", "WinEnter" }, {
    pattern = "term://*",
    callback = function() vim.cmd("startinsert") end,
})

-- Claude sessions: first one opens as right vertical split (~30% width).
-- Additional ones stack vertically (horizontal splits) inside that right column.
local claude_bufs = {}
local function find_window_with_buf(buf)
    for _, win in ipairs(vim.api.nvim_list_wins()) do
        if vim.api.nvim_win_get_buf(win) == buf then return win end
    end
    return nil
end
local function find_any_claude_window()
    for _, buf in pairs(claude_bufs) do
        if vim.api.nvim_buf_is_valid(buf) then
            local win = find_window_with_buf(buf)
            if win then return win end
        end
    end
    return nil
end
local function toggle_claude(id)
    local buf = claude_bufs[id]
    if buf and vim.api.nvim_buf_is_valid(buf) then
        local win = find_window_with_buf(buf)
        if win then
            vim.api.nvim_win_close(win, false)
            return
        end
    end
    local other_claude_win = find_any_claude_window()
    if other_claude_win then
        vim.api.nvim_set_current_win(other_claude_win)
        vim.cmd("belowright split")
    else
        vim.cmd("botright vsplit")
        vim.cmd("vertical resize " .. math.floor(vim.o.columns * 0.3))
    end
    if buf and vim.api.nvim_buf_is_valid(buf) then
        vim.api.nvim_win_set_buf(0, buf)
    else
        vim.cmd("terminal claude")
        claude_bufs[id] = vim.api.nvim_get_current_buf()
        vim.keymap.set("t", "<Esc>", "<Esc>", {
            buffer = claude_bufs[id],
            desc = "Send Esc to Claude",
        })
    end
    vim.cmd("startinsert!")
end
vim.keymap.set("n", "<leader>c1", function() toggle_claude(1) end, { desc = "Toggle Claude 1" })
vim.keymap.set("n", "<leader>c2", function() toggle_claude(2) end, { desc = "Toggle Claude 2" })
vim.keymap.set("n", "<leader>c3", function() toggle_claude(3) end, { desc = "Toggle Claude 3" })

local term_bufs = {}
local function find_any_term_window()
    for _, buf in pairs(term_bufs) do
        if vim.api.nvim_buf_is_valid(buf) then
            local win = find_window_with_buf(buf)
            if win then return win end
        end
    end
    return nil
end
local function toggle_term(id)
    local buf = term_bufs[id]
    if buf and vim.api.nvim_buf_is_valid(buf) then
        local win = find_window_with_buf(buf)
        if win then
            vim.api.nvim_win_close(win, false)
            return
        end
    end
    local other_term_win = find_any_term_window()
    if other_term_win then
        vim.api.nvim_set_current_win(other_term_win)
        vim.cmd("rightbelow vsplit")
    else
        vim.cmd("botright split")
        vim.cmd("resize " .. math.floor(vim.o.lines * 0.25))
    end
    if buf and vim.api.nvim_buf_is_valid(buf) then
        vim.api.nvim_win_set_buf(0, buf)
    else
        vim.cmd("terminal")
        term_bufs[id] = vim.api.nvim_get_current_buf()
    end
    vim.cmd("startinsert!")
end
vim.keymap.set("n", "<leader>t1", function() toggle_term(1) end, { desc = "Toggle terminal 1" })
vim.keymap.set("n", "<leader>t2", function() toggle_term(2) end, { desc = "Toggle terminal 2" })
vim.keymap.set("n", "<leader>t3", function() toggle_term(3) end, { desc = "Toggle terminal 3" })

-- Tree map
vim.keymap.set("n", "<leader>n", ":Neotree filesystem reveal left toggle<CR>", { desc = "Workspace tree" })

-- Open current file in default external app (e.g. PNG → image viewer)
vim.keymap.set("n", "<leader>i", function()
    vim.ui.open(vim.fn.expand("%"))
end, { desc = "Open file externally" })

-- Debugger bindings
vim.keymap.set("n", "<leader>db", function()
    require("dap").toggle_breakpoint()
end, { desc = "Toggle breakpoint" })

vim.keymap.set("n", "<leader>dc", function()
    local dap = require("dap")
    if dap.session() then
        dap.continue()                                  -- resume a running session
    elseif vim.bo.filetype == "rust" then
        vim.cmd.RustLsp({ "debuggables", bang = true }) -- re-run last Rust target, no prompt
    else
        dap.continue()                                  -- C/C++ use dap.configurations
    end
end, { desc = "Debug continue / start" })

vim.keymap.set("n", "<leader>dr", function()
    vim.cmd.RustLsp("debuggables") -- picker: choose (or switch) Rust target
end, { desc = "Debug: pick Rust target" })

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

-- Trouble (diagnostics panel)
vim.keymap.set("n", "<leader>xx", "<cmd>Trouble diagnostics toggle<CR>", { desc = "Diagnostics (Trouble)" })
vim.keymap.set("n", "<leader>xd", "<cmd>Trouble diagnostics toggle filter.buf=0<CR>", { desc = "Buffer diagnostics (Trouble)" })

-- Gitsigns navigation
vim.keymap.set("n", "]h", function() require("gitsigns").nav_hunk("next") end, { desc = "Next git hunk" })
vim.keymap.set("n", "[h", function() require("gitsigns").nav_hunk("prev") end, { desc = "Previous git hunk" })

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
