-- Telescope picker over every live Claude session on this machine (own
-- slots first). <CR> focuses an own slot, or resumes an external session in
-- the first free slot.
local M = {}

function M.pick()
    local ok, pickers = pcall(require, "telescope.pickers")
    if not ok then
        vim.notify("telescope.nvim is required for the sessions picker", vim.log.levels.WARN)
        return
    end
    local finders = require("telescope.finders")
    local conf = require("telescope.config").values
    local actions = require("telescope.actions")
    local action_state = require("telescope.actions.state")
    local panel = require("claude.panel")

    local results = require("claude.status").sessions()
    if #results == 0 then
        vim.notify("No Claude sessions running", vim.log.levels.INFO)
        return
    end
    panel.focus_edit_window()
    pickers.new({}, {
        prompt_title = "Claude sessions",
        finder = finders.new_table({
            results = results,
            entry_maker = function(sess)
                local where = sess.slot and ("Claude " .. sess.slot) or "external"
                local display = ("%-9s %-8s %-28s %s"):format(where, sess.state or "?", sess.name or sess.session_id:sub(1, 8), vim.fn.fnamemodify(sess.cwd or "", ":~"))
                return { value = sess, display = display, ordinal = display }
            end,
        }),
        sorter = conf.generic_sorter({}),
        attach_mappings = function(prompt_bufnr)
            actions.select_default:replace(function()
                local entry = action_state.get_selected_entry()
                actions.close(prompt_bufnr)
                if not entry then
                    return
                end
                local sess = entry.value
                if sess.slot then
                    panel.focus(sess.slot)
                else
                    panel.open_free({ "--resume", sess.session_id })
                end
            end)
            return true
        end,
    }):find()
end

return M
