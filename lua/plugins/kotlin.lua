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

return {}
