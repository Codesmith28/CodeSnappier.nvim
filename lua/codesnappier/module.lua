local module = {
  generator = nil,
}

local path_utils = require("codesnappier.utils.path")
local fetch = require("codesnappier.fetch")
local platform = require("codesnappier.utils.platform")

local OS_LIB_EXTENSION_MAP = {
  mac = "dylib",
  osx = "dylib",
  windows = "dll",
  linux = "so",
}

local sep = path_utils.get_separator()

function module.get_lib_extension()
  local extension = OS_LIB_EXTENSION_MAP[jit.os:lower()]
  return extension or "so"
end

local function get_platform_info()
  local uv = vim.uv or vim.loop
  local uname = uv.os_uname()
  local sys = uname.sysname:lower()
  local arch = uname.machine:lower()

  local os_name = "unknown"
  if sys:find("darwin") or sys:find("mac") or jit.os:lower() == "osx" or jit.os:lower() == "mac" then
    os_name = "mac"
  elseif sys:find("linux") or jit.os:lower() == "linux" then
    os_name = "linux"
  elseif sys:find("windows") or jit.os:lower() == "windows" then
    os_name = "windows"
  end

  local arch_name = "unknown"
  if arch == "x86_64" or arch == "amd64" or jit.arch:lower() == "x64" then
    arch_name = "x86_64"
  elseif arch == "aarch64" or arch == "arm64" or jit.arch:lower() == "arm64" then
    arch_name = "aarch64"
  end

  return os_name, arch_name
end

-- Get the path of the generator library
function module.generator_file_path(is_debug)
  local plugin_root = vim.fn.fnamemodify(debug.getinfo(1).source:sub(2), ":p:h:h:h")
  local ext = module.get_lib_extension()
  local is_win = platform.is_windows()
  local os_name, arch_name = get_platform_info()

  -- If explicitly requested debug mode, prioritize debug target
  local search_targets = {}
  if is_debug then
    table.insert(search_targets, path_utils.join(sep, plugin_root, "generator", "target", "debug", "libgenerator.so"))
    table.insert(
      search_targets,
      path_utils.join(sep, plugin_root, "generator", "target", "debug", (is_win and "generator." or "libgenerator.") .. ext)
    )
  end

  -- 1. Cached library in lua/libs/ (downloaded from GitHub releases)
  local lib_name = fetch.get_platform_lib_name()
  local cached_release_lib = path_utils.join(sep, plugin_root, "lua", "libs", lib_name)
  table.insert(search_targets, cached_release_lib)

  -- 2. Standard active binary: lua/generator.so, generator.dylib, generator.dll
  local default_target = path_utils.join(sep, plugin_root, "lua", "generator.so")
  table.insert(search_targets, default_target)
  table.insert(search_targets, path_utils.join(sep, plugin_root, "lua", "generator." .. ext))
  table.insert(search_targets, path_utils.join(sep, plugin_root, "lua", "libgenerator." .. ext))

  -- 3. Local cargo release builds (for local developers)
  table.insert(search_targets, path_utils.join(sep, plugin_root, "generator", "target", "release", "libgenerator.so"))
  table.insert(
    search_targets,
    path_utils.join(sep, plugin_root, "generator", "target", "release", (is_win and "generator." or "libgenerator.") .. ext)
  )

  -- 4. Local cargo debug builds
  table.insert(search_targets, path_utils.join(sep, plugin_root, "generator", "target", "debug", "libgenerator.so"))
  table.insert(
    search_targets,
    path_utils.join(sep, plugin_root, "generator", "target", "debug", (is_win and "generator." or "libgenerator.") .. ext)
  )

  -- 5. Bundled binaries (if present)
  if os_name ~= "unknown" and arch_name ~= "unknown" then
    local platform_id = string.format("%s-%s", os_name, arch_name)
    table.insert(search_targets, path_utils.join(sep, plugin_root, "lua", platform_id .. "generator.so"))
    table.insert(search_targets, path_utils.join(sep, plugin_root, "lua", platform_id .. "_generator.so"))
    table.insert(search_targets, path_utils.join(sep, plugin_root, "lua", platform_id .. "generator." .. ext))
    table.insert(search_targets, path_utils.join(sep, plugin_root, "lua", platform_id .. "_generator." .. ext))
  end

  for _, candidate in ipairs(search_targets) do
    if vim.fn.filereadable(candidate) == 1 then
      local loader = package.loadlib(candidate, "luaopen_generator")
      if loader then
        return candidate
      end
    end
  end

  -- 6. Not yet downloaded: fetch pre-compiled native binary from GitHub releases
  local ok, lib_path = pcall(fetch.ensure_lib)
  if ok and lib_path and vim.fn.filereadable(lib_path) == 1 then
    local loader = package.loadlib(lib_path, "luaopen_generator")
    if loader then
      -- Copy to default target for faster subsequent loads
      pcall(vim.fn.system, string.format("cp -f %s %s", vim.fn.shellescape(lib_path), vim.fn.shellescape(default_target)))
      return lib_path
    end
  end

  local platform_str = (os_name ~= "unknown" and arch_name ~= "unknown") and (os_name .. "-" .. arch_name)
    or "your system"
  error(
    "CodeSnappier: Failed to load pre-compiled generator library for "
      .. platform_str
      .. ". Ensure precompiled binaries are available in lua/ or build manually via 'make build_generator'."
  )
end

function module.load_generator(is_debug)
  if module.generator ~= nil then
    return module.generator
  end

  local generator_path = module.generator_file_path(is_debug)
  local loader = package.loadlib(generator_path, "luaopen_generator")

  if not loader then
    error("Failed to load generator: " .. generator_path)
  end

  module.generator = loader()
  return module.generator
end

return module
