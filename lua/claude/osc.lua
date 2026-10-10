-- OSC 7501 "Program Status Protocol" parsing (pure; no Neovim state).
--
-- Claude Code >= 2.1.295 probes the terminal with `ESC ] 7501 ; ? ST` and,
-- when the terminal answers, reports its state with
-- `ESC ] 7501 ; state=working:kind=permission:title=<b64>:app=claude-code ST`.
-- Spec: https://www.superlogical.com/rex/docs/build/program-status
local M = {}

M.PREFIX = "\27]7501;"
-- Capability reply to the probe. Must reach the program before Neovim's own
-- primary-DA answer (which Claude uses as the "no reply" sentinel); replying
-- synchronously from the TermRequest autocmd achieves that.
M.CAPS = "\27]7501;?:states=idle,working,done,blocked,error:kinds=permission,question,auth\27\\"

M.STATES = { idle = true, working = true, done = true, blocked = true, error = true, clear = true }

--- Parse a TermRequest sequence.
---@param seq string
---@return nil|"probe"|table  nil when not an OSC 7501 sequence; "probe" for the
--- capability query; otherwise { state=, kind=, progress=, id=, title=, msg=, app= }
function M.parse(seq)
    if type(seq) ~= "string" or seq:sub(1, #M.PREFIX) ~= M.PREFIX then
        return nil
    end
    local body = seq:sub(#M.PREFIX + 1)
    body = body:gsub("\27\\$", "")
    body = body:gsub("\7$", "")
    if body == "?" then
        return "probe"
    end
    local r = {}
    for field in body:gmatch("[^:]+") do
        local k, v = field:match("^(%a+)=(.*)$")
        if k then
            r[k] = v
        end
    end
    if not r.state then
        return nil
    end
    r.progress = tonumber(r.progress)
    for _, k in ipairs({ "title", "msg" }) do
        if r[k] and r[k] ~= "" then
            local ok, decoded = pcall(vim.base64.decode, r[k])
            if ok and decoded then
                r[k] = decoded
            end
        end
    end
    return r
end

return M
