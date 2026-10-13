local visual_utils = {
  _cached_range = nil,
}

-- Get all the lines from "from" to "to" and return them as a single string
-- If "from" and "to" are the same, return the line at "from"
local function get_whole_lines(from, to)
  local lines = {}
  if from > to then
    from, to = to, from
  end
  if from == to then
    local line = vim.api.nvim_buf_get_lines(0, from - 1, from, false)[1]
    if line then
      table.insert(lines, line)
    end
  else
    for i = from, to do
      local line = vim.api.nvim_buf_get_lines(0, i - 1, i, false)[1]
      if line then
        table.insert(lines, line)
      end
    end
  end
  return table.concat(lines, "\n")
end

--- Resolve the selected line range (start_line, end_line)
--- Handles active visual mode, command range detail, or '< and '> marks
--- @param detail table|nil
--- @return number|nil start_line
--- @return number|nil end_line
function visual_utils.resolve_range(detail)
  local mode = vim.fn.mode()
  local is_visual = (mode:match("[vV\22]") ~= nil) or (detail and detail.was_visual)

  -- If currently in visual mode (v, V, or Ctrl-V), exit visual mode immediately
  if mode:match("[vV\22]") then
    local vpos = vim.fn.getpos("v")
    local dotpos = vim.fn.getpos(".")
    vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("<Esc>", true, false, true), "x", false)
    local s = vim.fn.line("'<")
    local e = vim.fn.line("'>")
    if s > 0 and e > 0 then
      visual_utils._cached_range = { math.min(s, e), math.max(s, e) }
      return visual_utils._cached_range[1], visual_utils._cached_range[2]
    end
    if vpos[2] > 0 and dotpos[2] > 0 then
      local s_calc = math.min(vpos[2], dotpos[2])
      local e_calc = math.max(vpos[2], dotpos[2])
      visual_utils._cached_range = { s_calc, e_calc }
      return s_calc, e_calc
    end
  end

  -- If command range was explicitly specified (range > 0)
  if detail and detail.range and detail.range > 0 and detail.line1 and detail.line2 then
    visual_utils._cached_range = { detail.line1, detail.line2 }
    return detail.line1, detail.line2
  end

  -- If was visual mode (e.g. from keymap or command), marks '< and '> are authoritative
  if is_visual then
    local s = vim.fn.line("'<")
    local e = vim.fn.line("'>")
    if s > 0 and e > 0 then
      visual_utils._cached_range = { math.min(s, e), math.max(s, e) }
      return visual_utils._cached_range[1], visual_utils._cached_range[2]
    end
  end

  -- If detail has lines from user command (range == 0, e.g. whole buffer from range = "%")
  if detail and detail.line1 and detail.line2 then
    visual_utils._cached_range = { detail.line1, detail.line2 }
    return detail.line1, detail.line2
  end

  -- Fallback for direct Lua API calls: check marks '< and '> if set
  local s = vim.fn.line("'<")
  local e = vim.fn.line("'>")
  if s > 0 and e > 0 then
    visual_utils._cached_range = { math.min(s, e), math.max(s, e) }
    return visual_utils._cached_range[1], visual_utils._cached_range[2]
  end

  return nil, nil
end

function visual_utils.get_start_line_number(detail)
  local s, _ = visual_utils.resolve_range(detail)
  if s then
    return s
  end
  local mark_s = vim.fn.line("'<")
  return mark_s > 0 and mark_s or 1
end

function visual_utils.get_end_line_number(detail)
  local _, e = visual_utils.resolve_range(detail)
  if e then
    return e
  end
  local mark_e = vim.fn.line("'>")
  return mark_e > 0 and mark_e or vim.fn.line("$")
end

function visual_utils.get_selected_lines(detail)
  local s, e = visual_utils.resolve_range(detail)
  if s and e then
    return vim.api.nvim_buf_get_lines(0, s - 1, e, false)
  end

  local lines = vim.fn.getline("'<", "'>")
  if #lines == 1 and lines[1] == "" and (vim.fn.line("'<") == 0 or vim.fn.line("'>") == 0) then
    return {}
  end
  return lines
end

function visual_utils.get_selected_text(detail)
  local lines = visual_utils.get_selected_lines(detail)
  return table.concat(lines, "\n")
end

function visual_utils.get_selected_text_realtime()
  local start_pos = vim.fn.getpos("v")
  local end_pos = vim.fn.getpos(".")

  -- Switch start and end positions if start is after end
  if start_pos[2] > end_pos[2] or start_pos[3] > end_pos[3] then
    start_pos, end_pos = end_pos, start_pos
  end

  if vim.api.nvim_get_mode().mode == "V" then
    return get_whole_lines(start_pos[2], end_pos[2])
  end

  if start_pos[2] == end_pos[2] then
    local line = vim.api.nvim_buf_get_lines(0, start_pos[2] - 1, start_pos[2], false)[1] or ""
    return line:sub(start_pos[3], end_pos[3] - 1)
  end

  local selected_text = {}
  for i = start_pos[2], end_pos[2] do
    local line_text = vim.api.nvim_buf_get_lines(0, i - 1, i, false)[1] or ""
    if i == start_pos[2] then
      line_text = line_text:sub(start_pos[3])
    end
    if i == end_pos[2] then
      line_text = line_text:sub(1, end_pos[3] - 1)
    end
    table.insert(selected_text, line_text)
  end

  return table.concat(selected_text, "\n")
end

return visual_utils
