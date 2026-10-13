local codesnap = require("codesnap")

local function run_generator_function(func)
  xpcall(func, function(err)
    print(err)
  end)
end

local function take_snapshot(take_snapshot_function)
  return function(detail)
    local args = detail.fargs

    -- If command invoked while in visual mode, exit visual mode so marks get populated
    local mode = vim.fn.mode()
    local was_visual = mode:match("[vV\22]") ~= nil
    if was_visual then
      vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("<Esc>", true, false, true), "x", false)
    end
    detail.was_visual = was_visual

    run_generator_function(function()
      take_snapshot_function(args[1], detail)
    end)
  end
end

vim.api.nvim_create_user_command("CodeSnapSave", take_snapshot(codesnap.save), { nargs = "*", range = "%" })
vim.api.nvim_create_user_command("CodeSnap", take_snapshot(codesnap.copy), { nargs = "*", range = "%" })
vim.api.nvim_create_user_command("CodeSnapASCII", take_snapshot(codesnap.copy_ascii), { nargs = "*", range = "%" })
vim.api.nvim_create_user_command(
  "CodeSnapHighlight",
  take_snapshot(codesnap.copy_highlight),
  { nargs = "*", range = "%" }
)
vim.api.nvim_create_user_command(
  "CodeSnapHighlightSave",
  take_snapshot(codesnap.save_highlight),
  { nargs = "*", range = "%" }
)
