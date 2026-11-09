local fetch = {}
local uv = vim.uv or vim.loop

local function get_os_arch()
  local uname = uv.os_uname()
  local os_name = uname.sysname:lower()
  local arch = uname.machine:lower()

  -- Normalize OS names
  if os_name == "darwin" then
    os_name = "mac"
  elseif os_name == "windows_nt" then
    os_name = "windows"
  end

  -- Normalize architecture names
  if arch == "x86_64" or arch == "amd64" then
    arch = "x86_64"
  elseif arch == "aarch64" or arch == "arm64" then
    arch = "aarch64"
  end

  return os_name, arch
end

local function get_platform_lib_name()
  local os_name, arch = get_os_arch()
  local extension = "so"

  if os_name == "windows" then
    extension = "dll"
  end

  return string.format("%s-%s_generator.%s", os_name, arch, extension)
end

local function get_plugin_version()
  local path_utils = require("codesnappier.utils.path")
  local sep = path_utils.get_separator()
  local project_toml_path =
    path_utils.join(sep, vim.fn.fnamemodify(debug.getinfo(1).source:sub(2), ":p:h:h:h"), "project.toml")

  local file = io.open(project_toml_path, "r")
  if not file then
    return nil
  end

  local content = file:read("*all")
  file:close()

  local version = content:match('version%s*=%s*"([^"]+)"')
  return version
end

local function download_lib(version, lib_name, dest_path)
  local platform_utils = require("codesnappier.utils.platform")
  local lib_names = {
    lib_name,
    (lib_name:gsub("_generator", "generator")),
  }

  local candidate_urls = {}
  if version and version ~= "" then
    for _, name in ipairs(lib_names) do
      table.insert(
        candidate_urls,
        string.format("https://github.com/Codesmith28/CodeSnappier.nvim/releases/download/v%s/%s", version, name)
      )
      table.insert(
        candidate_urls,
        string.format("https://github.com/Codesmith28/CodeSnappier.nvim/releases/download/%s/%s", version, name)
      )
    end
  end

  -- Fallback to latest release
  for _, name in ipairs(lib_names) do
    table.insert(
      candidate_urls,
      string.format("https://github.com/Codesmith28/CodeSnappier.nvim/releases/latest/download/%s", name)
    )
  end

  local success = false
  local last_err = ""

  for _, url in ipairs(candidate_urls) do
    local cmd
    if platform_utils.is_windows() then
      cmd = string.format(
        'powershell -Command "[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12; Invoke-WebRequest -Uri %s -OutFile %s"',
        vim.fn.shellescape(url),
        vim.fn.shellescape(dest_path)
      )
    else
      cmd = string.format("curl -f -L -s -o %s %s", vim.fn.shellescape(dest_path), vim.fn.shellescape(url))
    end

    local result = vim.fn.system(cmd)
    if vim.v.shell_error == 0 and vim.fn.filereadable(dest_path) == 1 and (vim.fn.getfsize(dest_path) or 0) > 4096 then
      success = true
      break
    else
      last_err = result ~= "" and result or ("HTTP download failed for " .. url)
      pcall(vim.fn.delete, dest_path)
    end
  end

  if not success then
    error(
      "CodeSnappier: Failed to download precompiled binary for "
        .. lib_name
        .. " from GitHub releases.\nPlease ensure internet access or visit https://github.com/Codesmith28/CodeSnappier.nvim/releases"
    )
  end

  return true
end

function fetch.get_os_arch()
  return get_os_arch()
end

function fetch.get_platform_lib_name()
  return get_platform_lib_name()
end

function fetch.ensure_lib()
  local path_utils = require("codesnappier.utils.path")
  local lib_name = get_platform_lib_name()
  local version = get_plugin_version() or "latest"

  local sep = path_utils.get_separator()
  local plugin_root = vim.fn.fnamemodify(debug.getinfo(1).source:sub(2), ":p:h:h:h")
  local lib_dir = path_utils.join(sep, plugin_root, "lua", "libs")
  local lib_path = path_utils.join(sep, lib_dir, lib_name)
  local version_file = path_utils.join(sep, lib_dir, ".version")

  -- Create libs directory if it doesn't exist
  vim.fn.mkdir(lib_dir, "p")

  -- Check if library already exists and is current version
  local need_download = true
  if vim.fn.filereadable(lib_path) == 1 and vim.fn.filereadable(version_file) == 1 then
    local current_version = vim.fn.readfile(version_file)[1]
    if current_version == version then
      need_download = false
    end
  end

  if need_download then
    vim.notify("CodeSnappier: Downloading precompiled native binary for " .. lib_name .. "...", vim.log.levels.INFO)
    download_lib(version, lib_name, lib_path)
    vim.fn.writefile({ version }, version_file)
    vim.notify("CodeSnappier: Precompiled binary downloaded successfully!", vim.log.levels.INFO)
  end

  return lib_path
end

return fetch
