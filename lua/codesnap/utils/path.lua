local string_utils = require("codesnap.utils.string")
local platform_utils = require("codesnap.utils.platform")
local path_utils = {}

-- Get the appropriate path separator for the current OS
function path_utils.get_separator()
  return package.config:sub(1, 1) -- Returns '\' on Windows, '/' on Unix-like systems
end

function path_utils.join(separator, ...)
  local args = { ... }

  return table.concat(args, separator)
end

function path_utils.dir_name()
  local fallback_sep = "/"
  local sep = path_utils.get_separator()
  local pattern = "@?(.*" .. vim.pesc(sep) .. ")"
  local src_path = debug.getinfo(1).source
  local retval = src_path:match(pattern)

  -- if regex has no matches (fails) and you're on non-unix-style system (windows), try again w/Unix-Style path sep
  if (retval == nil) and (sep ~= fallback_sep) then
    local new_pattern = "@?(.*" .. vim.pesc(fallback_sep) .. ")"
    retval = src_path:match(new_pattern)
  end

  if retval == nil then
    error("CodeSnap config cannot determine runtime path.", 2)
  end

  return retval
end

function path_utils.with_dir_name(path)
  return path_utils.dir_name() .. path
end

function path_utils.get_escaped_cwd()
  local cwd = vim.fn.getcwd()

  return string_utils.escape(cwd)
end

function path_utils.back(path)
  local sep = path_utils.get_separator()
  local pattern = vim.pesc(sep) .. "[^" .. vim.pesc(sep) .. "]+" .. vim.pesc(sep) .. "?$"
  local parsed_path, _ = path:gsub(pattern, "")

  return parsed_path
end

function path_utils.get_git_root()
  local root = vim.fs.root(0, ".git")
  if root and root ~= "" then
    return root
  end
  return nil
end

function path_utils.get_workspace()
  local git_root = path_utils.get_git_root()
  if git_root then
    return vim.fs.basename(git_root)
  end

  local cwd = vim.fn.getcwd()
  local base = vim.fs.basename(cwd)
  return base or ""
end

function path_utils.get_relative_path()
  local full_path = vim.api.nvim_buf_get_name(0)
  if not full_path or full_path == "" then
    full_path = vim.fn.expand("%:p")
  end
  if not full_path or full_path == "" then
    return ""
  end

  local git_root = path_utils.get_git_root()
  if git_root then
    return vim.fs.relpath(git_root, full_path) or full_path
  end

  local cwd = vim.fn.getcwd()
  return vim.fs.relpath(cwd, full_path) or vim.fn.fnamemodify(full_path, ":.")
end

function path_utils.get_breadcrumbs(show_workspace)
  local full_path = vim.api.nvim_buf_get_name(0)
  if not full_path or full_path == "" then
    full_path = vim.fn.expand("%:p")
  end

  if not full_path or full_path == "" then
    return "[No Name]"
  end

  local git_root = path_utils.get_git_root()
  if git_root then
    local rel_path = vim.fs.relpath(git_root, full_path) or full_path
    if show_workspace and not rel_path:match("^[/\\]") and not rel_path:match("^%a:[/\\]") and not rel_path:match("^%.%.") then
      local repo_name = vim.fs.basename(git_root)
      return (repo_name and repo_name ~= "" and (repo_name .. "/") or "") .. rel_path
    else
      return rel_path
    end
  end

  local cwd = vim.fn.getcwd()
  local rel_path = vim.fs.relpath(cwd, full_path) or vim.fn.fnamemodify(full_path, ":.")
  if show_workspace and not rel_path:match("^[/\\]") and not rel_path:match("^%a:[/\\]") and not rel_path:match("^%.%.") then
    local workspace = vim.fs.basename(cwd)
    return (workspace and workspace ~= "" and (workspace .. "/") or "") .. rel_path
  else
    return rel_path
  end
end

-- Get default save directory by OS:
-- Linux: ~/Pictures/Screenshots if exists, else XDG_PICTURES_DIR, else ~/Pictures
-- macOS: defaults read com.apple.screencapture location, else ~/Desktop, else ~/Pictures
-- Windows: %USERPROFILE%\Pictures\Screenshots, else %USERPROFILE%\Pictures
function path_utils.get_default_save_path()
  local sep = path_utils.get_separator()
  local home = vim.fn.expand("~")

  if platform_utils.is_linux() then
    local screenshots = vim.fn.expand("~/Pictures/Screenshots")
    if vim.fn.isdirectory(screenshots) == 1 then
      return screenshots
    end
    local xdg = os.getenv("XDG_PICTURES_DIR")
    if xdg and xdg ~= "" and vim.fn.isdirectory(vim.fn.expand(xdg)) == 1 then
      return vim.fn.expand(xdg)
    end
    return vim.fn.expand("~/Pictures")
  elseif platform_utils.is_macos() then
    local ok, location = pcall(function()
      local out = vim.fn.system("defaults read com.apple.screencapture location")
      if vim.v.shell_error == 0 and out then
        local trimmed = vim.trim(out)
        if trimmed ~= "" and vim.fn.isdirectory(vim.fn.expand(trimmed)) == 1 then
          return vim.fn.expand(trimmed)
        end
      end
    end)
    if ok and location then
      return location
    end
    local desktop = vim.fn.expand("~/Desktop")
    if vim.fn.isdirectory(desktop) == 1 then
      return desktop
    end
    return vim.fn.expand("~/Pictures")
  elseif platform_utils.is_windows() then
    local userprofile = os.getenv("USERPROFILE") or home
    local screenshots = userprofile .. "\\Pictures\\Screenshots"
    if vim.fn.isdirectory(screenshots) == 1 then
      return screenshots
    end
    return userprofile .. "\\Pictures"
  end

  return vim.fn.expand("~/Pictures")
end

function path_utils.generate_snapshot_filename()
  local buf_name = vim.fn.expand("%:t")
  if not buf_name or buf_name == "" then
    buf_name = "code"
  end
  buf_name = buf_name:gsub("[/\\]", "_")
  local timestamp = os.date("%Y-%m-%d_%H-%M-%S")
  return string.format("codesnap_%s_%s.png", buf_name, timestamp)
end

function path_utils.resolve_save_path(save_path)
  if not save_path or save_path == "" then
    local ok, static = pcall(require, "codesnap.static")
    local configured_path = ok and static and (static.config and static.config.save_path or (static.config and static.config.snapshot_config and static.config.snapshot_config.save_path))
    save_path = configured_path or path_utils.get_default_save_path()
  end

  local expanded = vim.fn.expand(save_path)
  local sep = path_utils.get_separator()

  if vim.fn.isdirectory(expanded) == 1 or expanded:sub(-1) == "/" or expanded:sub(-1) == "\\" then
    local filename = path_utils.generate_snapshot_filename()
    if expanded:sub(-1) == "/" or expanded:sub(-1) == "\\" then
      return expanded .. filename
    else
      return expanded .. sep .. filename
    end
  end

  local ext = vim.fn.fnamemodify(expanded, ":e"):lower()
  if ext == "png" or ext == "svg" or ext == "html" then
    return expanded
  end

  return expanded .. sep .. path_utils.generate_snapshot_filename()
end

return path_utils
