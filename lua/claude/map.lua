-- Agent map: a floating window listing each Claude slot with its state,
-- running subagents, background tasks and recent to-dos, then the other
-- Claude sessions running on this machine (like VS Code's agent map and
-- sessions list). Keys: <CR> focus slot, r refresh, q close.
local M = {}

local buf, win = nil, nil
local line_slots = {} -- line number -> slot id

local function status()
    return require("claude.status")
end
local function ui()
    return require("claude.ui")
end

local function fmt_elapsed(since)
    return since and ui().elapsed(since) or ""
end

function M.render()
    local st = status()
    local panel = require("claude.panel")
    local lines, hls = {}, {}
    line_slots = {}
    local function add(text, group)
        lines[#lines + 1] = text
        if group then
            hls[#lines] = group
        end
    end
    local any = false
    for id = 1, panel.MAX do
        local s = st.get(id)
        if panel.live(id) or (s and (s.state or s.session)) then
            any = true
            local state = s and s.state or "starting"
            local head = ("Claude %d  %s%s%s"):format(id, state, s and s.kind and (" (" .. s.kind .. ")") or "", s and s.since and state == "working" and ("  " .. fmt_elapsed(s.since)) or "")
            add(head, state == "working" and "ClaudeWorking" or state == "blocked" and "ClaudeBlocked" or state == "done" and "ClaudeDone" or state == "error" and "ClaudeError" or "ClaudeIdle")
            line_slots[#lines] = id
            local sess = s and s.session
            if sess and sess.name then
                add("  session " .. sess.name .. (sess.cwd and ("  " .. vim.fn.fnamemodify(sess.cwd, ":~")) or ""), "Comment")
            end
            if s and s.title and s.title ~= "" then
                add("  " .. s.title, "Comment")
            end
            if s and s.msg and s.msg ~= "" and s.msg ~= s.title then
                add("  " .. s.msg, "Comment")
            end
            if sess and sess.tool and sess.tool.name then
                add("  tool " .. sess.tool.name .. "  " .. fmt_elapsed(sess.tool.at))
            end
            local agents = st.agents(id)
            if #agents > 0 then
                add("  agents")
                for _, a in ipairs(agents) do
                    add(("    ⛬ %-18s %s"):format(a.type or "agent", fmt_elapsed(a.started)), "ClaudeWorking")
                end
            elseif s and next(s.children) then
                add("  agents (terminal reports)")
                for cid, c in pairs(s.children) do
                    add(("    ⛬ %-18s %s %s"):format(c.title or cid, c.state or "", fmt_elapsed(c.since)), "ClaudeWorking")
                end
            end
            if sess and sess.tasks and next(sess.tasks) then
                add("  background tasks")
                for tid, t in pairs(sess.tasks) do
                    add(("    %s %s  %s"):format(t.status or "", t.type or "", t.description or tid))
                end
            end
            if sess and sess.todos and #sess.todos > 0 then
                add("  to-dos")
                local first = math.max(1, #sess.todos - 4)
                for i = first, #sess.todos do
                    local t = sess.todos[i]
                    add(("    %s %s"):format(t.status == "completed" and "✓" or "·", t.subject or ""), t.status == "completed" and "Comment" or nil)
                end
            end
            add("")
        end
    end
    if not any then
        add("No Claude slot running  (<leader>c1 to start one)", "Comment")
        add("")
    end
    local external = {}
    for _, sess in ipairs(st.sessions()) do
        if not sess.slot then
            external[#external + 1] = sess
        end
    end
    if #external > 0 then
        add("Other sessions on this machine", "Title")
        for _, sess in ipairs(external) do
            local agents = 0
            if sess.file and sess.file.agents then
                for _, a in pairs(sess.file.agents) do
                    if not a.ended then
                        agents = agents + 1
                    end
                end
            end
            add(("  %-8s %-28s %s%s"):format(sess.state or "?", sess.name or sess.session_id or "", vim.fn.fnamemodify(sess.cwd or "", ":~"), agents > 0 and ("  ⛬" .. agents) or ""), sess.state == "working" and "ClaudeWorking" or sess.state == "blocked" and "ClaudeBlocked" or nil)
        end
    end
    add("")
    add("<CR> focus slot   r refresh   q close", "Comment")
    return lines, hls
end

local function draw()
    if not (buf and vim.api.nvim_buf_is_valid(buf)) then
        return
    end
    local lines, hls = M.render()
    vim.bo[buf].modifiable = true
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
    vim.bo[buf].modifiable = false
    local ns = vim.api.nvim_create_namespace("claude_map")
    vim.api.nvim_buf_clear_namespace(buf, ns, 0, -1)
    for lnum, group in pairs(hls) do
        vim.api.nvim_buf_set_extmark(buf, ns, lnum - 1, 0, { line_hl_group = group })
    end
    if win and vim.api.nvim_win_is_valid(win) then
        local height = math.min(#lines, math.floor(vim.o.lines * 0.8))
        vim.api.nvim_win_set_height(win, math.max(height, 3))
    end
end

function M.close()
    if win and vim.api.nvim_win_is_valid(win) then
        vim.api.nvim_win_close(win, true)
    end
    win = nil
end

function M.is_open()
    return win ~= nil and vim.api.nvim_win_is_valid(win)
end

function M.open()
    if M.is_open() then
        vim.api.nvim_set_current_win(win)
        draw()
        return
    end
    if not (buf and vim.api.nvim_buf_is_valid(buf)) then
        buf = vim.api.nvim_create_buf(false, true)
        vim.bo[buf].bufhidden = "hide"
        vim.bo[buf].filetype = "claude_map"
        local function map(lhs, fn, desc)
            vim.keymap.set("n", lhs, fn, { buffer = buf, nowait = true, desc = desc })
        end
        map("q", M.close, "Close agent map")
        map("<Esc>", M.close, "Close agent map")
        map("r", draw, "Refresh agent map")
        map("<CR>", function()
            local id = line_slots[vim.api.nvim_win_get_cursor(0)[1]]
            if id then
                M.close()
                require("claude.panel").focus(id)
            end
        end, "Focus slot")
        vim.api.nvim_create_autocmd("User", {
            pattern = "ClaudeStatus",
            callback = function()
                if M.is_open() then
                    draw()
                end
            end,
        })
    end
    local width = math.min(90, math.floor(vim.o.columns * 0.7))
    win = vim.api.nvim_open_win(buf, true, {
        relative = "editor",
        width = width,
        height = 10,
        row = math.floor((vim.o.lines - 20) / 2),
        col = math.floor((vim.o.columns - width) / 2),
        style = "minimal",
        border = "rounded",
        title = " Claude agents & sessions ",
        title_pos = "center",
    })
    vim.wo[win].wrap = false
    draw()
end

function M.toggle()
    if M.is_open() then
        M.close()
    else
        M.open()
    end
end

return M
