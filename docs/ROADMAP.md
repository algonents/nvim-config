# Roadmap

Planned improvements, grouped by area. Ordered roughly by impact within each section.

## C++ Experience

The current C++ setup (clangd via native `vim.lsp.config`, codelldb debugging,
treesitter, format-on-save) is functional. These items reduce day-to-day
friction.

### 1. CMake integration — `Civitasv/cmake-tools.nvim`

Removes the manual `cmake -B build -DCMAKE_EXPORT_COMPILE_COMMANDS=ON` step and
the hand-typed executable path in the debug config (`debugger.lua`).

- `:CMakeGenerate` / `:CMakeBuild` / `:CMakeRun` with target + build-type pickers
- Auto-generates `compile_commands.json` so clangd works with no manual step
- `:CMakeDebug` picks the target and passes it to codelldb automatically,
  replacing the `vim.fn.input("Executable: ")` prompt

### 2. Inlay hints (native, no plugin)

Neovim 0.11 supports `vim.lsp.inlay_hint.enable(true)`. clangd emits parameter
names and deduced types (`auto`, lambda return types). Wire on `LspAttach` with a
toggle keymap.

### 3. Fill C++ navigation / signature gaps

Existing LSP maps cover `gd K <leader>fr/rn/ca`. Missing ones that matter for C++:

- `gi` → implementation, `gD` → declaration, `gy` → type definition
- `<C-k>` → signature help (function arg hints, useful for overloads)
- `<leader>fs` → document / workspace symbols via Telescope
  (`lsp_dynamic_workspace_symbols`)

### 4. clangd flags (`cpp.lua` cmd)

```
"--completion-style=detailed",      -- full overload info in the menu
"--header-insertion=iwyu",          -- auto-add #includes on completion
"--header-insertion-decorators",
"-j=4", "--pch-storage=memory",     -- faster background indexing
```

### 5. Nice-to-haves

- `p00f/clangd_extensions.nvim` — `:ClangdAST`, `:ClangdTypeHierarchy`,
  `:ClangdMemoryUsage`, `:ClangdSymbolInfo`
- `.clang-format` in the repo to pin style (format-on-save uses LLVM defaults
  otherwise)
- `neocmakelsp` — LSP for `CMakeLists.txt` itself (completion / linting; the
  treesitter parser is already installed)
