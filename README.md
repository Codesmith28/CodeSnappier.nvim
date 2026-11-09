<h1 align="center">CodeSnappier.nvim</h1>

<p align="center">
  <b>Fast, beautiful code snapshots for Neovim — noticeably snappier.</b><br>
  Matches your active colorscheme, system font, and generates transparent screenshots.
</p>

<p align="center">
  <img src="https://img.shields.io/badge/Neovim-0.9+-57A143?logo=neovim&logoColor=fff&style=flat-square" alt="Neovim 0.9+" />
  <img src="https://img.shields.io/badge/Rust-Core-DEA584?logo=rust&logoColor=fff&style=flat-square" alt="Rust" />
  <img src="https://img.shields.io/badge/Precompiled-Universal-blue?style=flat-square" alt="Precompiled" />
  <img src="https://img.shields.io/badge/License-MIT-green?style=flat-square" alt="License" />
</p>

---

## ✨ Features

- 🎨 **Neovim Theme Matching**: Automatically extracts your editor's active colorscheme.
- 🔤 **Smart Font Detection**: Matches your terminal font (Ghostty, Kitty, WezTerm, Alacritty) or system monospace.
- 🫥 **Transparent PNGs**: Clean transparent background with 20px padding (no unwanted gradients or TIFF issues).
- 🪟 **macOS Title Bar**: Displays macOS traffic lights and repository-relative breadcrumbs.
- ⚡ **Near-Instant (~98ms)**: Optimized Rust engine with non-blocking, detached async clipboard delivery.
- 📦 **Zero Compilation**: Pre-compiled binaries downloaded automatically via GitHub Releases for macOS (Apple Silicon & Intel), Linux (x86_64 & ARM64), and Windows. No Rust or Cargo required.

---

## ⚡ Performance

| Operation | Upstream | CodeSnappier | Speedup |
| :--- | :--- | :--- | :--- |
| **Copy to Clipboard** (`:CodeSnappier`, ~10 lines) | ~1,225 ms | **~98 ms** | **~12x faster** |
| **Save to Disk** (`:CodeSnappierSave`, ~10 lines) | ~180 ms | **~95 ms** | **~1.9x faster** |
| **Clipboard Delivery Hand-off** | ~1,185 ms (blocking) | **~1.5 ms** (detached) | **~790x faster** |
| **Format & Installation** | `.tiff` / requires Rust | **Pure PNG / Precompiled** | **Universal & Instant** |

---

## 📦 Installation

### [lazy.nvim](https://github.com/folke/lazy.nvim)

```lua
{
  "Codesmith28/CodeSnappier.nvim",
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

<details>
<summary>Other plugin managers (Packer, vim-plug)</summary>

#### [packer.nvim](https://github.com/wbthomason/packer.nvim)
```lua
use({
  "Codesmith28/CodeSnappier.nvim",
  config = function()
    require("codesnappier").setup()
  end,
})
```

#### [vim-plug](https://github.com/junegunn/vim-plug)
```vim
Plug 'Codesmith28/CodeSnappier.nvim'
```
</details>

<details>
<summary>Building from source (developers only)</summary>

```bash
git clone https://github.com/Codesmith28/CodeSnappier.nvim.git ~/.local/share/nvim/lazy/CodeSnappier.nvim
cd ~/.local/share/nvim/lazy/CodeSnappier.nvim
make build_generator
```
</details>

---

## ⌨️ Commands & Keymaps

| Command | Alias | Keymap (Visual) | Description |
| :--- | :--- | :--- | :--- |
| `:CodeSnappier` | `:CodeSnap` | `<leader>Cc` | Copies snapshot to clipboard strictly as transparent PNG. |
| `:CodeSnappierSave [path]` | `:CodeSnapSave` | `<leader>Cs` | Saves snapshot to disk strictly as PNG. |
| `:CodeSnappierHighlight` | `:CodeSnapHighlight` | — | Interactively select lines to highlight before copying. |
| `:CodeSnappierASCII` | `:CodeSnapASCII` | — | Copies snapshot as ASCII art text box. |

---

## ⚙️ Configuration

CodeSnappier works out of the box with zero configuration. You can customize any option in `setup()`:

```lua
require("codesnappier").setup({
  -- Custom font family (defaults to auto-detecting terminal / system monospace)
  font_family = nil,

  -- Default destination directory for :CodeSnappierSave
  save_path = "~/Pictures/Screenshots",

  -- Show line numbers in snapshot
  show_line_number = true,

  -- Prepend repository folder name to breadcrumbs
  show_workspace = true,

  snapshot_config = {
    -- "auto" extracts active Neovim colorscheme (or set static theme like "candy")
    theme = "auto",

    -- Render scale factor (2 = fast HiDPI, 3 = 4K retina)
    scale_factor = 2,

    -- Window styling
    window = {
      mac_window_bar = true,
      margin = { x = 20, y = 20 },
      shadow = { radius = 0, color = "#00000000" },
      border = { width = 1, color = "#ffffff20" },
      radius = 12,
    },

    -- Background: "#00000000" (transparent) or hex color ("#1e1e2e")
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
