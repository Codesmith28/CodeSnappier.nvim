local static = require("codesnap.static")
local table_utils = require("codesnap.utils.table")
local module = require("codesnap.module")
local config_module = require("codesnap.config")
local modal = require("codesnap.modal")
local path = require("codesnap.path")
local path_utils = require("codesnap.utils.path")

-- Prepare the Rust generator module
local generator = module.load_generator()

local main = {
  cwd = static.cwd,
  highlight_mode_config = nil,
}

function main.setup(config)
  static.config = table_utils.merge_config(static.config, config == nil and {} or config)
  if static.config.snapshot_config then
    path.expand_paths_in_config(static.config.snapshot_config)
  end
end

-- Save snapshot to specified save_path
--- @param save_path string|table|nil
--- @param detail table|nil
function main.save(save_path, detail)
  if type(save_path) == "table" and detail == nil then
    detail = save_path
    save_path = nil
  end
  local resolved_path = path_utils.resolve_save_path(save_path)

  local parent_dir = vim.fs.dirname(resolved_path)
  if parent_dir and parent_dir ~= "" and vim.fn.isdirectory(parent_dir) == 0 then
    vim.fn.mkdir(parent_dir, "p")
  end

  local config = config_module.get_config(detail)
  generator.save(resolved_path, config)
  pcall(vim.cmd, "delmarks <>")
  vim.notify("Save snapshot in " .. resolved_path .. " successfully", vim.log.levels.INFO)
end

-- Copy snapshot into clipboard
--- @param detail_or_path any
--- @param maybe_detail table|nil
function main.copy(detail_or_path, maybe_detail)
  local detail = type(detail_or_path) == "table" and detail_or_path or (type(maybe_detail) == "table" and maybe_detail or nil)
  local config = config_module.get_config(detail)
  generator.copy(config)
  pcall(vim.cmd, "delmarks <>")
  vim.notify("The snapshot is copied into clipboard successfully!", vim.log.levels.INFO)
end

-- Generate ASCII code snapshot and copy it into clipboard
--- @param detail_or_path any
--- @param maybe_detail table|nil
function main.copy_ascii(detail_or_path, maybe_detail)
  local detail = type(detail_or_path) == "table" and detail_or_path or (type(maybe_detail) == "table" and maybe_detail or nil)
  local config = config_module.get_config(detail)
  generator.copy_ascii(config)
  pcall(vim.cmd, "delmarks <>")
  vim.notify("The ASCII code snapshot is copied into clipboard successfully!", vim.log.levels.INFO)
end

--- @param detail_or_path any
--- @param maybe_detail table|nil
function main.copy_highlight(detail_or_path, maybe_detail)
  local detail = type(detail_or_path) == "table" and detail_or_path or (type(maybe_detail) == "table" and maybe_detail or nil)
  local original_config = config_module.get_config(detail)
  if not original_config or not original_config.content or not original_config.content.content then
    vim.notify("No code is selected", vim.log.levels.ERROR)
    return
  end

  local selected_text = original_config.content.content
  local filetype = vim.bo.filetype

  -- Pop up the modal and handle the result in the callback
  modal.pop_modal(selected_text, filetype, function(selection)
    if not selection then
      vim.notify("Selection cancelled", vim.log.levels.INFO)
      return
    end

    -- Extract the selected lines from the original text
    local lines = vim.split(selected_text, "\n", { plain = true })
    local start_line, end_line = selection[1], selection[2]

    -- Validate line numbers
    if start_line < 1 or end_line > #lines or start_line > end_line then
      vim.notify("Invalid selection range", vim.log.levels.ERROR)
      return
    end

    local config = config_module.get_config(detail)
    if not config or not config.content then
      vim.notify("Failed to get configuration", vim.log.levels.ERROR)
      return
    end

    config.content.highlight_lines = {
      { start_line, end_line, static.config.highlight_color },
    }

    generator.copy(config)
    pcall(vim.cmd, "delmarks <>")
    vim.notify("The snapshot is copied into clipboard successfully!", vim.log.levels.INFO)
  end)
end

--- @param save_path string|table|nil
--- @param detail table|nil
function main.save_highlight(save_path, detail)
  if type(save_path) == "table" and detail == nil then
    detail = save_path
    save_path = nil
  end
  local resolved_path = path_utils.resolve_save_path(save_path)
  local original_config = config_module.get_config(detail)
  if not original_config or not original_config.content or not original_config.content.content then
    vim.notify("No code is selected", vim.log.levels.ERROR)
    return
  end

  local selected_text = original_config.content.content
  local filetype = vim.bo.filetype

  modal.pop_modal(selected_text, filetype, function(selection)
    if not selection then
      vim.notify("Selection cancelled", vim.log.levels.INFO)
      return
    end

    local lines = vim.split(selected_text, "\n", { plain = true })
    local start_line, end_line = selection[1], selection[2]

    if start_line < 1 or end_line > #lines or start_line > end_line then
      vim.notify("Invalid selection range", vim.log.levels.ERROR)
      return
    end

    local config = config_module.get_config(detail)
    if not config or not config.content then
      vim.notify("Failed to get configuration", vim.log.levels.ERROR)
      return
    end

    config.content.highlight_lines = {
      { start_line, end_line, static.config.highlight_color },
    }

    local parent_dir = vim.fs.dirname(resolved_path)
    if parent_dir and parent_dir ~= "" and vim.fn.isdirectory(parent_dir) == 0 then
      vim.fn.mkdir(parent_dir, "p")
    end

    generator.save(resolved_path, config)
    pcall(vim.cmd, "delmarks <>")
    vim.notify("Save snapshot in " .. resolved_path .. " successfully", vim.log.levels.INFO)
  end)
end

return main
