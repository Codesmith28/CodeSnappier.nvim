local theme = {}

local function to_hex(color)
  if not color then
    return nil
  end
  if type(color) == "string" then
    return color
  end
  return string.format("#%06x", color)
end

local function get_hl(group_name)
  local ok, hl = pcall(vim.api.nvim_get_hl, 0, { name = group_name, link = false })
  if ok and hl then
    return hl
  end
  return {}
end

local _cached_theme = nil
local _cached_colors_name = nil
local _cached_bg = nil

--- Extract colors from active Neovim colorscheme and generate TextMate plist XML theme
--- @return table { theme_dir = string, theme_name = string, bg = string, fg = string, line_number_color = string, diff_add = string, diff_delete = string }
function theme.extract()
  local colors_name = vim.g.colors_name or ""
  local bg_mode = vim.o.background or "dark"

  if _cached_theme and _cached_colors_name == colors_name and _cached_bg == bg_mode then
    return _cached_theme
  end
  local normal = get_hl("Normal")
  local comment = get_hl("Comment")
  local string_hl = get_hl("String")
  local keyword = get_hl("Keyword")
  local func = get_hl("Function")
  local type_hl = get_hl("Type")
  local number = get_hl("Number")
  local constant = get_hl("Constant")
  local identifier = get_hl("Identifier")
  local line_nr = get_hl("LineNr")
  local diff_add = get_hl("DiffAdd")
  local diff_delete = get_hl("DiffDelete")

  local bg_hex = to_hex(normal.bg) or "#1e1e2e"
  local fg_hex = to_hex(normal.fg) or "#cdd6f4"

  local comment_fg = to_hex(comment.fg) or "#6c7086"
  local comment_italic = comment.italic == true or (type(comment.cterm) == "table" and comment.cterm.italic == true)

  local string_fg = to_hex(string_hl.fg) or fg_hex
  local keyword_fg = to_hex(keyword.fg) or fg_hex
  local func_fg = to_hex(func.fg) or fg_hex
  local type_fg = to_hex(type_hl.fg) or fg_hex
  local number_fg = to_hex(number.fg) or fg_hex
  local constant_fg = to_hex(constant.fg) or number_fg
  local identifier_fg = to_hex(identifier.fg) or fg_hex

  local line_nr_hex = to_hex(line_nr.fg) or "#6c7086"
  local diff_add_hex = to_hex(diff_add.bg) or to_hex(diff_add.fg) or "#a6e3a1"
  local diff_delete_hex = to_hex(diff_delete.bg) or to_hex(diff_delete.fg) or "#f38ba8"

  local theme_dir = vim.fn.stdpath("cache") .. "/codesnappier"
  vim.fn.mkdir(theme_dir, "p")
  local theme_file = theme_dir .. "/nvim_theme.tmTheme"

  local font_style_tag = comment_italic and "\n\t\t\t\t<key>fontStyle</key>\n\t\t\t\t<string>italic</string>" or ""

  local xml_content = string.format([[<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>name</key>
	<string>nvim_theme</string>
	<key>settings</key>
	<array>
		<dict>
			<key>settings</key>
			<dict>
				<key>background</key>
				<string>%s</string>
				<key>foreground</key>
				<string>%s</string>
				<key>caret</key>
				<string>%s</string>
				<key>lineHighlight</key>
				<string>%s</string>
			</dict>
		</dict>
		<dict>
			<key>name</key>
			<string>Comment</string>
			<key>scope</key>
			<string>comment</string>
			<key>settings</key>
			<dict>
				<key>foreground</key>
				<string>%s</string>%s
			</dict>
		</dict>
		<dict>
			<key>name</key>
			<string>String</string>
			<key>scope</key>
			<string>string</string>
			<key>settings</key>
			<dict>
				<key>foreground</key>
				<string>%s</string>
			</dict>
		</dict>
		<dict>
			<key>name</key>
			<string>Keyword</string>
			<key>scope</key>
			<string>keyword, storage</string>
			<key>settings</key>
			<dict>
				<key>foreground</key>
				<string>%s</string>
			</dict>
		</dict>
		<dict>
			<key>name</key>
			<string>Function</string>
			<key>scope</key>
			<string>entity.name.function, support.function</string>
			<key>settings</key>
			<dict>
				<key>foreground</key>
				<string>%s</string>
			</dict>
		</dict>
		<dict>
			<key>name</key>
			<string>Type</string>
			<key>scope</key>
			<string>entity.name.type, support.type, storage.type</string>
			<key>settings</key>
			<dict>
				<key>foreground</key>
				<string>%s</string>
			</dict>
		</dict>
		<dict>
			<key>name</key>
			<string>Number</string>
			<key>scope</key>
			<string>constant.numeric</string>
			<key>settings</key>
			<dict>
				<key>foreground</key>
				<string>%s</string>
			</dict>
		</dict>
		<dict>
			<key>name</key>
			<string>Constant</string>
			<key>scope</key>
			<string>constant</string>
			<key>settings</key>
			<dict>
				<key>foreground</key>
				<string>%s</string>
			</dict>
		</dict>
		<dict>
			<key>name</key>
			<string>Identifier</string>
			<key>scope</key>
			<string>variable, variable.other</string>
			<key>settings</key>
			<dict>
				<key>foreground</key>
				<string>%s</string>
			</dict>
		</dict>
		<dict>
			<key>name</key>
			<string>Diff Add</string>
			<key>scope</key>
			<string>markup.inserted</string>
			<key>settings</key>
			<dict>
				<key>foreground</key>
				<string>%s</string>
			</dict>
		</dict>
		<dict>
			<key>name</key>
			<string>Diff Delete</string>
			<key>scope</key>
			<string>markup.deleted</string>
			<key>settings</key>
			<dict>
				<key>foreground</key>
				<string>%s</string>
			</dict>
		</dict>
	</array>
</dict>
</plist>]],
    bg_hex,
    fg_hex,
    fg_hex,
    bg_hex,
    comment_fg,
    font_style_tag,
    string_fg,
    keyword_fg,
    func_fg,
    type_fg,
    number_fg,
    constant_fg,
    identifier_fg,
    diff_add_hex,
    diff_delete_hex
  )

  local file = io.open(theme_file, "w")
  if file then
    file:write(xml_content)
    file:close()
  end

  _cached_theme = {
    theme_dir = theme_dir,
    theme_name = "nvim_theme",
    bg = bg_hex,
    fg = fg_hex,
    line_number_color = line_nr_hex,
    diff_add = diff_add_hex,
    diff_delete = diff_delete_hex,
  }
  _cached_colors_name = colors_name
  _cached_bg = bg_mode

  return _cached_theme
end

theme.extract_colorscheme = theme.extract

return theme
