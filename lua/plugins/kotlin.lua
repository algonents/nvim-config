-- JetBrains kotlin-lsp (official, pre-alpha) via native vim.lsp.config.
-- Install: standalone Linux tarball from https://github.com/Kotlin/kotlin-lsp
-- extracted to ~/.local/opt/kotlin-lsp/, with bin/intellij-server symlinked
-- to ~/.local/bin/kotlin-lsp. Bundles its own JetBrains Runtime.
-- First open of a Gradle project triggers a build import — can take minutes.
vim.lsp.config("kotlin_lsp", {
    cmd = { "kotlin-lsp", "--stdio" },
    root_markers = {
        "settings.gradle.kts",
        "settings.gradle",
        "build.gradle.kts",
        "build.gradle",
        ".git",
    },
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
-- JDK) URIs, which Neovim can't read — the buffer stayed empty and the
-- cursor jump blew up. The server exposes a "decompile" command for exactly
-- this; fill the buffer with its output instead.
vim.api.nvim_create_autocmd("BufReadCmd", {
    pattern = { "jar:/*", "jrt:/*" },
    callback = function(ev)
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
        vim.api.nvim_buf_set_lines(ev.buf, 0, -1, false, vim.split(result.code, "\n"))
        vim.bo[ev.buf].modified = false
        vim.bo[ev.buf].modifiable = false
        vim.bo[ev.buf].readonly = true
        vim.bo[ev.buf].filetype = result.language or "kotlin"
    end,
})

return {}
