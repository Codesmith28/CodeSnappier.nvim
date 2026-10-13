local platform_utils = require("codesnap.utils.platform")

local font_utils = {
  _cached_font = nil,
}

local function clean_font_name(font)
  if not font or font == "" then
    return nil
  end
  -- guifont can be comma-separated or contain options like ":h12", ":b", etc.
  local first = vim.split(font, ",", { plain = true })[1]
  if not first or first == "" then
    return nil
  end
  local name = vim.split(first, ":", { plain = true })[1]
  name = vim.trim(name)
  return name ~= "" and name or nil
end

local function detect_linux_font()
  local ok, output = pcall(function()
    return vim.fn.system({ "fc-match", "monospace", "-f", "%{family}\n" })
  end)
  if ok and vim.v.shell_error == 0 and output then
    local trimmed = vim.trim(output)
    local first = vim.split(trimmed, ",", { plain = true })[1]
    first = vim.trim(first or "")
    if first ~= "" then
      return first
    end
  end
  return nil
end

local function detect_macos_font()
  local common_fonts = { "SF Mono", "Menlo", "Monaco", "monospace" }
  local mac_font_paths = {
    ["SF Mono"] = {
      "/System/Applications/Utilities/Terminal.app/Contents/Resources/Fonts/SF-Mono-Regular.otf",
      "/System/Library/Fonts/SFMono-Regular.otf",
      "/Library/Fonts/SFMono-Regular.otf",
    },
    ["Menlo"] = {
      "/System/Library/Fonts/Menlo.ttc",
      "/Library/Fonts/Menlo.ttc",
      "/System/Library/Fonts/Supplemental/Menlo.ttc",
    },
    ["Monaco"] = {
      "/System/Library/Fonts/Monaco.dfont",
      "/Library/Fonts/Monaco.dfont",
      "/System/Library/Fonts/Supplemental/Monaco.dfont",
    },
  }

  for _, font_name in ipairs(common_fonts) do
    if font_name == "monospace" then
      return "monospace"
    end
    local paths = mac_font_paths[font_name]
    if paths then
      for _, p in ipairs(paths) do
        if vim.fn.filereadable(p) == 1 then
          return font_name
        end
      end
    end
  end

  return "SF Mono"
end

local function detect_windows_font()
  local windir = os.getenv("WINDIR") or "C:\\Windows"
  local win_fonts = {
    { name = "Consolas", path = windir .. "\\Fonts\\consola.ttf" },
    { name = "Cascadia Code", path = windir .. "\\Fonts\\CascadiaCode.ttf" },
  }
  for _, item in ipairs(win_fonts) do
    if vim.fn.filereadable(item.path) == 1 then
      return item.name
    end
  end
  return "Consolas"
end

local function detect_terminal_font()
  -- 1. Ghostty (checks GHOSTTY_RESOURCES_DIR or config)
  if os.getenv("GHOSTTY_RESOURCES_DIR") or os.getenv("TERM") == "xterm-ghostty" then
    local paths = {
      vim.fn.expand("~/.config/ghostty/config"),
      vim.fn.expand("~/.ghostty/config"),
    }
    for _, path in ipairs(paths) do
      if vim.fn.filereadable(path) == 1 then
        local f = io.open(path, "r")
        if f then
          for line in f:lines() do
            local font = line:match("^%s*font%-family%s*=%s*[\"']?([^\"'\r\n]+)[\"']?")
            if font and font ~= "" and font:lower() ~= "monospace" then
              f:close()
              return vim.trim(font)
            end
          end
          f:close()
        end
      end
    end
  end

  -- 2. Kitty (checks KITTY_PID or kitty.conf)
  if os.getenv("KITTY_PID") or os.getenv("TERM") == "xterm-kitty" then
    local path = vim.fn.expand("~/.config/kitty/kitty.conf")
    if vim.fn.filereadable(path) == 1 then
      local f = io.open(path, "r")
      if f then
        for line in f:lines() do
          local font = line:match("^%s*font_family%s+[\"']?([^\"'\r\n]+)[\"']?")
          if font and font ~= "" and font:lower() ~= "monospace" then
            f:close()
            return vim.trim(font)
          end
        end
        f:close()
      end
    end
  end

  -- 3. Alacritty (alacritty.toml or alacritty.yml)
  local alacritty_paths = {
    vim.fn.expand("~/.config/alacritty/alacritty.toml"),
    vim.fn.expand("~/.config/alacritty/alacritty.yml"),
    vim.fn.expand("~/.alacritty.toml"),
  }
  for _, path in ipairs(alacritty_paths) do
    if vim.fn.filereadable(path) == 1 then
      local f = io.open(path, "r")
      if f then
        for line in f:lines() do
          local font = line:match('family%s*=%s*["\']([^"\']+)["\']')
            or line:match('family:%s*["\']?([^"\'\r\n]+)["\']?')
          if font and font ~= "" and font:lower() ~= "monospace" then
            f:close()
            return vim.trim(font)
          end
        end
        f:close()
      end
    end
  end

  -- 4. WezTerm (wezterm.lua)
  if os.getenv("WEZTERM_PANE") or os.getenv("WEZTERM_EXECUTABLE") then
    local path = vim.fn.expand("~/.config/wezterm/wezterm.lua")
    if vim.fn.filereadable(path) == 1 then
      local f = io.open(path, "r")
      if f then
        local content = f:read("*a")
        f:close()
        local font = content:match('font%s*=%s*wezterm%.font%s*%(%s*["\']([^"\']+)["\']')
          or content:match('font%s*=%s*wezterm%.font_with_fallback%s*%({?%s*["\']([^"\']+)["\']')
        if font and font ~= "" and font:lower() ~= "monospace" then
          return vim.trim(font)
        end
      end
    end
  end

  -- 5. macOS iTerm2
  if platform_utils.is_macos() then
    local ok, out = pcall(vim.fn.system, { "defaults", "read", "com.googlecode.iterm2", "Normal Font" })
    if ok and vim.v.shell_error == 0 and out then
      local font = clean_font_name(out)
      if font and font ~= "" then
        return font
      end
    end
  end

  return nil
end

--- Detect font following the prioritized fallback ladder:
--- p0: Terminal font (GUI guifont or terminal emulator: Ghostty, Kitty, Alacritty, WezTerm, iTerm2)
--- p1: System monospace font (fontconfig fc-match on Linux, macOS defaults, Windows system fonts)
--- p2: Generic fallback monospace font ("monospace")
function font_utils.detect_font()
  -- p0: Terminal font (GUI guifont or terminal emulator configuration)
  local is_gui = (vim.fn.has("gui_running") == 1) or vim.g.neovide or vim.g.goneovim
  if is_gui and vim.o.guifont and vim.o.guifont ~= "" then
    local cleaned = clean_font_name(vim.o.guifont)
    if cleaned then
      return cleaned
    end
  end

  local term_font = detect_terminal_font()
  if term_font and term_font ~= "" then
    return term_font
  end

  -- p1: System monospace font
  local detected = nil
  if platform_utils.is_linux() then
    detected = detect_linux_font()
  elseif platform_utils.is_macos() then
    detected = detect_macos_font()
  elseif platform_utils.is_windows() then
    detected = detect_windows_font()
  end

  if detected and detected ~= "" then
    return detected
  end

  -- p2: Whatever fallback monospace font is available
  return "monospace"
end

function font_utils.get_font()
  if not font_utils._cached_font then
    font_utils._cached_font = font_utils.detect_font()
  end
  return font_utils._cached_font
end

function font_utils.reset_cache()
  font_utils._cached_font = nil
end

return font_utils
