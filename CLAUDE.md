# Neovim Configuration

Personal Neovim config for hybrid Rust/C++ systems development.

## Structure

```
init.lua                  -- Bootstrap, settings, keymaps
lua/plugins/
  rust.lua                -- rustaceanvim (rust-analyzer + codelldb DAP adapter)
  cpp.lua                 -- clangd LSP via native vim.lsp.config (Neovim 0.11+)
  completion.lua          -- nvim-cmp with LSP, buffer, path, snippet sources
  debugger.lua            -- nvim-dap + nvim-dap-ui
  editor.lua              -- treesitter, telescope (fzf-native), neo-tree, toggleterm, gitsigns, which-key, trouble, tokyonight
```

## Plugin Stack

| Category       | Plugin                          | Notes                                      |
|----------------|---------------------------------|--------------------------------------------|
| Rust LSP       | `mrcjkb/rustaceanvim` v6        | rust-analyzer, clippy, cargo allFeatures   |
| C++ LSP        | native `vim.lsp.config`         | clangd with `--compile-commands-dir=build` |
| Completion     | `hrsh7th/nvim-cmp`              | LSP, buffer, path, LuaSnip sources        |
| Snippets       | `L3MON4D3/LuaSnip`             |                                            |
| Debugger       | `mfussenegger/nvim-dap`         | codelldb adapter for Rust and C/C++        |
| Debugger UI    | `rcarriga/nvim-dap-ui`          | Right panel (40 cols) + bottom REPL        |
| Treesitter     | `nvim-treesitter`               | rust, c, cpp, cmake, lua, vim, toml, json, md |
| File explorer  | `nvim-neo-tree/neo-tree.nvim`   | Left panel, 32 cols                        |
| Fuzzy finder   | `nvim-telescope/telescope.nvim` | With fzf-native for faster matching        |
| Git signs      | `lewis6991/gitsigns.nvim`       | Inline blame, hunk navigation              |
| Keymap help    | `folke/which-key.nvim`          | Keymap discovery popup                     |
| Diagnostics    | `folke/trouble.nvim`            | Cross-file diagnostics panel               |
| Terminal       | `akinsho/toggleterm.nvim`       | Horizontal, 3 slots                        |
| Theme          | `folke/tokyonight.nvim`         |                                            |

## Keymap Reference

| Key              | Action                  | Context     |
|------------------|-------------------------|-------------|
| `<Space>`        | Leader key              |             |
| `gd`             | Go to definition        | LSP         |
| `K`              | Hover docs              | LSP         |
| `<leader>fr`     | Find references         | LSP / Telescope |
| `<leader>rn`     | Rename symbol           | LSP         |
| `<leader>ca`     | Code action             | LSP         |
| `[d` / `]d`      | Prev/next diagnostic    | Diagnostics |
| `<leader>e`      | Show diagnostic float   | Diagnostics |
| `<leader>q`      | Diagnostics loclist     | Diagnostics |
| `<leader>ff`     | Find files              | Telescope   |
| `<leader>fg`     | Live grep               | Telescope   |
| `<leader>fb`     | Find buffers            | Telescope   |
| `<leader>fh`     | Help tags               | Telescope   |
| `<leader>db`     | Toggle breakpoint       | DAP         |
| `<leader>dc`     | Continue                | DAP         |
| `<leader>do`     | Step over               | DAP         |
| `<leader>di`     | Step into               | DAP         |
| `<leader>dO`     | Step out                | DAP         |
| `<leader>du`     | Toggle DAP UI           | DAP         |
| `<leader>dt`     | Terminate               | DAP         |
| `<leader>dw`     | Add watch expression    | DAP         |
| `<leader>ch`     | Switch header/source    | C++ (clangd)|
| `<leader>xx`     | Toggle diagnostics      | Trouble     |
| `<leader>xd`     | Buffer diagnostics      | Trouble     |
| `]h` / `[h`      | Next/prev git hunk      | Gitsigns    |
| `<leader>n`      | Toggle file tree        | Neo-tree    |
| `O` (in tree)    | Open file externally    | Neo-tree    |
| `<leader>i`      | Open current file externally | Editor |
| `<leader>t1/2/3` | Toggle terminal 1/2/3   | ToggleTerm  |
| `<leader>c1/2/3` | Toggle Claude 1/2/3 (right panel, swaps) | ToggleTerm |
| `<Up>/<Down>`    | Move by display line (wrapped) | Editor |
| `<Home>/<End>`   | Start/end of display line | Editor    |
| `<Esc>`          | Exit terminal mode      | Terminal    |
| `<C-\>`          | Toggle terminal         | ToggleTerm  |
| `<CR>`           | Confirm completion      | nvim-cmp    |
| `<Tab>/<S-Tab>`  | Navigate completion     | nvim-cmp    |
| `<C-Space>`      | Trigger completion      | nvim-cmp    |
| `<C-e>`          | Dismiss completion      | nvim-cmp    |

## C++ Projects

C++ projects using CMake need a `compile_commands.json` for clangd:

```shell
cmake -S <cmake-source-dir> -B build -DCMAKE_EXPORT_COMPILE_COMMANDS=ON
```

clangd is configured to look in `build/` by default.

## Neovim Directories

`NVIM_APPNAME` (default: `nvim`) controls where Neovim reads config, stores plugin data, and keeps state:

| Directory | Default path                       | Contents                                      |
|-----------|------------------------------------|-----------------------------------------------|
| Config    | `~/.config/{NVIM_APPNAME}/`        | `init.lua`, `lua/plugins/`, user configuration |
| Data      | `~/.local/share/{NVIM_APPNAME}/`   | Installed plugins, treesitter parsers, shada   |
| State     | `~/.local/state/{NVIM_APPNAME}/`   | Logs, undo history, swap files                 |

Set `NVIM_APPNAME` to run isolated configs side-by-side:

```shell
NVIM_APPNAME=nvim-web nvim
#             ^^^^^^^  ^^^
#           app name   nvim command
```

The app name can be anything (e.g. `web`, `nvim-web`, `systems`) — the `nvim-` prefix is just a naming convention.

## Conventions

- Plugin manager: lazy.nvim (auto-imports `lua/plugins/*.lua`)
- Leader: `<Space>`
- Format-on-save: Rust (`*.rs`) and C/C++ (`*.c`, `*.cpp`, `*.h`, `*.hpp`)
- DAP adapter: codelldb at `~/.local/opt/codelldb/extension/adapter/codelldb`
- Neovim 0.11+ required (uses native `vim.lsp.config` for C++)

## TODO

- [x] Add C++ DAP config — wire codelldb adapter for C++ debugging
- [x] Add `ClangdSwitchSourceHeader` keymap (`<leader>ch`) for switching between header/source files
- [x] Add `folke/which-key.nvim` for keymap discovery popup
- [x] Add `cmake` treesitter parser for CMakeLists.txt syntax highlighting
- [x] Add `folke/trouble.nvim` for a better diagnostics list across Rust and C++ files
