local font_utils = require("codesnappier.utils.font")
local path_utils = require("codesnappier.utils.path")

local detected_font = font_utils.get_font()

return {
  config = {
    font_family = nil, -- Optional explicit font. When nil/auto, follows p0 (terminal) -> p1 (system) -> p2 (fallback)
    show_line_number = true,
    diff_config = {
      add_color = "#98C37960",
      delete_color = "#E06C7550",
    },
    highlight_color = "#ffffff20",
    show_workspace = true,
    snapshot_config = {
      theme = "nvim_theme",
      title = nil,
      window = {
        mac_window_bar = true,
        shadow = {
          radius = 0,
          color = "#00000000",
        },
        margin = {
          x = 20,
          y = 20,
        },
        border = {
          width = 0,
          color = "#00000000",
        },
        title_config = {
          color = "#ffffff",
          font_family = detected_font,
        },
        radius = 12,
      },
      themes_folders = {},
      fonts_folders = {},
      line_number_color = nil,
      command_output_config = {
        prompt = "❯",
        font_family = detected_font,
        prompt_color = "#F78FB3",
        command_color = "#98C379",
        string_arg_color = "#ff0000",
      },
      code_config = {
        font_family = detected_font,
        breadcrumbs = {
          enable = true,
          separator = "/",
          color = "#80848b",
          font_family = detected_font,
        },
      },
      watermark = nil,
      background = "#00000000",
    },
  },
  cwd = path_utils.back(path_utils.back(debug.getinfo(1, "S").source:sub(2):match("(.*[/\\])"))),
}
