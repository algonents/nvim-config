-- Run: env -u NVIM nvim --clean --headless -u NONE --cmd "set rtp^=." -S tests/claude_panel.lua
-- Opens slot 1 with a stub program that emits the OSC 7501 probe and a
-- report, then checks status, winbar/indicator rendering, mention
-- formatting and the TermClose path.
-- Exits 0 on success, 1 on the first failed assertion (never hangs).
local ok, err = pcall(function()
vim.g.mapleader = " "
local claude = require("claude")
claude.setup({ hooks = { dir = vim.fn.tempname() } })
local panel, status, ui, mention = require("claude.panel"), require("claude.status"), require("claude.ui"), require("claude.mention")

local function check(cond, msg)
    if not cond then
        error("claude_panel: " .. msg)
    end
end

local title = vim.base64.encode("Refactoring panel.lua")
local script = table.concat({
    "printf '\\033]7501;?\\033\\\\'",
    "printf '\\033[c'",
    "sleep 0.3",
    "printf '\\033]7501;state=working:title=" .. title .. ":app=claude-code\\033\\\\'",
    "sleep 0.3",
    "printf '\\033]7501;state=blocked:kind=permission:app=claude-code\\033\\\\'",
    -- read back what the terminal answered to the probe
    "ans=''; while IFS= read -r -t 0.5 -n 1 ch; do ans=\"$ans$ch\"; done",
    "case \"$ans\" in *7501*states=*) printf 'CAPS_OK' ;; *) printf 'CAPS_MISSING' ;; esac",
    "sleep 0.3",
    "printf '\\033]7501;state=clear\\033\\\\'",
    "exit 3",
}, "; ")

local edit_win = vim.api.nvim_get_current_win()
local buf = panel.open(1, { cmd = { "sh", "-c", script }, focus = false })
check(buf and vim.b[buf].claude_slot == 1, "slot var set")
check(panel.live(1), "slot 1 live")
check(panel.is_claude_buf(buf), "is_claude_buf")
check(vim.api.nvim_win_get_width(panel.win_of(buf)) <= math.floor(vim.o.columns * 0.3) + 1, "30% column")
local wb = vim.api.nvim_get_option_value("winbar", { win = panel.win_of(buf) })
check(wb:find("claude.ui", 1, true) ~= nil, "winbar attached: " .. wb)

local events = {}
vim.api.nvim_create_autocmd("User", { pattern = "ClaudeStatus", callback = function(a) events[#events + 1] = a.data.state end })

check(vim.wait(2000, function() local s = status.get(1); return s and s.state == "working" end, 20), "working report received")
check(status.get(1).title == "Refactoring panel.lua", "title decoded")
vim.api.nvim_set_current_win(panel.win_of(buf))
vim.g.statusline_winid = panel.win_of(buf)
local bar = ui.winbar()
check(bar:find("Claude 1", 1, true) and bar:find("working", 1, true), "winbar renders: " .. bar)
vim.api.nvim_set_current_win(edit_win)
vim.g.statusline_winid = edit_win
local ind = ui.indicator()
check(ind:find("C1", 1, true) ~= nil, "indicator renders: " .. ind)

check(vim.wait(2000, function() local s = status.get(1); return s and s.state == "blocked" end, 20), "blocked report received")
check(status.get(1).kind == "permission", "kind")
check(status.get(1).attention == "blocked", "attention set while unfocused")
check(mention.send(1, "@x") == false, "mention refused while blocked")

check(vim.wait(3000, function()
    local lines = table.concat(vim.api.nvim_buf_get_lines(buf, 0, -1, false), "")
    return lines:find("CAPS_OK", 1, true) ~= nil or lines:find("CAPS_MISSING", 1, true) ~= nil
end, 20), "stub reported probe answer")
check(table.concat(vim.api.nvim_buf_get_lines(buf, 0, -1, false), ""):find("CAPS_OK", 1, true), "probe answered before DA")

check(vim.wait(3000, function() local s = status.get(1); return s and s.state == "error" end, 20), "non-zero exit -> error state")
check(not panel.live(1), "slot not live after exit")
check(vim.tbl_contains(events, "working") and vim.tbl_contains(events, "blocked"), "User ClaudeStatus fired")

-- relaunch in place replaces the crashed buffer
local buf2 = panel.open(1, { cmd = { "sh", "-c", "exit 0" }, focus = false })
check(buf2 and buf2 ~= buf, "relaunch creates a new buffer")
check(vim.wait(2000, function() return status.get(1) == nil end, 20), "clean exit forgets the slot")
check(vim.wait(1000, function() return not vim.api.nvim_buf_is_valid(buf2) end, 20), "clean exit deletes the buffer")

-- mention formatting
vim.cmd("edit lua/claude/panel.lua")
check(mention.format(vim.api.nvim_buf_get_name(0), 5, 10) == "@lua/claude/panel.lua#L5-10", "range mention")
check(mention.format(vim.api.nvim_buf_get_name(0)) == "@lua/claude/panel.lua", "file mention")
check(mention.current() == "@lua/claude/panel.lua", "current() in normal mode")

-- map renders without error when nothing runs
local lines = require("claude.map").render()
check(#lines > 0, "map renders")

print("claude_panel: all assertions passed")
end)
if not ok then
    io.stderr:write(tostring(err) .. "\n")
    vim.cmd("cquit! 1")
end
vim.cmd("qa!")
