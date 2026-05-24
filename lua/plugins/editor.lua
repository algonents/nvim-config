return {
    {
        "nvim-telescope/telescope.nvim",
        dependencies = {
            "nvim-lua/plenary.nvim",
            { "nvim-telescope/telescope-fzf-native.nvim", build = "make" },
        },
        config = function()
            require("telescope").load_extension("fzf")
        end,
    },
    {
        "nvim-treesitter/nvim-treesitter",
        build = ":TSUpdate",
        config = function()
            require("nvim-treesitter").setup({
                ensure_installed = {
                    "rust",
                    "c",
                    "cpp",
                    "lua",
                    "vim",
                    "vimdoc",
                    "query",
                    "toml",
                    "json",
                    "markdown",
                    "markdown_inline",
                    "cmake",
                },
                highlight = { enable = true },
                indent = { enable = true },
            })
        end,
    },
    {
        "akinsho/toggleterm.nvim",
        version = "*",
        config = function()
            require("toggleterm").setup({
                direction = "horizontal",
                open_mapping = [[<c-\>]],
                shade_terminals = true,
                start_in_insert = true,
                insert_mappings = true,
                persist_size = true,
                persist_mode = true,
                close_on_exit = true,
                float_opts = {
                    border = "rounded",
                },
                -- Pin horizontal terminals to the full-width bottom regardless
                -- of which window had focus when the toggle fired.
                on_open = function(term)
                    if term.direction == "horizontal" then
                        vim.cmd("wincmd J")
                    end
                end,
            })
        end,
    },
    {
        "nvim-neo-tree/neo-tree.nvim",
        branch = "v3.x",
        dependencies = {
            "nvim-lua/plenary.nvim",
            "MunifTanjim/nui.nvim",
            "nvim-tree/nvim-web-devicons",
        },
        config = function()
            require("neo-tree").setup({
                filesystem = {
                    filtered_items = {
                        hide_dotfiles = false,
                        hide_gitignored = false,
                        hide_by_name = { "target" },
                    },
                    follow_current_file = {
                        enabled = true,
                    },
                    use_libuv_file_watcher = true,
                },
                window = {
                    position = "left",
                    width = 32,
                    mappings = {
                        ["O"] = {
                            function(state)
                                local node = state.tree:get_node()
                                if node and node.type == "file" then
                                    vim.ui.open(node.path)
                                end
                            end,
                            desc = "Open externally",
                        },
                    },
                },
            })
        end,
    },
    {
        "folke/tokyonight.nvim",
        priority = 1000,
        config = function()
            vim.cmd.colorscheme("tokyonight")
        end,
    },
    {
        "lewis6991/gitsigns.nvim",
        config = function()
            require("gitsigns").setup({
                signs = {
                    add = { text = "│" },
                    change = { text = "│" },
                    delete = { text = "_" },
                    topdelete = { text = "‾" },
                    changedelete = { text = "~" },
                },
                current_line_blame = true,
            })
        end,
    },
    {
        "folke/which-key.nvim",
        event = "VeryLazy",
        config = function()
            require("which-key").setup()
        end,
    },
    {
        "folke/trouble.nvim",
        dependencies = { "nvim-tree/nvim-web-devicons" },
        config = function()
            require("trouble").setup()
        end,
    },
}
