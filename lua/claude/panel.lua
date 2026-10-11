-- Claude Code terminal slots. The first slot opens as a right vertical
-- column (~30% width); further slots stack below it inside that column.
-- Each slot is a plain terminal buffer running `claude` with
-- NVIM_CLAUDE_SLOT in its environment, so hook scripts (claude/hook.sh) can
-- tell Neovim which panel a session belongs to.
local M = {}

M.MAX = 3
M.WIDTH = 0.3
M.slots = {} -- id -> { buf, job, exited_at, exit_code }
local last_used = nil

local function status()
    return require("claude.status")
end

function M.win_of(buf)
    for _, win in ipairs(vim.api.nvim_list_wins()) do
        if vim.api.nvim_win_get_buf(win) == buf then
            return win
        end
    end
    return nil
end

function M.slot_of(buf)
    if not buf or not vim.api.nvim_buf_is_valid(buf) then
        return nil
    end
    return vim.b[buf].claude_slot
end

function M.is_claude_buf(buf)
    return M.slot_of(buf) ~= nil
end

--- Buffer of a live (running) slot, or nil.
function M.buf_of(id)
    local s = M.slots[id]
    if s and vim.api.nvim_buf_is_valid(s.buf) then
        return s.buf
    end
    return nil
end

--- Slot has a buffer whose job is still running.
function M.live(id)
    local s = M.slots[id]
    return s ~= nil and vim.api.nvim_buf_is_valid(s.buf) and s.exited_at == nil
end

function M.any_window()
    for _, s in pairs(M.slots) do
        if vim.api.nvim_buf_is_valid(s.buf) then
            local win = M.win_of(s.buf)
            if win then
                return win
            end
        end
    end
    return nil
end

function M.first_free()
    for id = 1, M.MAX do
        if not M.live(id) then
            return id
        end
    end
    return nil
end

function M.last_used()
    if last_used and M.live(last_used) then
        return last_used
    end
    for id = 1, M.MAX do
        if M.live(id) then
            return id
        end
    end
    return nil
end

--- Environment for the claude process. Phase 3 (claudecode.nvim) merges the
--- IDE variables here.
function M.env(id)
    return { NVIM_CLAUDE_SLOT = tostring(id) }
end

-- Jump to an editing window: the previous window if it is one, else the first
-- normal (non-floating, buftype "") window in the tab. Used before opening
-- pickers from a panel and by the focus toggle.
function M.focus_edit_window()
    local function is_edit(win)
        return vim.api.nvim_win_is_valid(win)
            and vim.api.nvim_win_get_config(win).relative == ""
            and vim.bo[vim.api.nvim_win_get_buf(win)].buftype == ""
    end
    if is_edit(vim.api.nvim_get_current_win()) then
        return true
    end
    local prev = vim.fn.win_getid(vim.fn.winnr("#"))
    if prev ~= 0 and is_edit(prev) then
        vim.api.nvim_set_current_win(prev)
        return true
    end
    for _, win in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
        if is_edit(win) then
            vim.api.nvim_set_current_win(win)
            return true
        end
    end
    return false
end

local function split_for_slot()
    local other = M.any_window()
    if other then
        vim.api.nvim_set_current_win(other)
        vim.cmd("belowright split")
    else
        vim.cmd("botright vsplit")
        vim.cmd("vertical resize " .. math.floor(vim.o.columns * M.WIDTH))
    end
end

local function launch(id, opts)
    local buf = vim.api.nvim_create_buf(true, false)
    vim.b[buf].claude_slot = id -- before the window shows it: BufWinEnter attaches the winbar
    vim.api.nvim_win_set_buf(0, buf)
    require("claude.ui").attach_winbar(vim.api.nvim_get_current_win())
    local cmd = opts.cmd
    if not cmd then
        cmd = { "claude" }
        vim.list_extend(cmd, opts.args or {})
    end
    local job = vim.fn.jobstart(cmd, { term = true, env = M.env(id) })
    if job <= 0 then
        vim.notify("Claude " .. id .. ": failed to start " .. table.concat(cmd, " "), vim.log.levels.ERROR)
        return nil
    end
    M.slots[id] = { buf = buf, job = job }
    -- Inside Claude, Esc belongs to Claude (cancel, dismiss). Leave the panel
    -- with Alt-arrows, Alt-c or <C-\><C-n> instead.
    vim.keymap.set("t", "<Esc>", "<Esc>", { buffer = buf, desc = "Send Esc to Claude" })
    vim.api.nvim_create_autocmd("TermClose", {
        buffer = buf,
        once = true,
        callback = function()
            local code = vim.v.event.status
            local s = M.slots[id]
            if not s or s.buf ~= buf then
                return
            end
            s.exited_at, s.exit_code = os.time(), code
            if code == 0 then
                -- Clean exit: drop the "[Process exited 0]" buffer so the
                -- next toggle launches a fresh session.
                M.slots[id] = nil
                status().forget(id)
                vim.schedule(function()
                    if vim.api.nvim_buf_is_valid(buf) then
                        pcall(vim.cmd, "bdelete! " .. buf)
                    end
                end)
            else
                status().exited(id, code)
            end
        end,
    })
    vim.api.nvim_exec_autocmds("User", { pattern = "ClaudePanelOpen", modeline = false, data = { slot = id, buf = buf } })
    return buf
end

--- Show slot `id`, launching claude when it is not running.
--- opts.args: extra CLI args (e.g. { "--continue" }); opts.cmd: full command
--- override (tests); opts.focus = false keeps Normal mode.
function M.open(id, opts)
    opts = opts or {}
    local s = M.slots[id]
    local existing = s and vim.api.nvim_buf_is_valid(s.buf) and s.buf or nil
    local win = existing and M.win_of(existing)
    if existing and not s.exited_at then
        if win then
            vim.api.nvim_set_current_win(win)
        else
            split_for_slot()
            vim.api.nvim_win_set_buf(0, existing)
            require("claude.ui").attach_winbar(vim.api.nvim_get_current_win())
        end
    else
        -- Nothing running: launch, reusing the window of a crashed session
        -- (kept open so its output could be read) when there is one.
        if win then
            vim.api.nvim_set_current_win(win)
        else
            split_for_slot()
        end
        if existing then
            M.slots[id] = nil
            vim.schedule(function()
                if vim.api.nvim_buf_is_valid(existing) then
                    pcall(vim.cmd, "bdelete! " .. existing)
                end
            end)
        end
        if not launch(id, opts) then
            return nil
        end
    end
    last_used = id
    if opts.focus ~= false then
        vim.cmd("startinsert!")
    end
    return M.slots[id] and M.slots[id].buf
end

--- Hide the slot's window if visible, otherwise show/launch it.
function M.toggle(id)
    local buf = M.buf_of(id)
    local win = buf and M.win_of(buf)
    if win then
        vim.api.nvim_win_close(win, false)
        return
    end
    M.open(id)
end

function M.focus(id)
    return M.open(id)
end

function M.hide(id)
    local buf = M.buf_of(id)
    local win = buf and M.win_of(buf)
    if win then
        vim.api.nvim_win_close(win, false)
    end
end

--- Editor <-> Claude: from a Claude buffer go back to an editing window;
--- from anywhere else focus the last-used slot (slot 1 when none runs).
function M.focus_toggle()
    if M.is_claude_buf(vim.api.nvim_get_current_buf()) then
        vim.cmd("stopinsert")
        M.focus_edit_window()
        return
    end
    M.focus(M.last_used() or 1)
end

--- Launch claude with extra args in the first free slot (e.g. --resume).
function M.open_free(args)
    local id = M.first_free()
    if not id then
        vim.notify("All " .. M.MAX .. " Claude slots are running", vim.log.levels.WARN)
        return nil
    end
    return M.open(id, { args = args })
end

--- Stop the slot's job and close its window/buffer.
function M.stop(id)
    local s = M.slots[id]
    if not s then
        return
    end
    if s.job and not s.exited_at then
        pcall(vim.fn.jobstop, s.job)
    end
    M.slots[id] = nil
    status().forget(id)
    if vim.api.nvim_buf_is_valid(s.buf) then
        pcall(vim.cmd, "bdelete! " .. s.buf)
    end
end

--- Slot shown in the current window, else the last-used one.
function M.current()
    return M.slot_of(vim.api.nvim_get_current_buf()) or M.last_used()
end

function M.setup()
    vim.api.nvim_create_autocmd("BufEnter", {
        group = vim.api.nvim_create_augroup("ClaudePanel", { clear = true }),
        callback = function(args)
            local id = M.slot_of(args.buf)
            if id then
                last_used = id
                status().seen(id)
            end
        end,
    })
end

return M
