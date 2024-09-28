local config = require('aider.config')

local WindowManager = {}

local aider_win = nil

function WindowManager.setup()
  -- Any setup needed for window management
end

function WindowManager.show_aider_window(buf, layout)
  if layout == 'float' then
    WindowManager.create_float_window(buf)
  elseif layout == 'vsplit' then
    WindowManager.create_split_window(buf, 'vertical')
  elseif layout == 'hsplit' then
    WindowManager.create_split_window(buf, 'horizontal')
  else
    error("Invalid layout: " .. layout)
  end
end

function WindowManager.create_float_window(buf)
  local width = math.floor(vim.o.columns * 0.8)
  local height = math.floor(vim.o.lines * 0.8)
  local row = math.floor((vim.o.lines - height) / 2)
  local col = math.floor((vim.o.columns - width) / 2)

  local opts = {
    relative = "editor",
    width = width,
    height = height,
    row = row,
    col = col,
    style = "minimal",
    border = "rounded",
  }

  aider_win = vim.api.nvim_open_win(buf, true, opts)
  vim.api.nvim_win_set_option(aider_win, "winblend", 0)
end

function WindowManager.create_split_window(buf, direction)
  vim.cmd(direction == 'vertical' and 'vsplit' or 'split')
  aider_win = vim.api.nvim_get_current_win()
  vim.api.nvim_win_set_buf(aider_win, buf)
end

function WindowManager.hide_aider_window()
  if aider_win and vim.api.nvim_win_is_valid(aider_win) then
    vim.api.nvim_win_close(aider_win, true)
    aider_win = nil
  end
end

function WindowManager.is_aider_window_open()
  return aider_win ~= nil and vim.api.nvim_win_is_valid(aider_win)
end

return WindowManager
