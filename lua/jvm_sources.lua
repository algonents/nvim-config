-- Real library sources for `jar://…!/pkg/Cls.class` locations returned by
-- kotlin-lsp. The server only ever points at compiled classes, even when a
-- -sources.jar sits in the Gradle cache, and its decompiler yields stubs
-- whose bodies are `/* compiled code */`. This module maps a class to its
-- source file instead:
--
--   1. read the class file's SourceFile attribute (e.g. MaterialThemeKt ->
--      MaterialTheme.kt) and combine it with the package path;
--   2. android.jar (SDK platform) -> <sdk>/sources/android-N/<pkg>/<file>;
--   3. anything else -> an index of every *-sources.jar in the Gradle cache.
--      Multiplatform jars prefix entries with the source set
--      (commonMain/, androidMain/…), so entries are indexed without it.
--
-- Sources are fetched with :GradleDownloadSources (Gradle deps) and
-- `sdkmanager "sources;android-N"` (platform classes).
local M = {}

local GRADLE_FILES = vim.fs.normalize("~/.gradle/caches/modules-2/files-2.1")
local INIT_SCRIPT = vim.fs.joinpath(vim.fn.stdpath("config"), "gradle", "download-sources.gradle")
-- Source sets preferred when one jar holds the same file several times.
local SOURCE_SET_RANK = { androidMain = 1, jvmAndroidMain = 2, jvmMain = 3, commonMain = 4 }

local function run(cmd)
    local r = vim.system(cmd, { text = false }):wait()
    return r.code == 0 and r.stdout or nil
end

-- SourceFile attribute of a class file, by walking its constant pool.
local function source_file_attr(bytes)
    if not bytes or #bytes < 10 or bytes:sub(1, 4) ~= "\202\254\186\190" then return nil end
    local pos = 9
    local function u1() local b = bytes:byte(pos); pos = pos + 1; return b end
    local function u2() local a, b = bytes:byte(pos, pos + 1); pos = pos + 2; return a * 256 + b end
    local function u4() local v = u2() * 65536; return v + u2() end
    local utf8 = {}
    local count = u2()
    local i = 1
    while i < count do
        local tag = u1()
        if tag == 1 then
            local len = u2()
            utf8[i] = bytes:sub(pos, pos + len - 1)
            pos = pos + len
        elseif tag == 5 or tag == 6 then pos = pos + 8; i = i + 1 -- long/double: two slots
        elseif tag == 3 or tag == 4 or (tag >= 9 and tag <= 12) or tag == 17 or tag == 18 then pos = pos + 4
        elseif tag == 15 then pos = pos + 3
        elseif tag == 7 or tag == 8 or tag == 16 or tag == 19 or tag == 20 then pos = pos + 2
        else return nil end
        i = i + 1
    end
    pos = pos + 6            -- access_flags, this_class, super_class
    pos = pos + 2 * u2()     -- interfaces
    for _ = 1, 2 do          -- fields, then methods: skip their attributes
        for _ = 1, u2() do
            pos = pos + 6
            for _ = 1, u2() do pos = pos + 2; pos = pos + u4() end
        end
    end
    for _ = 1, u2() do
        local name = utf8[u2()]
        local len = u4()
        if name == "SourceFile" then return utf8[u2()] end
        pos = pos + len
    end
    return nil
end

-- key "pkg/path/File.kt" -> list of { jar = …, entry = …, rank = … }
local index, index_jar_count
local function sources_jars()
    return vim.fn.globpath(GRADLE_FILES, "*/*/*/*/*-sources.jar", false, true)
end
local function build_index(jars)
    index, index_jar_count = {}, #jars
    for _, jar in ipairs(jars) do
        for entry in (run({ "unzip", "-Z1", jar }) or ""):gmatch("[^\n]+") do
            if entry:match("%.kt$") or entry:match("%.java$") then
                local first, rest = entry:match("^([^/]+)/(.+)$")
                local add = function(key, rank)
                    index[key] = index[key] or {}
                    table.insert(index[key], { jar = jar, entry = entry, rank = rank })
                end
                add(entry, 0)
                if first and first:match("Main$") then add(rest, SOURCE_SET_RANK[first] or 5) end
                -- Some jars (kotlinx.coroutines) omit package directories
                -- (commonMain/Builders.common.kt); also index by file name.
                add("#" .. vim.fs.basename(entry), SOURCE_SET_RANK[first] or 5)
            end
        end
    end
end

-- Prefer the sources jar of the same artifact as the binary jar.
local function artifact_hint(binary_jar)
    local art, ver = binary_jar:match("/files%-2%.1/[^/]+/([^/]+)/([^/]+)/[^/]+/[^/]+$")
    if art then return art .. "-" .. ver end
    return binary_jar:match("/transformed/([^/]+)/jars/[^/]+$") -- e.g. activity-1.10.0
end

local function pick(candidates, hint)
    local function score(c)
        local base = vim.fs.basename(c.jar):gsub("%-sources%.jar$", "")
        local s = c.rank
        if hint and base == hint then s = s - 100
        elseif hint and base:find(hint:match("^(.-)%-") or hint, 1, true) == 1 then s = s - 50 end
        return s
    end
    table.sort(candidates, function(a, b) return score(a) < score(b) end)
    return candidates[1]
end

-- First line declaring `symbol` in `lines` (Kotlin or Java), as {row, col}.
local function find_decl(lines, symbol, ext)
    if not symbol or symbol == "" then return nil end
    local sym = vim.fn.escape(symbol, [[\/.*$^~[]])
    local patterns = ext == "java" and {
        [[\v<(class|interface|enum|record)\s+]] .. sym .. [[>]],
        [[\v^\s*(\@\S+\s+)*(public|protected|private|static|final|abstract|synchronized|native|default)>[^=;]*<]] .. sym .. [[\s*\(]],
    } or {
        [[\v^\s*(\@\S+\s+)*(\w+\s+)*(class|interface|object|fun|val|var|typealias)>[^=({]*<]] .. sym .. [[>]],
    }
    for _, pat in ipairs(patterns) do
        local re = vim.regex(pat)
        for row, line in ipairs(lines) do
            if re:match_str(line) then
                local col = vim.regex([[\v<]] .. sym .. [[>]]):match_str(line) or 0
                return { row, col }
            end
        end
    end
    return nil
end

--- Cursor position of `symbol`'s declaration in a library-source buffer.
function M.locate(buf, symbol)
    local ext = vim.bo[buf].filetype == "java" and "java" or "kt"
    return find_decl(vim.api.nvim_buf_get_lines(buf, 0, -1, false), symbol, ext)
end

--- Source text for a jar URI, or nil. Returns text, extension ("kt"/"java").
-- Symbol name `gd` was invoked on, set by the gd wrapper (init.lua) just
-- before the jar:// buffer loads. Picks between multifile-facade parts.
M.pending_symbol = nil

function M.find(uri, symbol)
    local jar, class = uri:match("^jar:/+(.-%.jar)!/(.+%.class)$")
    if not jar then return nil end
    jar = "/" .. jar
    local pkg = class:match("^(.*)/[^/]+$") or ""
    local prefix = pkg ~= "" and pkg .. "/" or ""

    -- Source files behind this class: its own SourceFile, plus those of
    -- multifile-facade parts (BuildersKt -> BuildersKt__Builders_commonKt
    -- -> Builders.common.kt), whose facade has no single source file.
    local files, seen = {}, {}
    local function add_class(entry)
        local f = source_file_attr(run({ "unzip", "-p", jar, entry }))
        if f and not seen[f] then seen[f] = true; table.insert(files, f) end
    end
    add_class(class)
    local part_prefix = class:gsub("%.class$", "") .. "__"
    for entry in (run({ "unzip", "-Z1", jar }) or ""):gmatch("[^\n]+") do
        if entry:sub(1, #part_prefix) == part_prefix and not entry:find("$", 1, true) then add_class(entry) end
    end
    if #files == 0 then return nil end

    local sdk, level = jar:match("^(.*)/platforms/(android%-[^/]+)/android%.jar$")
    local function read_candidate(file)
        local ext = file:match("%.(%w+)$")
        if sdk then
            local path = vim.fs.joinpath(sdk, "sources", level, prefix .. file)
            if vim.uv.fs_stat(path) then return table.concat(vim.fn.readfile(path), "\n"), ext end
            return nil
        end
        local hint = artifact_hint(jar)
        local candidates = index[prefix .. file]
        if candidates then
            local best = pick(vim.deepcopy(candidates), hint)
            return run({ "unzip", "-p", best.jar, best.entry }), ext
        end
        -- By file name, restricted to the same artifact, verified by the
        -- file's `package` line.
        local want = pkg:gsub("/", ".")
        local by_name = vim.deepcopy(index["#" .. file] or {})
        table.sort(by_name, function(a, b) return a.rank < b.rank end)
        for _, c in ipairs(by_name) do
            local base = vim.fs.basename(c.jar):gsub("%-sources%.jar$", "")
            if hint and base == hint then
                local text = run({ "unzip", "-p", c.jar, c.entry })
                local declared = text and text:match("\npackage%s+([%w_.]+)") or (text and text:match("^package%s+([%w_.]+)"))
                if declared == want then return text, ext end
            end
        end
        return nil
    end

    if not sdk then
        local jars = sources_jars()
        if not index or index_jar_count ~= #jars then build_index(jars) end
    end
    local first_text, first_ext
    for _, file in ipairs(files) do
        local text, ext = read_candidate(file)
        if text then
            if not symbol or #files == 1 or find_decl(vim.split(text, "\n"), symbol, ext) then
                return text, ext
            end
            first_text, first_ext = first_text or text, first_ext or ext
        end
    end
    if first_text then return first_text, first_ext end
    if sdk then
        return nil, ("no Android SDK sources — run: sdkmanager \"sources;%s\""):format(level)
    end
    return nil, "no sources jar in the Gradle cache — run :GradleDownloadSources"
end

--- Run the download-sources init script in the Gradle project of `buf`.
function M.download(buf)
    local root = vim.fs.root(buf or 0, { "gradlew" })
    if not root then
        vim.notify("GradleDownloadSources: no gradlew above this file", vim.log.levels.WARN)
        return
    end
    vim.notify("Downloading dependency sources (" .. vim.fs.basename(root) .. ")…")
    vim.system({ "./gradlew", "-q", "--init-script", INIT_SCRIPT, "downloadSources" }, { cwd = root, text = true },
        vim.schedule_wrap(function(r)
            index = nil -- rebuild on next lookup
            if r.code == 0 then
                vim.notify(vim.trim(r.stdout ~= "" and r.stdout or "Sources downloaded"))
            else
                vim.notify("GradleDownloadSources failed:\n" .. (r.stderr or ""), vim.log.levels.ERROR)
            end
        end))
end

M._source_file_attr = source_file_attr -- for tests
return M
