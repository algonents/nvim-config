-- Rendering: a winbar on Claude windows, a status segment on the focused
-- window's statusline, and notifications when a hidden slot needs input or
-- finishes. Colors follow VS Code's dots: blue = permission pending,
-- orange = finished while hidden.
local M = {}

local GLYPH = { working = "●", blocked = "◆", done = "✓", idle = "○", error = "✗" }
local HL = { working = "ClaudeWorking", blocked = "ClaudeBlocked", done = "ClaudeDone", idle = "ClaudeIdle", error = "ClaudeError" }

local function status()
    return require("claude.status")
end
local function panel()
    return require("claude.panel")
end

function M.setup_highlights()
    vim.api.nvim_set_hl(0, "ClaudeWorking", { link = "DiagnosticOk", default = true })
    vim.api.nvim_set_hl(0, "ClaudeBlocked", { link = "DiagnosticInfo", default = true })
    vim.api.nvim_set_hl(0, "ClaudeDone", { link = "DiagnosticWarn", default = true })
    vim.api.nvim_set_hl(0, "ClaudeError", { link = "DiagnosticError", default = true })
    vim.api.nvim_set_hl(0, "ClaudeIdle", { link = "Comment", default = true })
end

function M.elapsed(since)
    if not since then
        return ""
    end
    local d = math.max(0, os.time() - since)
    if d < 60 then
        return d .. "s"
    elseif d < 3600 then
        return math.floor(d / 60) .. "m"
    end
    return ("%dh%02dm"):format(math.floor(d / 3600), math.floor(d % 3600 / 60))
end

local function hl(state)
    return "%#" .. (HL[state] or "ClaudeIdle") .. "#"
end

local function glyph(state)
    return GLYPH[state] or "○"
end

--- Short label for a slot: "● 2m", "◆ perm", "✓", "○".
local function short(s)
    if not s or not s.state then
        return "○"
    end
    if s.state == "working" then
        return glyph(s.state) .. " " .. M.elapsed(s.since)
    elseif s.state == "blocked" then
        return glyph(s.state) .. " " .. (s.kind and s.kind:sub(1, 4) or "input")
    end
    return glyph(s.state)
end

--- Whole statusline (`%!` form): Neovim's default layout with the Claude
--- segment before the ruler. `%!` is required: with `%{}` items Neovim does
--- not set g:statusline_winid, so the focused-window check cannot work.
function M.statusline()
    return "%<%f %h%w%m%r %=" .. M.indicator() .. "%-14.(%l,%c%V%) %P"
end

--- Statusline segment: one entry per live slot plus the agent count, only on
--- the focused window (vim.g.statusline_winid is the window being drawn).
function M.indicator()
    if vim.g.statusline_winid ~= vim.api.nvim_get_current_win() then
        return ""
    end
    local p, st = panel(), status()
    local parts = {}
    for id = 1, p.MAX do
        if p.live(id) or (st.get(id) and st.get(id).state == "error") then
            local s = st.get(id)
            local state = s and s.state
            local label = "C" .. id .. " " .. short(s)
            local attention = s and s.attention
            parts[#parts + 1] = hl(attention or state) .. label .. "%*"
        end
    end
    if #parts == 0 then
        return ""
    end
    local agents = st.summary().agents
    if agents > 0 then
        parts[#parts + 1] = hl("working") .. "⛬" .. agents .. "%*"
    end
    return " " .. table.concat(parts, "  ") .. " "
end

--- Winbar for a Claude window.
function M.winbar()
    local win = vim.g.statusline_winid
    if not win or not vim.api.nvim_win_is_valid(win) then
        return ""
    end
    local buf = vim.api.nvim_win_get_buf(win)
    local p, st = panel(), status()
    local id = p.slot_of(buf)
    if not id then
        return ""
    end
    local s = st.get(id)
    local state = s and s.state
    local width = vim.api.nvim_win_get_width(win)
    local out = { hl(state), " ", glyph(state), " Claude ", id, "%*" }
    if state then
        out[#out + 1] = " " .. state
        if s.kind then
            out[#out + 1] = " (" .. s.kind .. ")"
        end
        if s.progress then
            out[#out + 1] = " " .. s.progress .. "%%"
        end
        if state == "working" and s.since then
            out[#out + 1] = " " .. M.elapsed(s.since)
        end
    else
        out[#out + 1] = " starting"
    end
    local agents = st.agents(id)
    if #agents > 0 then
        out[#out + 1] = " ⛬" .. #agents
    end
    if width >= 50 then
        local text = s and (s.title or s.msg)
        if text and text ~= "" then
            out[#out + 1] = " · %<" .. text:gsub("%%", "%%%%")
        end
    end
    return table.concat(out)
end

function M.attach_winbar(win)
    vim.api.nvim_set_option_value("winbar", "%!v:lua.require'claude.ui'.winbar()", { win = win, scope = "local" })
end

-- Notifications ---------------------------------------------------------------

local last_key = nil

function M.on_status(data)
    local id, state = data.slot, data.state
    if not id or not state or state == data.prev then
        return
    end
    local st = status()
    local key = table.concat({ id, state, data.kind or "", data.msg or "" }, "|")
    if key == last_key then
        return
    end
    if state == "blocked" then
        last_key = key
        local what = data.kind or "input"
        local msg = data.msg and data.msg ~= "" and (": " .. data.msg) or ""
        vim.notify(("Claude %d needs %s%s"):format(id, what, msg), vim.log.levels.WARN, { title = "Claude Code" })
    elseif state == "done" and not st.focused(id) then
        last_key = key
        local title = data.title and data.title ~= "" and (": " .. data.title) or ""
        vim.notify(("Claude %d finished%s"):format(id, title), vim.log.levels.INFO, { title = "Claude Code" })
    elseif state == "error" and data.msg then
        last_key = key
        vim.notify(("Claude %d %s"):format(id, data.msg), vim.log.levels.ERROR, { title = "Claude Code" })
    end
end

function M.setup()
    M.setup_highlights()
    local group = vim.api.nvim_create_augroup("ClaudeUI", { clear = true })
    vim.api.nvim_create_autocmd("ColorScheme", { group = group, callback = M.setup_highlights })
    vim.o.statusline = "%!v:lua.require'claude.ui'.statusline()"
    vim.api.nvim_create_autocmd("BufWinEnter", {
        group = group,
        callback = function(args)
            if panel().is_claude_buf(args.buf) then
                M.attach_winbar(vim.api.nvim_get_current_win())
            end
        end,
    })
    vim.api.nvim_create_autocmd("User", {
        group = group,
        pattern = "ClaudeStatus",
        callback = function(args)
            M.on_status(args.data or {})
        end,
    })
    -- Keep elapsed times moving while something runs.
    local timer = vim.uv.new_timer()
    timer:start(10000, 10000, vim.schedule_wrap(function()
        if status().summary().working > 0 then
            pcall(vim.api.nvim__redraw, { statusline = true, winbar = true })
        end
    end))
end

return M
