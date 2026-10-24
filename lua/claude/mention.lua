-- Push `@path` / `@path#L5-10` references into a Claude prompt by typing
-- them into the terminal (bracketed paste, no newline: nothing is submitted).
-- Phase 3 (claudecode.nvim) can replace `send` with the IDE at_mentioned
-- notification; the formatting stays the same.
local M = {}

--- "@rel/path" or "@rel/path#L5-10" (VS Code's Alt+K form).
function M.format(path, start_line, end_line)
    local rel = vim.fn.fnamemodify(path, ":.")
    if start_line then
        if end_line and end_line ~= start_line then
            return ("@%s#L%d-%d"):format(rel, math.min(start_line, end_line), math.max(start_line, end_line))
        end
        return ("@%s#L%d"):format(rel, start_line)
    end
    return "@" .. rel
end

--- Reference for the current buffer; in Visual mode the selected line range.
function M.current()
    local path = vim.api.nvim_buf_get_name(0)
    if path == "" or vim.bo.buftype ~= "" then
        return nil
    end
    local mode = vim.fn.mode()
    if mode == "v" or mode == "V" or mode == "\22" then
        local a, b = vim.fn.line("v"), vim.fn.line(".")
        vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("<Esc>", true, false, true), "n", false)
        return M.format(path, a, b)
    end
    return M.format(path)
end

--- Reference for the node under the cursor in a neo-tree window.
function M.node(state)
    local node = state and state.tree and state.tree:get_node()
    if node and node.path then
        return M.format(node.path)
    end
    return nil
end

--- Type `text` (plus a trailing space) into slot `id`'s prompt.
--- Launches the slot when nothing runs and retries once Claude is up.
function M.send(id, text, opts)
    opts = opts or {}
    local panel, status = require("claude.panel"), require("claude.status")
    id = id or panel.current() or 1
    if not panel.live(id) then
        local from = vim.api.nvim_get_current_win()
        panel.open(id, { focus = false })
        if not opts.focus and vim.api.nvim_win_is_valid(from) then
            vim.api.nvim_set_current_win(from)
        end
        vim.defer_fn(function()
            M.send(id, text, vim.tbl_extend("force", opts, { retry = true }))
        end, 2500)
        return true
    end
    local s = status.get(id)
    if s and s.state == "blocked" then
        vim.notify(("Claude %d is waiting for input; answer it before sending a mention"):format(id), vim.log.levels.WARN)
        return false
    end
    local chan = vim.bo[panel.buf_of(id)].channel
    vim.api.nvim_chan_send(chan, "\27[200~" .. text .. " \27[201~")
    if opts.focus then
        panel.focus(id)
    end
    return true
end

--- Mention the current file/selection (keymap entry point).
function M.send_current(opts)
    local text = M.current()
    if not text then
        vim.notify("No file to mention in this buffer", vim.log.levels.WARN)
        return
    end
    M.send(nil, text, opts)
end

return M
