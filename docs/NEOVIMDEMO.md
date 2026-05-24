# Neovim for Claude Code-Assisted Systems Programming — Demo Script

Narration script for a short video showcasing the Neovim configuration.
Post title: **Neovim for Claude Code-Assisted Systems Programming**
Audience: general tech. ~265 words, runtime ~2:05, comfortable pace with room to breathe.

Each beat lists the keybindings the editor should overlay on screen as they're triggered, so viewers see the actual shortcuts driving the demo.

---

**[0:00 — clean Neovim session, empty buffer]**

"Neovim for Claude Code-assisted systems programming."

*Keys: leader is `<Space>`*

**[0:04 — `:Lazy` opens, plugin dashboard visible]**

"The stack, at a glance: lazy.nvim manages plugins. rustaceanvim and clangd power the LSPs. nvim-cmp drives completion. nvim-dap and dap-ui handle debugging. Telescope, neo-tree, gitsigns, trouble, and Tokyo Night round out the editor."

*Keys: `:Lazy` plugin dashboard*

**[0:18 — `<leader>n` opens neo-tree on the left]**

"This is my custom Neovim setup for hybrid Rust and C++ work…"

*Keys: `<leader>n` toggle file tree*

**[0:22 — `<leader>c1` opens Claude Code in the right column]**

"…built around one idea: keep the editor and Claude Code in the same window."

*Keys: `<leader>c1` toggle Claude session 1*

**[0:26 — show hover docs, completion popup]**

"At its core: native language-server support. Rust runs on rustaceanvim with rust-analyzer and clippy. C++ uses clangd through Neovim 0.11's built-in LSP config — no extra package manager, no glue code."

*Keys: `gd` go to definition · `K` hover docs · `<leader>rn` rename · `<leader>ca` code action · `<C-Space>` trigger completion*

**[0:42 — breakpoint hit, dap-ui open]**

"Both languages share the same debugger. codelldb is wired through nvim-dap, so breakpoints, watches, and step-through work the same whether I'm in Rust or C++."

*Keys: `<leader>db` toggle breakpoint · `<leader>dc` continue · `<leader>do` step over · `<leader>di` step into · `<leader>du` toggle DAP UI · `<leader>dw` add watch*

**[0:56 — camera focuses on the Claude pane that's been open since the intro]**

"That right-hand pane is the slick part — Claude Code, the real CLI agent, running as a terminal pane right inside Neovim. Not a sidebar plugin, not a web tab. Same agent I'd use in a terminal, docked next to my code."

*Keys: (Claude already open from `<leader>c1` at intro)*

**[1:12 — `<leader>c2` then `<leader>c3` stack additional Claude panes]**

"I can spin up three Claude sessions side by side — one for the feature, one for tests, one for spelunking through the codebase — all stacked in a single right-hand column."

*Keys: `<leader>c2` · `<leader>c3` stack additional sessions*

**[1:26 — Alt+arrow jumping from Claude back into the editor]**

"Alt-plus-arrow jumps between every pane — even through Claude's TUI, which normally swallows Vim's shortcuts."

*Keys: `<A-Up>` · `<A-Down>` · `<A-Left>` · `<A-Right>` window navigation (works from inside terminal TUIs)*

**[1:36 — telescope search, gitsigns blame, trouble panel]**

"Telescope for fuzzy search. Inline git blame. Cross-file diagnostics. Format-on-save for every Rust and C++ buffer."

*Keys: `<leader>ff` find files · `<leader>fg` live grep · `]h` / `[h` next/prev git hunk · `<leader>xx` diagnostics panel · `<leader>n` file tree*

**[1:48 — terminal showing `NVIM_APPNAME=nvim-web nvim`]**

"And `NVIM_APPNAME` isolates the config — same machine, completely separate web-dev setup, one env var away."

*Shell: `NVIM_APPNAME=nvim-web nvim` launches an isolated config*

**[1:58 — end card]**

"Fast, native, debuggable — and Claude Code lives in the editor. That's what Claude Code-assisted systems programming looks like for me."
