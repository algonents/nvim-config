-- State store for the Claude panels: OSC 7501 reports (per slot, in-band,
-- authoritative for state/kind/progress/title/msg) merged with hook state
-- files (authoritative for agents/tasks/todos/session identity) and Claude's
-- own session registry (external sessions). Every change fires
-- `User ClaudeStatus` and redraws the statusline/winbar.
local M = {}

M.slots = {}  -- id -> { state, kind, progress, title, msg, since, attention, children = {}, session = table|nil }
M.files = {}  -- session_id -> hook state file contents (all sessions on this machine)

local function panel()
    return require("claude.panel")
end

local redraw_pending = false
local function redraw()
    if redraw_pending then
        return
    end
    redraw_pending = true
    vim.defer_fn(function()
        redraw_pending = false
        local ok = pcall(vim.api.nvim__redraw, { statusline = true, winbar = true })
        if not ok then
            pcall(vim.cmd, "redrawstatus")
        end
    end, 50)
end

local function emit(id, prev)
    local s = M.slots[id] or {}
    vim.api.nvim_exec_autocmds("User", {
        pattern = "ClaudeStatus",
        modeline = false,
        data = { slot = id, state = s.state, prev = prev, kind = s.kind, title = s.title, msg = s.msg },
    })
    redraw()
end

local function slot(id)
    local s = M.slots[id]
    if not s then
        s = { children = {} }
        M.slots[id] = s
    end
    return s
end

--- Is the slot's window the current window?
function M.focused(id)
    local p = panel()
    local buf = p.buf_of(id)
    if not buf then
        return false
    end
    return vim.api.nvim_get_current_buf() == buf
end

--- Is the slot's buffer shown in any window?
function M.visible(id)
    local p = panel()
    local buf = p.buf_of(id)
    return buf ~= nil and p.win_of(buf) ~= nil
end

--- Top-level OSC 7501 report for a slot.
function M.report(id, r)
    local s = slot(id)
    local prev = s.state
    if r.state == "clear" then
        M.clear(id)
        return
    end
    if r.state ~= prev then
        s.since = os.time()
    end
    s.state, s.kind, s.progress, s.title, s.msg = r.state, r.kind, r.progress, r.title, r.msg
    if r.state == "blocked" or r.state == "done" then
        if not M.focused(id) then
            s.attention = r.state
        end
    elseif r.state == "working" then
        s.attention = nil
    end
    emit(id, prev)
end

--- Child record (id=... path) from OSC 7501; may describe a subagent.
function M.report_child(id, child_id, r)
    local s = slot(id)
    if r.state == "clear" then
        -- clearing a record removes it and its descendants
        for k in pairs(s.children) do
            if k == child_id or k:sub(1, #child_id + 1) == child_id .. "/" then
                s.children[k] = nil
            end
        end
    else
        s.children[child_id] = { state = r.state, kind = r.kind, title = r.title, msg = r.msg, progress = r.progress, since = (s.children[child_id] or {}).since or os.time() }
    end
    emit(id, s.state)
end

--- Program exited cleanly or reported `clear`: forget its OSC state.
function M.clear(id)
    local s = M.slots[id]
    local prev = s and s.state
    if s then
        s.state, s.kind, s.progress, s.title, s.msg, s.attention = nil, nil, nil, nil, nil, nil
        s.children = {}
    end
    emit(id, prev)
end

--- Slot was focused by the user: attention has been seen.
function M.seen(id)
    local s = M.slots[id]
    if s and s.attention then
        s.attention = nil
        emit(id, s.state)
    end
end

--- Program exited with a non-zero code.
function M.exited(id, code)
    local s = slot(id)
    local prev = s.state
    s.state, s.kind, s.msg, s.since = "error", nil, ("exited with code %d"):format(code), os.time()
    s.children = {}
    emit(id, prev)
end

--- Drop everything about a slot (buffer deleted).
function M.forget(id)
    local prev = M.slots[id] and M.slots[id].state
    M.slots[id] = nil
    emit(id, prev)
end

function M.get(id)
    return M.slots[id]
end

function M.by_buf(buf)
    local id = panel().slot_of(buf)
    return id and M.slots[id] or nil, id
end

-- Hook state files -----------------------------------------------------------

local function is_own(file)
    return file.nvim ~= nil and file.nvim ~= "" and file.nvim == vim.v.servername and file.slot ~= nil
end

--- Merge a hook state file (see claude/hook.sh) into the store.
function M.merge_session(file)
    if type(file) ~= "table" or not file.session_id then
        return
    end
    M.files[file.session_id] = file
    if is_own(file) then
        local id = tonumber(file.slot)
        if id then
            local s = slot(id)
            -- /clear or --resume gives the same slot a new session: newest wins.
            if not s.session or s.session.session_id == file.session_id or (file.updated or 0) >= (s.session.updated or 0) then
                s.session = file
                emit(id, s.state)
            end
        end
    else
        redraw()
    end
end

function M.remove_session(session_id)
    local file = M.files[session_id]
    M.files[session_id] = nil
    if file and is_own(file) then
        local id = tonumber(file.slot)
        local s = id and M.slots[id]
        if s and s.session and s.session.session_id == session_id then
            s.session = nil
            emit(id, s.state)
        end
    else
        redraw()
    end
end

--- Running subagents of a slot (hook data), as a list sorted by start time.
function M.agents(id)
    local s = M.slots[id]
    local out = {}
    if s and s.session and s.session.agents then
        for agent_id, a in pairs(s.session.agents) do
            if not a.ended then
                table.insert(out, { id = agent_id, type = a.type, started = a.started })
            end
        end
    end
    table.sort(out, function(a, b)
        return (a.started or 0) < (b.started or 0)
    end)
    return out
end

--- Counts across own slots: { working=, blocked=, done=, agents= }.
function M.summary()
    local sum = { working = 0, blocked = 0, done = 0, agents = 0 }
    for id, s in pairs(M.slots) do
        if s.state and sum[s.state] then
            sum[s.state] = sum[s.state] + 1
        end
        sum.agents = sum.agents + #M.agents(id)
    end
    return sum
end

--- Every live Claude session on this machine: own slots first, then external.
--- Entries: { session_id, name, cwd, pid, slot (nil when external), state, file }.
function M.sessions()
    local hooks = require("claude.hooks")
    local out, seen = {}, {}
    local function slot_of_file(file)
        if file and is_own(file) then
            local id = tonumber(file.slot)
            if id and M.slots[id] and M.slots[id].session and M.slots[id].session.session_id == file.session_id then
                return id
            end
        end
        return nil
    end
    for _, r in ipairs(hooks.registry()) do
        local file = M.files[r.sessionId]
        local id = slot_of_file(file)
        local state = (id and M.slots[id].state) or (file and file.state) or (r.status == "busy" and "working" or r.status)
        table.insert(out, { session_id = r.sessionId, name = r.name, cwd = r.cwd, pid = r.pid, slot = id, state = state, file = file })
        seen[r.sessionId] = true
    end
    for sid, file in pairs(M.files) do
        if not seen[sid] then
            local id = slot_of_file(file)
            table.insert(out, { session_id = sid, name = file.name, cwd = file.cwd, pid = file.pid, slot = id, state = (id and M.slots[id].state) or file.state, file = file })
        end
    end
    table.sort(out, function(a, b)
        if (a.slot ~= nil) ~= (b.slot ~= nil) then
            return a.slot ~= nil
        end
        if a.slot and b.slot then
            return a.slot < b.slot
        end
        return (a.name or "") < (b.name or "")
    end)
    return out
end

return M
