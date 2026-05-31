# Neovim for Claude Code-Assisted Systems Programming — Demo Script

Narration script for a short video showcasing the Neovim configuration.  
Post title: **Neovim for Claude Code-Assisted Systems Programming**  
Audience: general tech. ~270 words, runtime ~2:05.

---

## [0:00 — clean Neovim session, empty buffer]

"Neovim for Claude Code-assisted systems programming."

**Keys:** leader is `<Space>`

---

## [0:04 — `:Lazy` opens, plugin dashboard visible]

"The setup is intentionally lightweight."

### Plugins
- `lazy.nvim` — plugin manager
- `neo-tree` — file explorer and workspace navigation
- `Telescope` — fuzzy finder and project search
- `which-key.nvim` — interactive keybinding hints
- `rustaceanvim` — Rust development and LSP integration
- `clangd` — C and C++ language server
- `nvim-cmp` — autocompletion engine
- `nvim-dap` + `dap-ui` — debugger integration
- `gitsigns` — inline git changes and blame
- `trouble.nvim` — diagnostics and issues panel
- `Tokyo Night` — colorscheme

**Keys:** `:Lazy` plugin dashboard

---

## [0:14 — press `<Space>`, which-key popup appears]

"Every major action is organized behind leader-key shortcuts. which-key displays the available commands as I type, so the workflow stays discoverable without memorizing every binding."

**Keys:**  
`<Space>` opens which-key menu

---

## [0:20 — `<leader>n` opens neo-tree on the left]

"This is my custom Neovim setup for hybrid Rust and C++ systems work…"

**Keys:** `<leader>n` toggle file tree

---

## [0:24 — `<leader>c1` opens Claude Code in the right column]

"…built around one idea: keep the editor and Claude Code in the same window."

**Keys:** `<leader>c1` toggle Claude session 1

---

## [0:29 — show hover docs, completion popup]

"At its core: native language-server support. Rust runs on rustaceanvim with rust-analyzer and clippy. C++ runs through Neovim 0.11's native LSP config — no Mason, no glue code."

**Keys:**  
`gd` go to definition  
`K` hover docs  
`<leader>rn` rename  
`<leader>ca` code action  
`<C-Space>` trigger completion

---

## [0:45 — breakpoint hit, dap-ui open]

"Both languages share the same debugger. codelldb is wired through nvim-dap, so breakpoints, watches, and step-through debugging work the same whether I'm in Rust or C++."

**Keys:**  
`<leader>db` toggle breakpoint  
`<leader>dc` continue  
`<leader>do` step over  
`<leader>di` step into  
`<leader>du` toggle DAP UI  
`<leader>dw` add watch

---

## [1:00 — camera focuses on the Claude pane that's been open since the intro]

"That right-hand pane is the slick part — Claude Code, the real CLI agent, running directly inside Neovim. Not a sidebar plugin. Not a web tab. The exact same agent I'd use in a terminal, docked right next to the code."

**Keys:** Claude already open from `<leader>c1`

---

## [1:16 — `<leader>c2` then `<leader>c3` stack additional Claude panes]

"I can spin up three Claude sessions side by side — one building the feature, one focused on tests, one exploring the codebase — all stacked in a single right-hand column."

**Keys:**  
`<leader>c2`  
`<leader>c3`

---

## [1:30 — Alt+arrow jumping from Claude back into the editor]

"Alt-plus-arrow jumps between every pane — even through Claude's terminal UI, which normally captures Vim keybindings."

**Keys:**  
`<A-Up>`  
`<A-Down>`  
`<A-Left>`  
`<A-Right>`

---

## [1:40 — telescope search, gitsigns blame, trouble panel]

"Telescope for fuzzy search. Inline git blame. Cross-file diagnostics. Format-on-save for every Rust and C++ buffer."

**Keys:**  
`<leader>ff` find files  
`<leader>fg` live grep  
`]h` / `[h` next/prev git hunk  
`<leader>xx` diagnostics panel  
`<leader>n` file tree

---

## [2:00 — end card]

"Fast, terminal-native, debuggable — with Claude Code embedded directly into the workflow. That's my setup for Claude Code-assisted systems programming in Neovim."
