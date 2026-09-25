# Neovim Configuration

Personal Neovim config for hybrid Rust/C++ systems development, plus
Kotlin/JVM and buildless JavaScript work (the `air` monorepo).

## Structure

```
init.lua                  -- Bootstrap, settings, keymaps
lua/plugins/
  rust.lua                -- rustaceanvim (rust-analyzer + codelldb DAP adapter)
  cpp.lua                 -- clangd LSP via native vim.lsp.config (Neovim 0.11+)
  kotlin.lua              -- JetBrains kotlin-lsp via native vim.lsp.config
  typescript.lua          -- typescript-language-server (ts_ls) via native vim.lsp.config
  completion.lua          -- nvim-cmp with LSP, buffer, path, snippet sources
  debugger.lua            -- nvim-dap + nvim-dap-ui
  editor.lua              -- treesitter, telescope (fzf-native), neo-tree, toggleterm, gitsigns, which-key, trouble, tokyonight
```

## Plugin Stack

| Category       | Plugin                          | Notes                                      |
|----------------|---------------------------------|--------------------------------------------|
| Rust LSP       | `mrcjkb/rustaceanvim` v6        | rust-analyzer, clippy, cargo allFeatures   |
| C++ LSP        | native `vim.lsp.config`         | clangd with `--compile-commands-dir=build` |
| Kotlin LSP     | native `vim.lsp.config`         | JetBrains kotlin-lsp (pre-alpha), standalone tarball |
| TS/JS LSP      | native `vim.lsp.config`         | typescript-language-server; also checks plain JS via project `jsconfig.json` |
| Completion     | `hrsh7th/nvim-cmp`              | LSP, buffer, path, LuaSnip sources        |
| Snippets       | `L3MON4D3/LuaSnip`             |                                            |
| Debugger       | `mfussenegger/nvim-dap`         | codelldb adapter for Rust and C/C++        |
| Debugger UI    | `rcarriga/nvim-dap-ui`          | Right panel (40 cols) + bottom REPL        |
| Treesitter     | `nvim-treesitter`               | rust, c, cpp, cmake, kotlin, lua, vim, toml, json, md |
| File explorer  | `nvim-neo-tree/neo-tree.nvim`   | Left panel, 32 cols                        |
| Fuzzy finder   | `nvim-telescope/telescope.nvim` | With fzf-native for faster matching        |
| Git signs      | `lewis6991/gitsigns.nvim`       | Inline blame, hunk navigation              |
| Keymap help    | `folke/which-key.nvim`          | Keymap discovery popup                     |
| Diagnostics    | `folke/trouble.nvim`            | Cross-file diagnostics panel               |
| Terminal       | `akinsho/toggleterm.nvim`       | Horizontal, 3 slots                        |
| Nested nvim    | `willothy/flatten.nvim`         | `git commit` in a terminal opens in a new tab in this nvim |
| MD preview     | `iamcco/markdown-preview.nvim`  | Live browser preview via local node server |
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
| `:Workspace`     | Re-open tree + terminal 1 + Claude 1 (opened automatically on startup) | Editor |
| `O` (in tree)    | Open file externally    | Neo-tree    |
| `E` (in tree)    | Expand/collapse subtree recursively | Neo-tree |
| `<leader>mp`     | Toggle markdown preview | Markdown    |
| `<leader>i`      | Open current file externally | Editor |
| `<leader>t1/2/3` | Toggle terminal 1/2/3   | ToggleTerm  |
| `<leader>c1/2/3` | Toggle Claude 1/2/3 (right panel, swaps) | ToggleTerm |
| `<Up>/<Down>`    | Move by display line (wrapped) | Editor |
| `<Home>/<End>`   | Start/end of display line | Editor    |
| `<A-Up/Down/Left/Right>` | Window navigation (also from terminal/TUI) | Editor |
| `<C-w><Up/Down/Left/Right>` | Window navigation (Normal mode, built-in) | Editor |
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

## Kotlin Projects

`kotlin.lua` uses the official JetBrains **kotlin-lsp** (pre-alpha). It is not
on npm or in distro repos — clean-machine install is a standalone tarball:

1. Download the standalone Linux zip from
   <https://github.com/Kotlin/kotlin-lsp> (bundles its own JetBrains Runtime —
   no local JDK needed to run it).
2. Extract to `~/.local/opt/kotlin-lsp/` (the archive unpacks to a versioned
   `kotlin-server-<build>/` directory).
3. Symlink the launcher onto the PATH under the name the config invokes:

```shell
ln -s ~/.local/opt/kotlin-lsp/kotlin-server-<build>/bin/intellij-server ~/.local/bin/kotlin-lsp
```

**EAP builds expire after ~40 days.** When the server suddenly dies with
"Client kotlin_lsp quit with exit code 7" (stderr: "This build of
intellij-server has expired"), it is not a config problem — install a newer
build. The GitHub RELEASES.md links go stale; the VS Code Marketplace
extension `JetBrains.kotlin-server` updates more often. Find its latest
version, get the bundled build number (`extension/server/build.txt` in the
vsix), then fetch the matching standalone tarball from
`https://download-cdn.jetbrains.com/language-server/kotlin-server/<build>/kotlin-server-<build>.tar.gz`,
extract next to the old one, and repoint the symlink.

Root markers are the Gradle settings/build files. First open of a Gradle
project triggers a full build import — expect minutes, not seconds; later
opens are fast.

## JavaScript / TypeScript Projects

`typescript.lua` runs **typescript-language-server** (`ts_ls`). Clean-machine
install (needs Node.js; binaries land in `~/.local/bin`):

```shell
npm install -g --prefix ~/.local typescript typescript-language-server
```

Plain-JS projects with no build step (e.g. `air/air-app`) opt into checking
via a `jsconfig.json` (`checkJs`) at the project root — that file is also the
root marker `ts_ls` attaches to. For diagnostics to match the project's
`npm run typecheck`, run `npm install` **in the project** once so its dev-only
type packages (`node_modules`) exist; the annotations themselves are
JSDoc-only, nothing is compiled.

## Committing from a Terminal

Running `git commit` in a `:terminal` (toggleterm) opens the message buffer in a
**new tab** in this Neovim instance — not a nested editor. Write and close it
(`:wq`) and git proceeds. Three pieces make this work, all required:

- `vim.env.EDITOR = "nvim"` (init.lua) — otherwise git falls back to `/usr/bin/vi`
  and `flatten.nvim` (which only intercepts `nvim`) never engages.
- `flatten.nvim` with `window = { open = "tab" }` — forwards the nested `nvim` to
  the host via `$NVIM` and opens the commit in its own tab.
- A `noswapfile` autocmd for `COMMIT_EDITMSG`/`MERGE_MSG`/`TAG_EDITMSG`/
  `git-rebase-todo` (init.lua) — a crashed commit otherwise leaves a stale swap in
  `.git/`, and the next commit opens the message read-only, silently dropping it so
  git aborts with "empty commit message".

If commit-from-terminal regresses, check those three. The `<Esc>` → exit-terminal
mapping (init.lua) is why a *nested* editor is painful, so the goal is to never nest.

## Startup Layout

A `VimEnter` autocmd (init.lua) opens the workspace layout on every launch:
neo-tree on the left, terminal 1 along the bottom, Claude 1 as a full-height
right column, with focus returned to the editor. It reuses the `<leader>n`,
`<leader>t1` and `<leader>c1` toggles, so closing a panel and re-toggling it
behaves as before; `:Workspace` restores any panel that was closed.

The layout is skipped when there is no UI (`--headless`), in diff mode, and
when Neovim is launched as `$EDITOR` by git (commit message, rebase todo),
so a commit from an outside terminal still opens as a plain message buffer.

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
- Format-on-save: Rust (`*.rs`), C/C++ (`*.c`, `*.cpp`, `*.h`, `*.hpp`), Kotlin (`*.kt`, `*.kts`)
- DAP adapter: codelldb at `~/.local/opt/codelldb/extension/adapter/codelldb`
- Neovim 0.11+ required (uses native `vim.lsp.config` for C++, Kotlin, TS/JS)

## Roadmap

Planned improvements (C++ experience, etc.) live in [docs/ROADMAP.md](docs/ROADMAP.md).

## TODO

- [x] Add C++ DAP config — wire codelldb adapter for C++ debugging
- [x] Add `ClangdSwitchSourceHeader` keymap (`<leader>ch`) for switching between header/source files
- [x] Add `folke/which-key.nvim` for keymap discovery popup
- [x] Add `cmake` treesitter parser for CMakeLists.txt syntax highlighting
- [x] Add `folke/trouble.nvim` for a better diagnostics list across Rust and C++ files
