<h1 align="center">CodeSnap.nvim</h1>

<p align="center">
  <b>Fast, beautiful code snapshots for Neovim.</b><br>
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

## 📦 Installation

### [lazy.nvim](https://github.com/folke/lazy.nvim)

```lua
{
  "Codesmith28/codesnap.nvim",
  build = "make build_generator",
  cmd = { "CodeSnap", "CodeSnapSave", "CodeSnapASCII", "CodeSnapHighlight" },
  keys = {
    { "<leader>Cc", "<cmd>CodeSnap<cr>", mode = "x", desc = "Copy snapshot to clipboard" },
    { "<leader>Cs", "<cmd>CodeSnapSave<cr>", mode = "x", desc = "Save snapshot to file" },
  },
  opts = {
    save_path = "~/Pictures/Screenshots",
  },
}
```

### Build from source (manual)

```bash
git clone https://github.com/Codesmith28/codesnap.nvim.git ~/.local/share/nvim/lazy/codesnap.nvim
cd ~/.local/share/nvim/lazy/codesnap.nvim
make build_generator
```

---

## ⌨️ Commands & Keymaps

| Command | Keymap (Visual Mode) | Description |
| :--- | :--- | :--- |
| `:CodeSnap` | `<leader>Cc` | Copies snapshot to system clipboard as transparent PNG (`image/png`). |
| `:CodeSnapSave [path]` | `<leader>Cs` | Saves snapshot to disk (defaults to system screenshot folder with timestamp). |
| `:CodeSnapHighlight` | — | Interactively select lines to highlight before copying. |
| `:CodeSnapASCII` | — | Copies snapshot as ASCII art text box. |

---

## ⚙️ Configuration

CodeSnap works out of the box with zero configuration. You can customize any option in `setup()`:

```lua
require("codesnap").setup({
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
