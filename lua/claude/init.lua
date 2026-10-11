-- Claude Code integration: terminal slots with live status (OSC 7501 from
-- the claude process itself), subagents/tasks/sessions from hook state
-- files, a winbar + statusline indicator, notifications, @-mentions and an
-- agent map. See CLAUDE.md "Claude Code integration".
local M = {}

local function on_term_request(ev)
    local id = vim.b[ev.buf].claude_slot
    if not id then
        return
    end
    local osc = require("claude.osc")
    local seq = ev.data and ev.data.sequence
    local r = osc.parse(seq)
    if r == nil then
        return
    end
    if r == "probe" then
        -- Reply synchronously: Claude treats Neovim's primary-DA answer,
        -- which libvterm queues right after this OSC, as "no support".
        pcall(vim.api.nvim_chan_send, vim.bo[ev.buf].channel, osc.CAPS)
        return
    end
    local status = require("claude.status")
    if r.id and r.id ~= "" then
        status.report_child(id, r.id, r)
    else
        status.report(id, r)
    end
end

function M.setup(opts)
    opts = opts or {}
    local panel = require("claude.panel")
    panel.setup()
    require("claude.ui").setup()

    local group = vim.api.nvim_create_augroup("ClaudeIntegration", { clear = true })
    vim.api.nvim_create_autocmd("TermRequest", { group = group, callback = on_term_request })

    if opts.hooks ~= false then
        local ok, err = pcall(require("claude.hooks").setup, opts.hooks)
        if not ok then
            vim.schedule(function()
                vim.notify("claude.hooks: " .. tostring(err), vim.log.levels.WARN)
            end)
        end
    end

    vim.api.nvim_create_user_command("Claude", function(a)
        local args = vim.split(a.args, "%s+", { trimempty = true })
        local id = tonumber(args[1])
        if id then
            table.remove(args, 1)
        end
        if id and #args == 0 then
            panel.toggle(id)
        elseif id then
            panel.open(id, { args = args })
        else
            panel.open_free(args)
        end
    end, { nargs = "*", desc = "Claude [slot] [claude args]: toggle a slot or launch with arguments" })
    vim.api.nvim_create_user_command("ClaudeMap", function()
        require("claude.map").toggle()
    end, { desc = "Toggle the Claude agent map" })
    vim.api.nvim_create_user_command("ClaudeHooksCheck", function()
        require("claude.hooks").check()
    end, { desc = "Check ~/.claude/settings.json hooks for the Neovim integration" })
    vim.api.nvim_create_user_command("ClaudePlan", M.open_plan, { desc = "Open the newest Claude plan file" })
end

--- Open the most recently modified ~/.claude/plans/*.md in an edit window.
function M.open_plan()
    local files = vim.fn.glob(vim.fn.expand("~/.claude/plans") .. "/*.md", true, true)
    local newest, newest_mtime = nil, -1
    for _, f in ipairs(files) do
        local mtime = vim.fn.getftime(f)
        if mtime > newest_mtime then
            newest, newest_mtime = f, mtime
        end
    end
    if not newest then
        vim.notify("No plan files in ~/.claude/plans", vim.log.levels.WARN)
        return
    end
    require("claude.panel").focus_edit_window()
    vim.cmd("edit " .. vim.fn.fnameescape(newest))
end

return M
