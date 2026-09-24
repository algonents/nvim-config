-- Live browser preview for markdown (GitHub-like rendering, scroll sync).
-- Runs a local node server; needs node on the PATH (already there for ts_ls).
-- Spec follows the plugin README's lazy.nvim recipe: mkdp_filetypes must be
-- set in init (before load), and the keymap goes through lazy's keys handler
-- so the first press loads the plugin and re-fires cleanly.
return {
    {
        "iamcco/markdown-preview.nvim",
        cmd = { "MarkdownPreviewToggle", "MarkdownPreview", "MarkdownPreviewStop" },
        ft = { "markdown" },
        build = "cd app && npm install",
        init = function()
            vim.g.mkdp_filetypes = { "markdown" }
        end,
        keys = {
            {
                "<leader>mp",
                "<cmd>MarkdownPreviewToggle<CR>",
                desc = "Toggle markdown preview",
                ft = "markdown",
            },
        },
    },
}
