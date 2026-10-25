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
lua/jvm_sources.lua       -- real library sources for jar:// class locations (gd)
gradle/download-sources.gradle -- init script behind :GradleDownloadSources
  typescript.lua          -- typescript-language-server (ts_ls) via native vim.lsp.config
  completion.lua          -- nvim-cmp with LSP, buffer, path, snippet sources
  debugger.lua            -- nvim-dap + nvim-dap-ui
  editor.lua              -- treesitter, telescope (fzf-native), neo-tree, toggleterm, gitsigns, which-key, trouble, tokyonight
lua/claude/               -- Claude Code integration: panels, live status, agent map, mentions (see below)
claude/hook.sh            -- Claude Code hook that feeds lua/claude/hooks.lua
tests/claude_*            -- headless smoke tests for lua/claude and hook.sh
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
| Treesitter     | `nvim-treesitter` (`main`)      | rust, c/cpp, cmake, kotlin, java, groovy, xml, js/ts, lua, toml, json, yaml, md; needs `tree-sitter` CLI |
| File explorer  | `nvim-neo-tree/neo-tree.nvim`   | Left panel, 32 cols                        |
| Fuzzy finder   | `nvim-telescope/telescope.nvim` | With fzf-native for faster matching        |
| Git signs      | `lewis6991/gitsigns.nvim`       | Inline blame, hunk navigation              |
| Keymap help    | `folke/which-key.nvim`          | Keymap discovery popup                     |
| Diagnostics    | `folke/trouble.nvim`            | Cross-file diagnostics panel               |
| Terminal       | `akinsho/toggleterm.nvim`       | Only behind `<C-\>`; terminals 1-3 and Claude 1-3 are plain `:terminal` buffers (init.lua, lua/claude) |
| Nested nvim    | `willothy/flatten.nvim`         | `git commit` in a terminal opens in a new tab in this nvim |
| MD preview     | `iamcco/markdown-preview.nvim`  | Live browser preview via local node server |
| Theme          | `folke/tokyonight.nvim`         |                                            |

## Keymap Reference

| Key              | Action                  | Context     |
|------------------|-------------------------|-------------|
| `<Space>`        | Leader key              |             |
| `gd`             | Go to definition (library code opens as real source when available) | LSP |
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
| `<M-p>` (in picker) | Toggle preview (full-width results) | Telescope |
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
| `:GradleDownloadSources` | Fetch dependency `-sources.jar` files for `gd` | Kotlin |
| `:KotlinLspRestart` | Restart kotlin-lsp (re-import the Gradle model) | Kotlin |
| `:Workspace`     | Re-open tree + terminal 1 + Claude 1 (opened automatically on startup) | Editor |
| `O` (in tree)    | Open file externally    | Neo-tree    |
| `E` (in tree)    | Expand/collapse subtree recursively | Neo-tree |
| `<leader>mp`     | Toggle markdown preview | Markdown    |
| `<leader>i`      | Open current file externally | Editor |
| `<leader>t1/2/3` | Toggle terminal 1/2/3 (bottom row) | Terminal |
| `<leader>c1/2/3` | Toggle Claude 1/2/3 (right column; extra slots stack below) | Claude |
| `<leader>cc` / `<A-c>` | Focus Claude / back to the editor (works from inside Claude) | Claude |
| `<leader>cs` / `<leader>cS` | Mention current file / Visual selection (`@path#L5-10`) in the prompt; `S` also focuses Claude | Claude |
| `<leader>cm`     | Agent map: slot states, subagents, background tasks, other sessions | Claude |
| `<leader>cl`     | Sessions picker (own slots + other Claude sessions; resume external ones) | Claude |
| `<leader>cr` / `<leader>cC` | `claude --resume` / `claude --continue` in a free slot | Claude |
| `<leader>cp`     | Open the newest `~/.claude/plans/*.md` | Claude |
| `<leader>cx`     | Stop the current/last Claude slot | Claude |
| `@` (in tree)    | Mention the file under the cursor in Claude | Neo-tree |
| `:Claude [n] [args]` | Toggle slot n, or launch with CLI args (`:Claude 2 --resume`) | Claude |
| `:ClaudeMap` / `:ClaudePlan` | Command forms of `<leader>cm` / `<leader>cp` | Claude |
| `:ClaudeHooksCheck` | Verify the hooks in `~/.claude/settings.json` | Claude |
| `<Up>/<Down>`    | Move by display line (wrapped) | Editor |
| `<Home>/<End>`   | Start/end of display line | Editor    |
| `<A-Up/Down/Left/Right>` | Window navigation by geometry; returns to the window you came from (also from terminal/TUI) | Editor |
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
kotlin-server has expired"), it is not a config problem — install a newer
build. `kotlin-lsp --version` still prints fine on an expired build; only
`intellij-server --stdio` exits 7. To update:

1. Take the newest `kotlin-server-<build>.tar.gz` link from
   <https://github.com/Kotlin/kotlin-lsp/blob/main/RELEASES.md>. If that
   file lags, the VS Code Marketplace extension `JetBrains.kotlin-server`
   is updated first; its vsix is a zip with the build number in
   `extension/server/build.txt` (370 MB, no HTTP range support), and the
   tarball then lives at
   `https://download.jetbrains.com/language-server/kotlin-server/<build>/kotlin-server-<build>.tar.gz`
   (the `download-cdn.jetbrains.com` host answers 404 for these).
2. Verify with the `.sha256` next to it, extract into
   `~/.local/opt/kotlin-lsp/`, and repoint the `~/.local/bin/kotlin-lsp`
   symlink. Delete the old build directory once the new one works.

Root markers are the Gradle settings/build files. First open of a Gradle
project triggers a full build import — expect minutes, not seconds; later
opens are fast.

**The Gradle model is imported once, at server start, and never refreshed.**
After adding, renaming or moving a module (editing `settings.gradle.kts` or a
module's build file), the edited files fall outside the stale model and
library symbols stop resolving — `gd` on an Android/AndroidX class returns
nothing while project-local symbols may still work. Run `:KotlinLspRestart`
(Neovim 0.11 has no built-in `:LspRestart`) to attach a fresh server, which
re-imports.

### Android

Android Gradle projects (e.g. `air/air-viewer`) need nothing extra: kotlin-lsp
imports AGP modules, including the platform `android.jar` from the SDK named
in `local.properties` (`sdk.dir`). Build once (`./gradlew assembleDebug`) so the
generated jars exist; otherwise the server warns it "Couldn't resolve"
`android:r` and the app classes jar, and `R.*` references stay unresolved.
`AndroidManifest.xml`, resource XML, `*.gradle.kts` and `libs.versions.toml`
are highlighted by the xml, kotlin and toml parsers.

### Library sources

kotlin-lsp always answers `gd` into a library with a compiled `.class`
location, even when a `-sources.jar` is cached, and its decompiler produces
stubs whose bodies are `/* compiled code */`. The `jar://` handler in
`kotlin.lua` first asks `lua/jvm_sources.lua` for the real file:

- it reads the class file's `SourceFile` attribute (multifile facades such as
  `BuildersKt` are resolved through their `__` part classes);
- SDK platform classes come from `<sdk>/sources/android-N/`;
- everything else from an index of every `*-sources.jar` in
  `~/.gradle/caches/modules-2` (source-set prefixes like `commonMain/` and
  jars without package directories are handled).

The `gd` wrapper in `init.lua` then puts the cursor on the declaration (the
server's position refers to the stub). Source buffers are read-only and have
no LSP attached; when no source is found, the decompiled stub is shown with a
one-time hint. To fetch sources:

```shell
:GradleDownloadSources                               # per Gradle project (init script in gradle/)
sdkmanager "sources;android-35"                      # Android platform classes
```

## Tree-sitter

`nvim-treesitter` is on its `main` branch, which differs from the old
`master` API: `setup()` takes no parser list and enables nothing. `editor.lua`
installs the parser list itself and starts highlighting from a `FileType`
autocmd. Parsers are compiled by the **`tree-sitter` CLI** (plus a C
compiler); without it every install fails with `ENOENT ... 'tree-sitter'` and
buffers silently fall back to regex syntax. Clean-machine install:

```shell
cargo install --locked tree-sitter-cli
```

Parsers land in `~/.local/share/nvim/site/parser/`. `:TSUpdate` updates them.

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

## Claude Code integration

`lua/claude/` turns the Claude panels into something closer to the VS Code
extension: each slot shows what its session is doing, hidden slots announce
when they need input or finish, subagents and background tasks are listed in
an agent map, and files/selections can be pushed into the prompt.

**Status comes from Claude itself.** Claude Code >= 2.1.295 speaks the
Program Status Protocol (OSC 7501): on start it probes the terminal and, if
answered, reports `working` / `idle` / `done` / `blocked` (with
`kind=permission|question|auth`), progress and a title. `lua/claude/init.lua`
answers the probe from a `TermRequest` autocmd (the reply must be sent
synchronously, before Neovim's own device-attributes answer, or Claude treats
the terminal as unsupported) and parses the reports (`osc.lua`) into
`status.lua`. Nothing to configure; needs no hooks. If a slot's winbar never
leaves "starting", check `claude --version` and that
`CLAUDE_CODE_DISABLE_TERMINAL_TITLE` is unset.

**Where it shows.** Claude windows get a winbar
(`● Claude 1 working 2m · <title>`). The focused window's statusline carries
one badge per live slot (`C1 ● 2m  C2 ◆ perm  C3 ✓  ⛬2`), colored like VS
Code's dots: blue = waiting for permission/input, orange = finished while the
slot was hidden. `vim.notify` fires on every `blocked` and on `done` when the
slot is not focused. `<leader>cm` opens the agent map.

**Subagents, tasks, sessions come from hooks.** `claude/hook.sh` is a
bash+jq hook that keeps `$XDG_RUNTIME_DIR/claude-nvim/<session_id>.json`
(session identity, running agents, background tasks, to-dos, last tool).
`hooks.lua` watches that directory with `vim.uv.new_fs_event`. Sessions
launched from a panel are matched to their slot through `NVIM_CLAUDE_SLOT`
and `$NVIM`, which the claude process inherits from the terminal job; other
sessions (plain terminals) appear in the map and in `<leader>cl` only. Live
sessions are also read from Claude's own registry in `~/.claude/sessions/`.

### Clean machine: hooks setup

Needs `jq`. Add this to `~/.claude/settings.json` (user level, so it applies
in every project), then run `:ClaudeHooksCheck`:

```json
{
  "hooks": {
    "SessionStart":      [{ "hooks": [{ "type": "command", "command": "~/.config/nvim/claude/hook.sh", "async": true }] }],
    "UserPromptSubmit":  [{ "hooks": [{ "type": "command", "command": "~/.config/nvim/claude/hook.sh", "async": true }] }],
    "PreToolUse":        [{ "hooks": [{ "type": "command", "command": "~/.config/nvim/claude/hook.sh", "async": true }] }],
    "PostToolUse":       [{ "hooks": [{ "type": "command", "command": "~/.config/nvim/claude/hook.sh", "async": true }] }],
    "PermissionRequest": [{ "hooks": [{ "type": "command", "command": "~/.config/nvim/claude/hook.sh", "async": true }] }],
    "SubagentStart":     [{ "hooks": [{ "type": "command", "command": "~/.config/nvim/claude/hook.sh", "async": true }] }],
    "SubagentStop":      [{ "hooks": [{ "type": "command", "command": "~/.config/nvim/claude/hook.sh", "async": true }] }],
    "Stop":              [{ "hooks": [{ "type": "command", "command": "~/.config/nvim/claude/hook.sh", "async": true }] }],
    "Notification":      [{ "hooks": [{ "type": "command", "command": "~/.config/nvim/claude/hook.sh", "async": true }] }],
    "TaskCreated":       [{ "hooks": [{ "type": "command", "command": "~/.config/nvim/claude/hook.sh", "async": true }] }],
    "TaskCompleted":     [{ "hooks": [{ "type": "command", "command": "~/.config/nvim/claude/hook.sh", "async": true }] }],
    "SessionEnd":        [{ "hooks": [{ "type": "command", "command": "~/.config/nvim/claude/hook.sh" }] }]
  }
}
```

The script exits 0 on anything unexpected and runs asynchronously, so it
never blocks or alters a session. Without the hooks everything but
subagents/tasks/sessions still works (status is in-band).

### Inside a Claude panel

`<Esc>` and `<Space>` belong to Claude, so no `<leader>` map works there.
Leave the panel with `<A-c>`, `<A-Left>` (window navigation) or
`<C-\><C-n>`. Mentions are typed into the prompt as a bracketed paste with
no newline, so nothing is submitted; they are refused while the slot is
`blocked` (a permission prompt would swallow them).

### Tests

```shell
bash tests/claude_hook.sh
for t in osc panel hooks; do env -u NVIM nvim --clean --headless -u NONE --cmd "set rtp^=." -S tests/claude_$t.lua; done
```

The panel test launches a stub program that emits the OSC 7501 probe and
checks Neovim's reply reaches it before the device-attributes answer.

### Follow-up (not implemented)

`coder/claudecode.nvim` would add the IDE protocol (live selection context,
Claude's edits as native diffs with accept/reject, neo-tree `@` through
`:ClaudeCodeTreeAdd`). Hook points: `panel.env()` merges
`CLAUDE_CODE_SSE_PORT` / `ENABLE_IDE_INTEGRATION`, and `mention.send` can
switch to the `at_mentioned` notification.

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
- Format-on-save: Rust (`*.rs`), C/C++ (`*.c`, `*.cpp`, `*.h`, `*.hpp`), Kotlin (`*.kt`, `*.kts`) through the LSP; XML (`*.xml`) through `xmllint --format` with 2-space indent (needs `libxml2`; invalid XML is saved unformatted with a warning)
- Statusline: Neovim's default layout plus the Claude badge (`lua/claude/ui.lua`); no statusline plugin
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
