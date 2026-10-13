local module = {
  generator = nil,
}

local path_utils = require("codesnap.utils.path")
local fetch = require("codesnap.fetch")
local platform = require("codesnap.utils.platform")

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

-- Get the path of the generator library
function module.generator_file_path(is_debug)
  local plugin_root = vim.fn.fnamemodify(debug.getinfo(1).source:sub(2), ":p:h:h:h")
  local ext = module.get_lib_extension()
  local is_win = platform.is_windows()

  -- If explicitly requested debug mode, prioritize debug target
  local search_targets = {}
  if is_debug then
    table.insert(search_targets, path_utils.join(sep, plugin_root, "generator", "target", "debug", "libgenerator.so"))
    table.insert(
      search_targets,
      path_utils.join(sep, plugin_root, "generator", "target", "debug", (is_win and "generator." or "libgenerator.") .. ext)
    )
  end

  -- Search local build targets first:
  -- 1. lua/generator.so
  -- 2. generator/target/release/libgenerator.so
  -- 3. generator/target/debug/libgenerator.so
  table.insert(search_targets, path_utils.join(sep, plugin_root, "lua", "generator.so"))
  table.insert(search_targets, path_utils.join(sep, plugin_root, "lua", "generator." .. ext))
  table.insert(search_targets, path_utils.join(sep, plugin_root, "lua", "libgenerator." .. ext))
  table.insert(search_targets, path_utils.join(sep, plugin_root, "generator", "target", "release", "libgenerator.so"))
  table.insert(
    search_targets,
    path_utils.join(sep, plugin_root, "generator", "target", "release", (is_win and "generator." or "libgenerator.") .. ext)
  )
  table.insert(search_targets, path_utils.join(sep, plugin_root, "generator", "target", "debug", "libgenerator.so"))
  table.insert(
    search_targets,
    path_utils.join(sep, plugin_root, "generator", "target", "debug", (is_win and "generator." or "libgenerator.") .. ext)
  )

  for _, candidate in ipairs(search_targets) do
    if vim.fn.filereadable(candidate) == 1 then
      local loader = package.loadlib(candidate, "luaopen_generator")
      if loader then
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
