-- Jump-to-match search for the neo-tree filesystem tree (`/` in the tree).
--
-- neo-tree's own fuzzy finder replaces the tree with a flat result list.
-- Here the tree stays as it is: as you type, the cursor moves to the most
-- probable match anywhere below the root, expanding the folders on the way.
-- Folders the search opened are collapsed again when the match moves
-- elsewhere, so only the path to the final match is left open. Folders you
-- expanded yourself are never touched.
--
-- Candidates are the files under the root plus their folders, as listed by
-- `rg --files` (so .gitignored trees such as node_modules or build output
-- don't drown the matches); without rg, a directory walk that skips .git,
-- node_modules and target. A query without `/` is matched against names,
-- one with `/` against relative paths. Equal scores go to the shallower
-- entry.
local M = {}

local last -- the last accepted search, stepped through by n / N

-- Beyond this (a Yocto build tree lists millions of files) matching on every
-- keystroke lags, so the search covers only the first MAX_FILES.
local MAX_FILES = 100000

-- Calls done(files, truncated) on the main loop; rg runs in the background
-- so the prompt opens at once.
local function list_files(root, done)
    local files, truncated = {}, false
    if vim.fn.executable("rg") ~= 1 then
        local skip = { [".git"] = true, node_modules = true, target = true }
        local walk = vim.fs.dir(root, {
            depth = 32,
            skip = function(dir) return not skip[vim.fs.basename(dir)] end,
        })
        for rel, type in walk do
            if #files == MAX_FILES then
                truncated = true
                break
            end
            if type == "file" then files[#files + 1] = rel end
        end
        return done(files, truncated)
    end
    local rest, proc = "", nil
    proc = vim.system({ "rg", "--files", "--hidden", "--glob", "!.git/" }, {
        cwd = root,
        text = true,
        stdout = function(_, data)
            if not data or truncated then return end
            data = rest .. data
            rest = data:match("[^\n]*$")
            for line in data:sub(1, #data - #rest):gmatch("[^\n]+") do
                if #files == MAX_FILES then
                    truncated = true
                    proc:kill("sigterm")
                    return
                end
                files[#files + 1] = line
            end
        end,
    }, function()
        vim.schedule(function() done(files, truncated) end)
    end)
end

local function build_entries(files)
    local seen, entries = {}, {}
    local function add(rel)
        seen[rel] = true
        local _, depth = rel:gsub("/", "")
        entries[#entries + 1] = { rel = rel, name = vim.fs.basename(rel), depth = depth }
    end
    for _, rel in ipairs(files) do
        add(rel)
        local dir = vim.fs.dirname(rel)
        while dir ~= "." and not seen[dir] do
            add(dir)
            dir = vim.fs.dirname(dir)
        end
    end
    -- matchfuzzy keeps list order for equal scores.
    table.sort(entries, function(a, b)
        if a.depth ~= b.depth then return a.depth < b.depth end
        return a.rel < b.rel
    end)
    -- Plain string lists: matchfuzzy is about twice as fast on them as on
    -- dicts with a key.
    local e = { rels = {}, names = {}, by_name = {} }
    for i, entry in ipairs(entries) do
        e.rels[i], e.names[i] = entry.rel, entry.name
        local same = e.by_name[entry.name] or {}
        same[#same + 1] = i
        e.by_name[entry.name] = same
    end
    return e
end

-- Relative paths of the matches, best first.
local function rank(e, query)
    if query == "" then return {} end
    if query:find("/", 1, true) then return vim.fn.matchfuzzy(e.rels, query) end
    -- Equal names score equally and come back in list order, so the k-th
    -- copy of a name is its k-th entry.
    local used, out = {}, {}
    for _, name in ipairs(vim.fn.matchfuzzy(e.names, query)) do
        local k = (used[name] or 0) + 1
        used[name] = k
        out[#out + 1] = e.rels[e.by_name[name][k]]
    end
    return out
end

local function expanded(state)
    local set = {}
    for _, id in ipairs(require("neo-tree.ui.renderer").get_expanded_nodes(state.tree)) do set[id] = true end
    return set
end

-- group_empty_dirs merges a folder whose only child is a folder into that
-- child, so the folder has no node of its own: land on the merged one.
local function node_id(state, path)
    while not state.tree:get_node(path) do
        local only, count = nil, 0
        for name, type in vim.fs.dir(path) do
            count = count + 1
            only = type == "directory" and name or nil
        end
        if count ~= 1 or not only then break end
        path = path .. "/" .. only
    end
    return path
end

-- Put the tree cursor on path (without focusing the tree window), first
-- collapsing what this search opened that is not on the way there.
local function show(s, path)
    local state = s.state
    local renderer = require("neo-tree.ui.renderer")
    local before = expanded(state)
    local function focus()
        local changed = false
        for id in pairs(s.opened) do
            if path:sub(1, #id + 1) ~= id .. "/" then
                local node = state.tree:get_node(id)
                if node and node:is_expanded() then
                    node:collapse()
                    changed = true
                end
                s.opened[id] = nil
            end
        end
        if changed then renderer.redraw(state) end
        renderer.focus_node(state, node_id(state, path), true)
        for id in pairs(expanded(state)) do
            if not before[id] then s.opened[id] = true end
        end
    end
    if state.tree:get_node(path) then
        focus()
    else
        -- Not loaded yet: scan the folders down to it, then focus.
        require("neo-tree.sources.filesystem.lib.fs_scan").get_items(state, nil, path, focus, false)
    end
end

local function step(s, delta)
    if #s.matches == 0 then return end
    s.index = (s.index - 1 + delta) % #s.matches + 1
    show(s, s.root .. "/" .. s.matches[s.index])
end

function M.start(state)
    if not state.tree or not vim.api.nvim_win_is_valid(state.winid or -1) then return end
    local cursor = state.tree:get_node()
    local s = {
        state = state,
        root = state.path,
        entries = nil, -- filled in once the file list arrives
        matches = {},
        index = 0,
        opened = {},
        origin = cursor and cursor:get_id(),
    }

    local buf = vim.api.nvim_create_buf(false, true)
    vim.bo[buf].buftype = "prompt" -- nvim-cmp stays off in prompt buffers
    vim.bo[buf].bufhidden = "wipe"
    vim.fn.prompt_setprompt(buf, "/")
    local win = vim.api.nvim_open_win(buf, true, {
        relative = "win",
        win = state.winid,
        row = math.max(vim.api.nvim_win_get_height(state.winid) - 3, 0),
        col = 0,
        width = math.max(vim.api.nvim_win_get_width(state.winid) - 2, 10),
        height = 1,
        style = "minimal",
        border = "rounded",
        title = " Jump to ",
    })

    local function query()
        return (vim.api.nvim_buf_get_lines(buf, 0, 1, false)[1] or ""):sub(2)
    end
    local function footer()
        local text = #s.matches > 0 and (" %d/%d "):format(s.index, #s.matches)
            or (query() ~= "" and " no match " or "")
        vim.api.nvim_win_set_config(win, { footer = text, footer_pos = "right" })
    end
    local function move(delta)
        step(s, delta)
        footer()
    end

    local timer = assert(vim.uv.new_timer())
    local done = false
    local function finish(accept)
        if done then return end
        done = true
        timer:stop()
        timer:close()
        vim.cmd.stopinsert()
        if vim.api.nvim_win_is_valid(win) then vim.api.nvim_win_close(win, true) end
        if not vim.api.nvim_win_is_valid(state.winid) then return end
        vim.api.nvim_set_current_win(state.winid)
        if accept and s.index > 0 then
            last = s
        elseif s.origin then
            show(s, s.origin) -- also collapses everything the search opened
        end
    end

    local function update()
        if done or not s.entries then return end
        s.matches = rank(s.entries, query())
        s.index = 0
        if #s.matches > 0 then move(1) else footer() end
    end

    vim.api.nvim_create_autocmd("TextChangedI", {
        buffer = buf,
        callback = function() timer:start(40, 0, vim.schedule_wrap(update)) end,
    })
    vim.api.nvim_create_autocmd("BufLeave", { buffer = buf, once = true, callback = function() finish(false) end })
    local function map(lhs, fn) vim.keymap.set("i", lhs, fn, { buffer = buf }) end
    map("<CR>", function() finish(true) end)
    map("<Esc>", function() finish(false) end)
    map("<C-c>", function() finish(false) end)
    for _, lhs in ipairs({ "<Tab>", "<C-n>", "<Down>" }) do map(lhs, function() move(1) end) end
    for _, lhs in ipairs({ "<S-Tab>", "<C-p>", "<Up>" }) do map(lhs, function() move(-1) end) end
    vim.cmd.startinsert()

    list_files(s.root, function(files, truncated)
        s.entries = build_entries(files)
        if truncated then
            vim.notify(("Tree search covers the first %d files only"):format(MAX_FILES), vim.log.levels.WARN)
        end
        update() -- for whatever was typed while the list was loading
    end)
end

-- n / N in the tree: the next / previous match of the last search.
function M.step(state, delta)
    if not last or last.root ~= state.path or #last.matches == 0 then
        vim.notify("No tree search to repeat (/ searches)", vim.log.levels.INFO)
        return
    end
    last.state = state
    step(last, delta)
    vim.api.nvim_echo({ { ("[%d/%d] %s"):format(last.index, #last.matches, last.matches[last.index]) } }, false, {})
end

return M
