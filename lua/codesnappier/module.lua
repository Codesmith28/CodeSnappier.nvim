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

  -- 1. Standard active binary: lua/generator.so, generator.dylib, generator.dll
  local default_target = path_utils.join(sep, plugin_root, "lua", "generator.so")
  table.insert(search_targets, default_target)
  table.insert(search_targets, path_utils.join(sep, plugin_root, "lua", "generator." .. ext))
  table.insert(search_targets, path_utils.join(sep, plugin_root, "lua", "libgenerator." .. ext))

  -- 2. Bundled precompiled binaries for current OS/architecture
  if os_name ~= "unknown" and arch_name ~= "unknown" then
    local platform_id = string.format("%s-%s", os_name, arch_name)
    table.insert(search_targets, path_utils.join(sep, plugin_root, "lua", platform_id .. "generator.so"))
    table.insert(search_targets, path_utils.join(sep, plugin_root, "lua", platform_id .. "_generator.so"))
    table.insert(search_targets, path_utils.join(sep, plugin_root, "lua", platform_id .. "generator." .. ext))
    table.insert(search_targets, path_utils.join(sep, plugin_root, "lua", platform_id .. "_generator." .. ext))
  end

  -- 3. Local cargo release builds
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

  for _, candidate in ipairs(search_targets) do
    if vim.fn.filereadable(candidate) == 1 then
      local loader = package.loadlib(candidate, "luaopen_generator")
      if loader then
        -- If loaded from bundled precompiled binary, auto-populate lua/generator.so if missing
        if candidate ~= default_target and vim.fn.filereadable(default_target) == 0 then
          pcall(vim.fn.system, string.format("cp -f %s %s", vim.fn.shellescape(candidate), vim.fn.shellescape(default_target)))
        end
        return candidate
      end
    end
  end

  -- Fallback to pre-built remote library in libs directory
  local ok, lib_path = pcall(fetch.ensure_lib)
  if ok and lib_path and vim.fn.filereadable(lib_path) == 1 then
    local libs_dir = path_utils.join(sep, plugin_root, "libs")
    package.cpath = path_utils.join(";", package.cpath, path_utils.join(sep, libs_dir, "?"))
    return lib_path
  end

  error("Failed to load the generator library. Please ensure it is built correctly.")
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
