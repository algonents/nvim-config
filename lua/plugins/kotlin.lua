-- JetBrains kotlin-lsp (official, pre-alpha) via native vim.lsp.config.
-- Install: standalone Linux tarball from https://github.com/Kotlin/kotlin-lsp
-- extracted to ~/.local/opt/kotlin-lsp/, with bin/intellij-server symlinked
-- to ~/.local/bin/kotlin-lsp. Bundles its own JetBrains Runtime.
-- First open of a Gradle project triggers a build import — can take minutes.
vim.lsp.config("kotlin_lsp", {
    cmd = { "kotlin-lsp", "--stdio" },
    -- root_dir (not root_markers) so library sources opened from a jar://
    -- URI stay detached: the server only knows that URI as a compiled class,
    -- so hover/gd positions in the real source text would be wrong.
    root_dir = function(bufnr, on_dir)
        if vim.b[bufnr].library_source then return end
        local root = vim.fs.root(bufnr, {
            "settings.gradle.kts",
            "settings.gradle",
            "build.gradle.kts",
            "build.gradle",
            ".git",
        })
        if root then on_dir(root) end
    end,
    filetypes = { "kotlin" },
    capabilities = (function()
        local caps = vim.lsp.protocol.make_client_capabilities()
        local ok, cmp_lsp = pcall(require, "cmp_nvim_lsp")
        if ok then
            caps = vim.tbl_deep_extend("force", caps, cmp_lsp.default_capabilities())
        end
        return caps
    end)(),
})

vim.lsp.enable("kotlin_lsp")

-- kotlin-lsp imports the Gradle model once, at startup, and never re-imports.
-- After changing settings.gradle(.kts) or a module's build file (adding,
-- renaming or moving a module), the files you edit fall outside the stale
-- model and library symbols stop resolving — gd on an Android class returns
-- nothing. Neovim 0.11 has no built-in :LspRestart, so stop the clients and
-- re-fire the enable autocmd to attach a fresh server (which re-imports).
vim.api.nvim_create_user_command("KotlinLspRestart", function()
    local clients = vim.lsp.get_clients({ name = "kotlin_lsp" })
    for _, client in ipairs(clients) do
        client:stop()
    end
    vim.wait(10000, function()
        for _, client in ipairs(clients) do
            if not client:is_stopped() then return false end
        end
        return true
    end, 100)
    for _, buf in ipairs(vim.api.nvim_list_bufs()) do
        if vim.api.nvim_buf_is_loaded(buf) and vim.bo[buf].filetype == "kotlin" then
            vim.api.nvim_exec_autocmds("FileType", { group = "nvim.lsp.enable", buffer = buf })
        end
    end
    vim.notify("kotlin-lsp restarted — Gradle re-import runs in the background")
end, { desc = "Restart kotlin-lsp (re-import the Gradle model)" })

-- Definitions inside library jars come back as jar:// (or jrt:// for the
-- JDK) URIs, which Neovim can't read. Prefer the real source from a
-- -sources.jar / the Android SDK sources (lua/jvm_sources.lua); fall back to
-- the server's "decompile" command, which yields stubs with no bodies.
local jvm_sources = require("jvm_sources")
local hinted = {}
vim.api.nvim_create_autocmd("BufReadCmd", {
    pattern = { "jar:/*", "jrt:/*" },
    callback = function(ev)
        local function fill(text, filetype)
            vim.bo[ev.buf].readonly = false -- refill on :edit! (facade reload)
            vim.bo[ev.buf].modifiable = true
            vim.api.nvim_buf_set_lines(ev.buf, 0, -1, false, vim.split(text, "\n"))
            vim.bo[ev.buf].modified = false
            vim.bo[ev.buf].modifiable = false
            vim.bo[ev.buf].readonly = true
            vim.bo[ev.buf].filetype = filetype
        end

        local ok, text, ext_or_hint = pcall(jvm_sources.find, ev.match, jvm_sources.pending_symbol)
        if ok and text then
            vim.b[ev.buf].library_source = true -- keeps kotlin_lsp detached (root_dir)
            fill(text, ext_or_hint == "java" and "java" or "kotlin")
            return
        end
        if ok and ext_or_hint and not hinted[ext_or_hint] then
            hinted[ext_or_hint] = true -- once per kind of miss per session
            vim.notify("Showing decompiled stub: " .. ext_or_hint, vim.log.levels.INFO)
        end

        local client = vim.lsp.get_clients({ name = "kotlin_lsp" })[1]
        if not client then
            return
        end
        local response = client:request_sync("workspace/executeCommand", {
            command = "decompile",
            arguments = { ev.match },
        }, 5000, ev.buf)
        local result = response and response.result
        if not result or type(result.code) ~= "string" then
            vim.notify("kotlin-lsp: decompile failed for " .. ev.match, vim.log.levels.WARN)
            return
        end
        fill(result.code, result.language or "kotlin")
    end,
})

vim.api.nvim_create_user_command("GradleDownloadSources", function()
    jvm_sources.download(0)
end, { desc = "Download -sources.jar for the Gradle project's dependencies" })

return {}
