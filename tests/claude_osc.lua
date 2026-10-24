-- Run: env -u NVIM nvim --clean --headless -u NONE --cmd "set rtp^=." -S tests/claude_osc.lua
-- Exits 0 on success, 1 on the first failed assertion (never hangs).
local ok, err = pcall(function()
local osc = require("claude.osc")
local function eq(a, b, msg)
    if not vim.deep_equal(a, b) then
        error(("%s: expected %s, got %s"):format(msg, vim.inspect(b), vim.inspect(a)))
    end
end
eq(osc.parse("\27]7501;?"), "probe", "probe without terminator")
eq(osc.parse("\27]7501;?\27\\"), "probe", "probe with ST")
eq(osc.parse("\27]7501;?\7"), "probe", "probe with BEL")
local title = vim.base64.encode("Refactor panel.lua")
local r = osc.parse("\27]7501;state=working:progress=42:title=" .. title .. ":app=claude-code\27\\")
eq(r.state, "working", "state")
eq(r.progress, 42, "progress")
eq(r.title, "Refactor panel.lua", "title decoded")
eq(r.app, "claude-code", "app")
r = osc.parse("\27]7501;state=blocked:kind=permission:msg=" .. vim.base64.encode("Bash: cargo test") .. "\7")
eq(r.state, "blocked", "blocked")
eq(r.kind, "permission", "kind")
eq(r.msg, "Bash: cargo test", "msg decoded (BEL)")
r = osc.parse("\27]7501;state=clear\27\\")
eq(r.state, "clear", "clear")
r = osc.parse("\27]7501;id=agents/1:state=working:app=claude-code")
eq(r.id, "agents/1", "child id")
eq(osc.parse("\27]7;file:///tmp"), nil, "other OSC ignored")
eq(osc.parse("\27]7501;garbage"), nil, "no state -> nil")
eq(osc.parse(nil), nil, "nil input")
print("claude_osc: all assertions passed")
end)
if not ok then
    io.stderr:write(tostring(err) .. "\n")
    vim.cmd("cquit! 1")
end
vim.cmd("qa!")
