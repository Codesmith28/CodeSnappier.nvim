local visual_utils = require("codesnappier.utils.visual")
local path_utils = require("codesnappier.utils.path")
local string_utils = require("codesnappier.utils.string")
local static = require("codesnappier.static")
local table_utils = require("codesnappier.utils.table")
local module = require("codesnappier.module")
local theme_module = require("codesnappier.theme")
local font_utils = require("codesnappier.utils.font")

local config_module = {}

local function generate_diff_highlights(lines, add_color, delete_color, is_strict_diff)
  local highlights = {}
  local current_type = nil
  local start_line = nil

  for i, line in ipairs(lines) do
    local is_add
    local is_del

    if is_strict_diff then
      is_add = line:sub(1, 1) == "+" and not line:match("^%+%+%+")
      is_del = line:sub(1, 1) == "-" and not line:match("^%-%-%-")
    else
      -- In non-diff buffers, only match genuine diff addition/deletion (+/- not followed by +/-)
      is_add = line:match("^%+[^+]") ~= nil
      is_del = line:match("^%-[^%-]") ~= nil
    end

    local line_type = nil
    if is_add then
      line_type = "add"
    elseif is_del then
      line_type = "del"
    end

    if line_type == current_type and current_type ~= nil then
      -- Continue current range
    else
      if current_type ~= nil then
        local color = current_type == "add" and add_color or delete_color
        table.insert(highlights, { start_line, i - 1, color })
      end
      current_type = line_type
      start_line = i
    end
  end

  if current_type ~= nil then
    local color = current_type == "add" and add_color or delete_color
    table.insert(highlights, { start_line, #lines, color })
  end

  return highlights
end

function config_module.get_config(detail)
  local code = visual_utils.get_selected_text(detail)
  local start_line_number = static.config.show_line_number and visual_utils.get_start_line_number(detail) or nil

  if string_utils.is_str_empty(code) then
    error("No code is selected", 0)
    return
  end

  -- Extract active Neovim theme
  local theme_info = theme_module.extract()

  local lines = vim.split(code, "\n", { plain = true })
  local filetype = vim.bo.filetype

  -- Auto diff lines highlighting detection
  local is_diff_ft = (filetype == "diff")
  local has_diff_marker = false
  local has_add = false
  local has_del = false

  for _, line in ipairs(lines) do
    if line:match("^@@ %-%d+") or line:match("^diff %-%-git ") or line:match("^index %x+%.%.%x+") then
      has_diff_marker = true
      break
    end
    if line:match("^%-%-%- [ab]/") or line:match("^%+%+%+ [ab]/") then
      has_diff_marker = true
      break
    end
    if line:match("^%+[^+]") then
      has_add = true
    end
    if line:match("^%-[^%-]") then
      has_del = true
    end
  end

  local is_strict_diff = is_diff_ft or has_diff_marker
  local is_diff = is_strict_diff or (has_add and has_del)

  local highlight_lines = {}
  if is_diff then
    local add_color = (static.config.diff_config and static.config.diff_config.add_color) or theme_info.diff_add
    local delete_color = (static.config.diff_config and static.config.diff_config.delete_color) or theme_info.diff_delete
    highlight_lines = generate_diff_highlights(lines, add_color, delete_color, is_strict_diff)
  end

  local file_path = path_utils.get_breadcrumbs(static.config.show_workspace)

  local code_content = {
    content = code,
    start_line_number = start_line_number,
    file_path = file_path,
    highlight_lines = #highlight_lines > 0 and highlight_lines or nil,
  }

  -- Dynamic title defaulting to current buffer filename
  local title = static.config.snapshot_config.title
  if not title or title == "" then
    local buf_name = vim.fn.expand("%:t")
    title = (buf_name and buf_name ~= "") and buf_name or "code"
  end

  -- Resolve font: User explicit config -> p0 (terminal) -> p1 (system) -> p2 (fallback)
  local explicit_font = static.config.font_family
    or (static.config.snapshot_config and static.config.snapshot_config.font_family)
    or (static.config.snapshot_config and static.config.snapshot_config.code_config and static.config.snapshot_config.code_config.font_family)

  local resolved_font
  if explicit_font and explicit_font ~= "" and explicit_font ~= "auto" then
    resolved_font = explicit_font
  else
    resolved_font = font_utils.get_font()
  end

  local snapshot_config = vim.deepcopy(static.config.snapshot_config)
  snapshot_config.title = title

  -- Apply resolved font to components if not explicitly customized
  if snapshot_config.window and snapshot_config.window.title_config then
    snapshot_config.window.title_config.font_family = snapshot_config.window.title_config.font_family or resolved_font
  end
  if snapshot_config.code_config then
    snapshot_config.code_config.font_family = resolved_font
    if snapshot_config.code_config.breadcrumbs then
      snapshot_config.code_config.breadcrumbs.font_family = snapshot_config.code_config.breadcrumbs.font_family or resolved_font
    end
  end
  if snapshot_config.command_output_config then
    snapshot_config.command_output_config.font_family = snapshot_config.command_output_config.font_family or resolved_font
  end
  if snapshot_config.watermark then
    snapshot_config.watermark.font_family = snapshot_config.watermark.font_family or resolved_font
  end

  -- Line number color default from theme
  if snapshot_config.line_number_color == nil then
    snapshot_config.line_number_color = theme_info.line_number_color or "#495162"
  end

  -- Add theme_dir to themes_folders
  snapshot_config.themes_folders = snapshot_config.themes_folders or {}
  local has_theme_dir = false
  for _, folder in ipairs(snapshot_config.themes_folders) do
    if folder == theme_info.theme_dir then
      has_theme_dir = true
      break
    end
  end
  if not has_theme_dir then
    table.insert(snapshot_config.themes_folders, theme_info.theme_dir)
  end

  local theme_name = snapshot_config.theme
  if theme_name:match("://") or theme_name:match("@") then
    theme_name = module.load_generator().parse_code_theme(theme_name)
  end

  local config = table_utils.assign(snapshot_config, {
    content = code_content,
    theme = theme_name,
  })

  return config
end

return config_module
