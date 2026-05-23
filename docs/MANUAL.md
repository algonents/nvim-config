# Neovim Concepts Manual

A reference for the conceptual model underlying this Neovim configuration:
what each on-screen area is, how Neovim names it, and which concepts come
from classic Vim versus Neovim itself.

## On-screen layout

```
┌──────────────────────────────────────────────────────────────────────┐
│  Tab line (only visible when you have >1 tab)                  TAB  │
├────────────┬──────────────────────────────────┬─────────────────────┤
│            │  ┃ ┃                              │                     │
│            │  ┃ ┃ ← Sign column               │                     │
│            │  ┃ ┃   (diagnostics, git, DAP)   │                     │
│            │  ┃ ┃                              │                     │
│  Neo-tree  │  ←┃ ← Line numbers              │  Claude panel       │
│  (left)    │   ┃                              │  (right, c1/c2/c3)  │
│            │   ┃ ← Editor window              │                     │
│  <Space>n  │   ┃   (your buffer)              │  or DAP UI          │
│            │   ┃                              │  (when debugging)   │
├────────────┴───┴──────────────────────────────┴─────────────────────┤
│  Toggleterm bottom panel (t1/t2/t3) — when open                     │
├──────────────────────────────────────────────────────────────────────┤
│  Status line: mode, file, position, etc.                            │
│  Command line: :commands, /search, messages                         │
└──────────────────────────────────────────────────────────────────────┘
```

### Persistent UI chrome

| Zone | What it is |
|---|---|
| Line number column | `number` (absolute) + `relativenumber` (distance). Both on. |
| Sign column | 1-char strip between line numbers and code. Shows git markers (`│`, `_`, `~`), LSP diagnostic icons, DAP breakpoints (`●`). Always reserved (`signcolumn = "yes"`) so the editor doesn't jump when signs appear. |
| Status line | Bottom of each window. Shows mode (`-- INSERT --`), filename, line/column. Default Vim status line. |
| Command line | The single bottom row. Where `:commands`, `/search`, and messages appear. |
| Tab line | Top row, only appears when you have multiple `:tabnew` tabs. |

### Toggleable panels (custom setup)

| Panel | Trigger | Position |
|---|---|---|
| Neo-tree (file explorer) | `<Space>n` | Left, 32 cols |
| Toggleterm 1/2/3 (bash) | `<Space>t1/t2/t3` | Bottom horizontal |
| Claude 1/2/3 | `<Space>c1/c2/c3` | Right vertical, ~50% width |
| DAP UI (debugger) | `<Space>du` | Right panel (40 cols) + bottom REPL |
| Trouble (diagnostics list) | `<Space>xx` | Bottom split |

### Floating overlays

Drawn temporarily on top of everything else.

| Floater | Trigger |
|---|---|
| Telescope picker | `<Space>ff/fg/fb/fh/fr` |
| Which-key popup | Auto, after pressing `<Space>` and pausing |
| Completion menu (nvim-cmp) | Auto in insert mode, or `<C-Space>` |
| LSP hover doc | `K` |
| Diagnostic float | `<Space>e` |
| Code action menu | `<Space>ca` |

### Inline annotations

Drawn into the text itself, not in a separate region.

| Annotation | Source |
|---|---|
| Virtual diagnostic text at end of line (`■ unused variable`) | LSP / `vim.diagnostic` |
| Inlay hints (parameter names, inferred types) — if enabled | rustaceanvim / clangd |
| Inline git blame at end of current line | gitsigns (`current_line_blame = true`) |
| Search highlights | `/` and `?` |

## The three core primitives

Everything visible in Neovim maps onto one of three abstractions.

### 1. Buffer — *in-memory content*. Not visible. Just data.

A buffer holds the text of a file, or terminal output, or neo-tree's tree,
or a help page. It exists independently of whether you can see it.

Each open file = one buffer. List them with `:ls`.

### 2. Window — *a viewport showing a buffer*. The visible rectangle.

A window is just a view through which you see a buffer.

- One buffer can be shown in multiple windows (the same file open in two splits).
- One window shows exactly one buffer at a time.
- Splits (`<C-w>v`, `<C-w>s`) create new windows.

### 3. Tab page — *a layout of windows*. A workspace.

Each tab is a fresh arrangement of windows on screen.

- Not the same as VS Code tabs — a Vim tab can hold many windows in any split layout.
- `gt` / `gT` to switch.

That's it. **Buffers hold content, windows show buffers, tabs hold window layouts.**

## How visual zones map to the primitives

| Visual area | What it is |
|---|---|
| Editor area (where you type code) | A **window** showing a file **buffer** |
| Neo-tree (left panel) | A **window** showing a special **buffer** (a Lua-rendered tree) |
| Toggleterm `<leader>t1/2/3` | A **window** showing a **terminal buffer** (a buffer attached to a running shell) |
| Claude `<leader>c1/2/3` | Same: **window** showing a **terminal buffer** running `claude` |
| DAP UI panel | Multiple **windows** showing DAP's special **buffers** (scopes, watches, stacks, REPL) |
| Trouble panel | A **window** showing Trouble's diagnostic **buffer** |
| Telescope picker | A **floating window** showing Telescope's prompt/results **buffers** |
| Hover doc / completion menu | **Floating windows** with their own scratch **buffers** |

A "floating window" is the same thing as a regular window — just positioned
over the others instead of taking a slot in the split grid.

## What is *not* a window or buffer

These are part of the global UI chrome, not first-class objects:

| Zone | What it actually is |
|---|---|
| Status line | A property of each window — every window has one (`laststatus` controls visibility) |
| Tab line | Global, drawn at top, lists tab pages |
| Command line | Global, the single bottom row |
| Line numbers, sign column | Properties of a window — they belong to the window, not the buffer |

## Why the distinction matters

Once you internalize "buffer = content, window = view," a lot becomes clear:

- `:bd` deletes a **buffer** (and any windows showing it become empty or close).
- `<C-w>q` or `:q` closes a **window** but the buffer stays (unless it was the last window showing it).
- `:b <name>` swaps the current window to show a different buffer.
- Hidden buffers (`:set hidden`) let you leave unsaved files in the background — they're just buffers without an attached window.
- Neo-tree's `O` keymap works because it reads the current buffer's *content* (`node.path` from the tree buffer) — not tied to where on screen the tree is drawn.

**One-line summary**: buffers are nouns (the thing), windows are verbs (showing the thing), tab pages are folders (grouping the showing).

## Vim vs Neovim — what's shared, what's not

Almost everything above is **Vim**, inherited by Neovim.

| Concept | Origin |
|---|---|
| Buffer | Vi (1976) — the original ancestor. Vim kept and extended the concept. |
| Window (splits) | Vim 1.x. Foundational. |
| Tab page | Vim 7.0 (2006). |

If you read a Vim book from 2010, the buffer/window/tab model is identical.
`:ls`, `<C-w>v`, `gt` all work the same in both editors.

### Neovim-specific additions

| Feature | Vim? | Neovim? |
|---|---|---|
| Buffer / window / tab page model | Yes | Yes (identical) |
| Status line, sign column, command line | Yes | Yes |
| Terminal buffers (`:terminal`) | Yes (Vim 8.0+) | Yes — separate implementation, slightly different keymaps |
| Floating windows | No — Vim has "popup windows" (different API, similar idea) | Yes (`nvim_open_win`) |
| Built-in LSP client | No (needs `coc.nvim` or similar) | Yes (`vim.lsp.*`) |
| Lua as a scripting language | No (Vim has Vim9script) | Yes (your `init.lua`) |
| Tree-sitter integration | No | Yes |
| `vim.diagnostic` API, `vim.ui.open` | No | Yes |
| Plugin ecosystem (lazy.nvim, telescope, neo-tree) | Mostly no — Lua-based, Neovim-only | Yes |

### Practical implication

- The **core editing model** (modes, motions, operators, buffers/windows/tabs,
  `:` commands, search, marks, registers) is shared. Skills transfer perfectly
  between Vim and Neovim — `dw`, `ciw`, `:%s/foo/bar/g`, `gd` are the same.
- The **plumbing for plugins and integrations** is where they diverge. Neovim's
  Lua API, built-in LSP, and floating windows are the reasons most modern
  plugins (telescope, neo-tree, nvim-cmp, lazy.nvim) are Neovim-only.

Neovim was forked from Vim in 2014 specifically to modernize the *extensibility*
side without breaking the core editing model. This config is a good example:
the buffer/window/tab model and key bindings (`gd`, `gr`, splits) are Vim
heritage; the `vim.lsp`, `vim.keymap.set`, `lazy.nvim`, and Lua are all
Neovim's additions.

## C++ symbols — generating `compile_commands.json`

clangd (the C++ LSP) needs to know each translation unit's compile flags
— include paths, defines, language standard, etc. — to resolve symbols,
find references, and surface accurate diagnostics. Without that, every
`#include` looks unresolved, every macro is unknown, and the buffer is
buried in red squiggles even though the project compiles fine via its
real build system.

The contract is a file called `compile_commands.json`: a JSON array of
`{file, directory, command}` records, one per compiled source. clangd
loads it at startup and uses it as ground truth.

### Generate it from a CMake project

```shell
cmake -S <cmake-source-dir> -B build -DCMAKE_EXPORT_COMPILE_COMMANDS=ON
```

- `-S <dir>` — the directory containing `CMakeLists.txt`.
- `-B build` — output directory. This config's clangd is set to look in
  `build/` (via `--compile-commands-dir=build`), so use that name.
- `-DCMAKE_EXPORT_COMPILE_COMMANDS=ON` — the switch that asks CMake to
  emit the file alongside the build artifacts.

CMake writes `build/compile_commands.json` and `build/CMakeCache.txt`.
Only the JSON matters for clangd; the rest is the actual build tree
(safe to delete if you only care about LSP).

### When the C++ lives in a subdirectory

If the project root isn't where `CMakeLists.txt` is — e.g. a Rust crate
with a C++ sys subcrate — point `-S` at the C++ directory but run the
command from the project root so the resulting `build/` is at the root:

```shell
cd ~/Repos/my_project
cmake -S subcrate/cpp -B build -DCMAKE_EXPORT_COMPILE_COMMANDS=ON
```

clangd opens the file at `subcrate/cpp/foo.cpp`, walks up looking for
`compile_commands.json` (or the `--compile-commands-dir` hint), finds
`build/compile_commands.json` at the root, and uses the matching entry.

### When to regenerate

- New source files added or moved.
- `CMakeLists.txt` changes (new include paths, defines, flags).
- After cloning a project for the first time.
- After restructuring the directory layout.

If sources don't move and flags don't change, you don't need to re-run
it. `build/` is typically gitignored.

### Picking up the new file in a running Neovim session

clangd reads `compile_commands.json` once at startup. After regenerating,
either:

```vim
:e
```

— reloads the current buffer and re-attaches LSP, *or*

```vim
:lua vim.lsp.stop_client(vim.lsp.get_clients({ name = "clangd" }))
```

— stops clangd; it auto-restarts on the next C/C++ buffer open. Closing
and reopening Neovim is the brute-force equivalent.

### When clangd still complains after regenerating

- Verify the regenerated file references the *current* source paths:
  ```shell
  head -20 build/compile_commands.json
  ```
  Each `"file": "..."` should be an absolute path that exists.
- Confirm clangd is finding it:
  ```vim
  :lua print(vim.inspect(vim.lsp.get_clients({ name = "clangd" })[1].config))
  ```
- Look at clangd's log for "Loaded compilation database" or errors:
  ```shell
  tail -f ~/.local/state/nvim/lsp.log
  ```

## Modes — the central reflex

Not a UI region but inseparable from how Neovim feels.

| Mode | Entered via | What you do there |
|---|---|---|
| Normal | `<Esc>` | Navigate, give commands |
| Insert | `i`/`a`/`o` | Type text |
| Visual | `v`/`V`/`<C-v>` | Select |
| Command | `:` | Run ex commands |
| Terminal | inside a terminal buffer, `i` | Type into shell/claude |
