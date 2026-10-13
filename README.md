<h1 align="center">CodeSnappier.nvim</h1>

<p align="center">
  <b>Fast, beautiful code snapshots for Neovim — noticeably snappier.</b><br>
  Matches your active Neovim colorscheme, system font, and generates transparent screenshots.
</p>

<p align="center">
  <img src="https://img.shields.io/badge/Neovim-0.9+-57A143?logo=neovim&logoColor=fff&style=flat-square" alt="Neovim 0.9+" />
  <img src="https://img.shields.io/badge/Rust-Core-DEA584?logo=rust&logoColor=fff&style=flat-square" alt="Rust" />
  <img src="https://img.shields.io/badge/Lua-Config-2C2D72?logo=lua&logoColor=fff&style=flat-square" alt="Lua" />
  <img src="https://img.shields.io/badge/License-MIT-blue?style=flat-square" alt="License" />
</p>

---

## ✨ Features

- 🎨 **Neovim Theme Matching**: Automatically extracts your active colorscheme (`Normal`, `Comment`, `Keyword`, `String`, etc.) so snapshots match your editor identically.
- 🔤 **Auto Font Detection**: Matches your terminal emulator (Ghostty, Kitty, Alacritty, WezTerm) or system monospace font.
- 🫥 **Transparent by Default**: Clean transparent background with 20px padding (no giant borders or unwanted gradients).
- 🪟 **macOS Title Bar**: Displays macOS traffic lights and the current buffer's file name.
- 📂 **Repo-Based Breadcrumbs**: Automatically displays relative paths based on your git repository root.
- 📊 **Git Diff Support**: Highlights added (`+`) and deleted (`-`) lines when snapping diff content.
- 🚀 **Optimized Native Engine**: Compiled with Rust release optimizations and Thin LTO for fast rendering.
- 🚫 **No Watermarks**: Clean code card out of the box.

---

## ⚡ Performance Benchmarks

CodeSnappier is engineered to eliminate UI blocking and deliver near-instantaneous snapshots:

| Operation | Before | CodeSnappier | Speedup |
| :--- | :--- | :--- | :--- |
| **Copy to Clipboard** (`:CodeSnappier`) | ~1,225 ms | **~42 ms** | **~29x faster** |
| **Save to Disk** (`:CodeSnappierSave`) | ~180 ms | **~42 ms** | **~4.3x faster** |
| **Clipboard Delivery** | ~1,185 ms (blocking) | **~1.5 ms** (detached) | **~790x faster** |

### Why is it faster?

- **Eliminated 1-Second Clipboard Sleep**: Removed an unconditional 1,000 ms block from upstream that froze Neovim's main thread on every copy.
- **Direct In-Memory PNG Streaming**: Bypassed intermediate RGBA conversions, piping pre-encoded PNG bytes directly from native memory.
- **Detached Asynchronous Delivery**: Offloaded clipboard handoff to background processes (`wl-copy` on Wayland, `xclip` on X11, native pasteboard on macOS/Windows) so Neovim never waits on external display servers.
- **Zero Tokio Overhead**: Local themes and highlight syntax are evaluated directly in-process instead of spawning and blocking on a full multi-threaded Tokio runtime.
- **Compiler-Level Optimization**: Compiled with Rust `opt-level = 3`, Thin LTO (Link-Time Optimization), single codegen unit, and symbol stripping.

---

## 📦 Installation

### [lazy.nvim](https://github.com/folke/lazy.nvim)

```lua
{
  "Codesmith28/CodeSnappier.nvim", -- or local dir = "~/Projects/CodeSnappier.nvim" (or "~/Projects/codesnap.nvim")
  build = "make build_generator",
  cmd = { "CodeSnappier", "CodeSnappierSave", "CodeSnap", "CodeSnapSave" },
  keys = {
    { "<leader>Cc", "<cmd>CodeSnappier<cr>", mode = "x", desc = "Copy snapshot to clipboard" },
    { "<leader>Cs", "<cmd>CodeSnappierSave<cr>", mode = "x", desc = "Save snapshot to file" },
  },
  opts = {
    save_path = "~/Pictures/Screenshots",
  },
}
```

### Build from source (manual)

```bash
git clone https://github.com/Codesmith28/CodeSnappier.nvim.git ~/.local/share/nvim/lazy/CodeSnappier.nvim
cd ~/.local/share/nvim/lazy/CodeSnappier.nvim
make build_generator
```

---

## ⌨️ Commands & Keymaps

| Command | Alias | Keymap (Visual) | Description |
| :--- | :--- | :--- | :--- |
| `:CodeSnappier` | `:CodeSnap` | `<leader>Cc` | Copies snapshot to clipboard as transparent PNG (`image/png`). |
| `:CodeSnappierSave [path]` | `:CodeSnapSave` | `<leader>Cs` | Saves snapshot to disk (defaults to system screenshot folder). |
| `:CodeSnappierHighlight` | `:CodeSnapHighlight` | — | Interactively select lines to highlight before copying. |
| `:CodeSnappierASCII` | `:CodeSnapASCII` | — | Copies snapshot as ASCII art text box. |

---

## ⚙️ Configuration

CodeSnappier works out of the box with zero configuration. You can customize any option in `setup()`:

```lua
require("codesnappier").setup({
  -- Font family to use for code, title bar, and breadcrumbs.
  -- Defaults to nil / "auto", which resolves via prioritized fallback:
  --   p0 = terminal font (Ghostty, Kitty, Alacritty, WezTerm, iTerm2, or GUI guifont)
  --   p1 = system monospace font (fontconfig fc-match on Linux, macOS/Windows system defaults)
  --   p2 = generic fallback monospace font ("monospace")
  -- Or set an explicit font name: font_family = "Fira Code"
  font_family = nil,

  -- Destination directory or file path for :CodeSnapSave
  -- Defaults to your system screenshot folder (~/Pictures/Screenshots)
  save_path = nil,

  -- Show line numbers in snapshot
  show_line_number = true,

  -- Prepend repository folder name to breadcrumbs
  show_workspace = true,

  snapshot_config = {
    -- "auto" extracts active Neovim colorscheme (or set static theme like "candy")
    theme = "auto",

    -- Render scale factor (2 = fast HiDPI ~74ms, 3 = 4K retina ~150ms)
    scale_factor = 2,

    -- Window styling
    window = {
      mac_window_bar = true,
      margin = { x = 20, y = 20 },
      shadow = { radius = 0, color = "#00000000" },
      border = { width = 1, color = "#ffffff20" },
      radius = 12,
    },

    -- Background: "#00000000" (transparent), hex color "#1e1e2e", or gradient
    background = "#00000000",

    -- Watermark (disabled by default)
    watermark = nil,

    code_config = {
      breadcrumbs = {
        enable = true,
        separator = "/",
      },
    },
  },
})
```

---

## 📄 License

[MIT](LICENSE)
