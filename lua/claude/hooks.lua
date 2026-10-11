-- Reads the state files written by claude/hook.sh (one per Claude session,
-- in $XDG_RUNTIME_DIR/claude-nvim/) and Claude's own session registry
-- (~/.claude/sessions/<pid>.json). Watches the state directory so subagent
-- and task changes reach the UI as they happen.
local M = {}

local uv = vim.uv

local function default_dir()
    local base = os.getenv("XDG_RUNTIME_DIR")
    if not base or base == "" then
        base = "/tmp/claude-nvim-" .. (uv.getuid and uv.getuid() or "user")
    end
    return base .. "/claude-nvim"
end

M.dir = default_dir()
M.registry_dir = vim.fn.expand("~/.claude/sessions")
M.MAX_AGE = 24 * 3600

M.EVENTS = {
    "SessionStart", "UserPromptSubmit", "PreToolUse", "PostToolUse", "PermissionRequest",
    "SubagentStart", "SubagentStop", "Stop", "Notification", "TaskCreated", "TaskCompleted", "SessionEnd",
}

local function status()
    return require("claude.status")
end

local function pid_alive(pid)
    pid = tonumber(pid)
    if not pid or pid <= 0 then
        return false
    end
    return uv.kill(pid, 0) == 0
end

local function read_json(path)
    local f = io.open(path, "r")
    if not f then
        return nil
    end
    local text = f:read("*a")
    f:close()
    if not text or text == "" then
        return nil
    end
    local ok, data = pcall(vim.json.decode, text, { luanil = { object = true, array = true } })
    if ok and type(data) == "table" then
        return data
    end
    return nil
end

local function stale(file)
    if not pid_alive(file.pid) then
        return true
    end
    return (os.time() - (file.updated or 0)) > M.MAX_AGE
end

--- (Re)read one state file; stale files are deleted and forgotten.
function M.read_file(path)
    local file = read_json(path)
    local sid = vim.fn.fnamemodify(path, ":t:r")
    if not file then
        if uv.fs_stat(path) == nil then
            status().remove_session(sid)
        end
        return
    end
    if stale(file) then
        pcall(os.remove, path)
        pcall(os.remove, path .. ".lock")
        status().remove_session(file.session_id or sid)
        return
    end
    status().merge_session(file)
end

function M.scan()
    for _, path in ipairs(vim.fn.glob(M.dir .. "/*.json", true, true)) do
        M.read_file(path)
    end
end

--- Live sessions from Claude's registry: { pid, sessionId, cwd, name, status }.
function M.registry()
    local out = {}
    for _, path in ipairs(vim.fn.glob(M.registry_dir .. "/*.json", true, true)) do
        local r = read_json(path)
        if r and r.sessionId and pid_alive(r.pid) then
            out[#out + 1] = r
        end
    end
    return out
end

local pending = {}
local function on_change(filename)
    if not filename or not filename:match("%.json$") then
        return
    end
    if pending[filename] then
        return
    end
    pending[filename] = true
    vim.defer_fn(function()
        pending[filename] = nil
        M.read_file(M.dir .. "/" .. filename)
    end, 30)
end

function M.setup(opts)
    opts = opts or {}
    if opts.dir then
        M.dir = opts.dir
    end
    vim.fn.mkdir(M.dir, "p")
    M.scan()
    if M.watcher then
        M.watcher:stop()
    end
    M.watcher = uv.new_fs_event()
    M.watcher:start(M.dir, {}, vim.schedule_wrap(function(err, filename)
        if not err then
            on_change(filename)
        end
    end))
end

--- :ClaudeHooksCheck — report whether ~/.claude/settings.json runs hook.sh
--- for every event the integration needs.
function M.check()
    local lines = {}
    local script = vim.fn.fnamemodify(debug.getinfo(1, "S").source:sub(2), ":h:h:h") .. "/claude/hook.sh"
    lines[#lines + 1] = (vim.fn.executable(script) == 1 and "ok  " or "MISSING  ") .. script .. (vim.fn.executable(script) == 1 and "" or " (chmod +x)")
    lines[#lines + 1] = (vim.fn.executable("jq") == 1 and "ok  " or "MISSING  ") .. "jq on PATH"
    local settings = read_json(vim.fn.expand("~/.claude/settings.json")) or {}
    local hooks = settings.hooks or {}
    local missing = {}
    for _, ev in ipairs(M.EVENTS) do
        local found = false
        for _, group in ipairs(hooks[ev] or {}) do
            for _, h in ipairs(group.hooks or {}) do
                if type(h.command) == "string" and h.command:find("claude/hook.sh", 1, true) then
                    found = true
                end
            end
        end
        if not found then
            missing[#missing + 1] = ev
        end
    end
    if #missing == 0 then
        lines[#lines + 1] = "ok  all " .. #M.EVENTS .. " hook events configured in ~/.claude/settings.json"
    else
        lines[#lines + 1] = "MISSING  hooks in ~/.claude/settings.json for: " .. table.concat(missing, ", ") .. " (see CLAUDE.md)"
    end
    lines[#lines + 1] = "state dir: " .. M.dir .. " (" .. #vim.fn.glob(M.dir .. "/*.json", true, true) .. " session files)"
    vim.notify(table.concat(lines, "\n"), #missing == 0 and vim.log.levels.INFO or vim.log.levels.WARN, { title = "Claude hooks" })
    return missing
end

return M
