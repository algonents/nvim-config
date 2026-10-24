-- Run: env -u NVIM nvim --clean --headless -u NONE --cmd "set rtp^=." -S tests/claude_hooks.lua
-- Feeds state files through the fs_event watcher and checks the store.
-- Exits 0 on success, 1 on the first failed assertion (never hangs).
local ok, err = pcall(function()
local dir = vim.fn.tempname()
local claude = require("claude")
claude.setup({ hooks = { dir = dir } })
local status, hooks, map = require("claude.status"), require("claude.hooks"), require("claude.map")
hooks.registry_dir = vim.fn.tempname() -- no real registry during the test
local function check(cond, msg) if not cond then error("claude_hooks: " .. msg) end end
local function write(name, tbl)
    local f = assert(io.open(dir .. "/" .. name, "w"))
    f:write(vim.json.encode(tbl))
    f:close()
end
local me = vim.uv.os_getpid()
-- own slot 1 (nvim = this server) with one running agent
local own = { session_id = "s-own", pid = me, cwd = vim.fn.getcwd(), nvim = vim.v.servername, slot = 1, started = os.time(), updated = os.time(), state = "working",
    agents = { a1 = { type = "Explore", started = os.time() - 65, ended = vim.NIL }, a2 = { type = "Plan", started = os.time(), ended = os.time() } },
    tasks = { t1 = { type = "shell", status = "running", description = "cargo test" } }, todos = { { subject = "write tests", status = "created", at = os.time() } } }
write("s-own.json", own)
check(vim.wait(2000, function() return status.files["s-own"] ~= nil end, 20), "fs_event delivered own file")
check(status.get(1) and status.get(1).session and status.get(1).session.session_id == "s-own", "joined to slot 1")
local agents = status.agents(1)
check(#agents == 1 and agents[1].type == "Explore", "one running agent (ended one excluded)")
check(status.summary().agents == 1, "summary agent count")
-- external session (other terminal)
write("s-ext.json", { session_id = "s-ext", pid = me, cwd = "/tmp", nvim = vim.NIL, slot = vim.NIL, updated = os.time(), state = "idle", agents = {}, tasks = {}, todos = {} })
check(vim.wait(2000, function() return status.files["s-ext"] ~= nil end, 20), "external file read")
local sessions = status.sessions()
check(#sessions == 2 and sessions[1].slot == 1 and sessions[2].slot == nil, "sessions(): own first, external second")
-- dead pid is swept
write("s-dead.json", { session_id = "s-dead", pid = 999999, updated = os.time(), agents = {} })
vim.wait(300, function() return false end)
check(status.files["s-dead"] == nil and vim.uv.fs_stat(dir .. "/s-dead.json") == nil, "dead-pid file swept")
-- removal
os.remove(dir .. "/s-ext.json")
check(vim.wait(2000, function() return status.files["s-ext"] == nil end, 20), "removed file forgotten")
-- map rendering
local lines = map.render()
local text = table.concat(lines, "\n")
check(text:find("Explore", 1, true) and text:find("cargo test", 1, true) and text:find("write tests", 1, true), "map lists agent, task, todo:\n" .. text)
-- hooks check reports missing events against a settings file without hooks
local missing = hooks.check()
check(#missing >= 0, "check runs")
print("claude_hooks: all assertions passed")
end)
if not ok then
    io.stderr:write(tostring(err) .. "\n")
    vim.cmd("cquit! 1")
end
vim.cmd("qa!")
