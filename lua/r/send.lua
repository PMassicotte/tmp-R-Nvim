-- TODO: Make the echo/silent option work

local M = {}

local config = require('r.config')
local cursor = require('r.cursor')
local paragraph = require('r.paragraph')

M.not_ready = function(_)
  require('r').warn('R is not ready yet.')
end

M.cmd = function(_)
  require('r').warn('Did you start R?')
end

M.GetSourceArgs = function(e)
  -- local sargs = config.get_config().source_args or ''
  local sargs = ''
  if config.get_config().source_args ~= '' then
    sargs = ', ' .. config.get_config().source_args
  end

  if e == 'echo' then
    sargs = sargs .. ', echo=TRUE'
  end
  return sargs
end

M.above_lines = function()
  local lines = vim.fn.getline(1, vim.fn.line('.') - 1)

  -- Remove empty lines from the end of the list
  local result = table.concat(
    vim.tbl_filter(function(line)
      return line ~= ''
    end, lines),
    '\n'
  )

  M.cmd(result)
end

M.source_file = function(e)
  local bufnr = 0
  local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
  M.cmd(lines)
end

-- Send the current paragraph to R. If m == 'down', move the cursor to the
-- first line of the next paragraph.
M.paragraph = function(e, m)
  local start_line, end_line = paragraph.get_current()

  local lines = vim.fn.getline(start_line, end_line)
  M.cmd(lines)

  if m == 'down' then
    cursor.move_next_paragraph()
  end
end

M.line = function(m)
  M.cmd(vim.fn.getline(vim.fn.line('.')))
  if m == 'down' then
    cursor.move_next_line()
  end
end

M.line_part = function(direction, correctpos)
  local lin = vim.fn.getline('.')
  local idx = vim.fn.col('.') - 1
  if correctpos then
    vim.fn.cursor(vim.fn.line('.'), idx)
  end
  local rcmd
  if direction == 'right' then
    rcmd = string.sub(lin, idx + 1)
  else
    rcmd = string.sub(lin, 1, idx + 1)
  end
  M.cmd(rcmd)
end

-- Send the current function
M.fun = function()
  local start_line = vim.fn.searchpair('.*<-\\s*function', '', '^}', 'cbnW')
  local end_line = vim.fn.searchpair('.*<-\\s*function', '', '^}$', 'cnW')

  if start_line ~= 0 and start_line <= end_line then
    local lines = vim.fn.getline(start_line, end_line - 1)
    M.cmd(lines)
  else
    require('r').warn('Not inside a function.')
  end
end

-- TODO: Looks like work has been done in rmd.lua to handle this
-- Send the current code chunk
M.chunk = function()
  local start_line = vim.fn.searchpair('```{r', '', '```', 'cbnW')
  local end_line = vim.fn.searchpair('```{r', '', '```', 'cnW')

  if start_line ~= 0 and start_line <= end_line then
    local lines = vim.fn.getline(start_line, end_line - 1)
    M.cmd(lines)
  else
    require('r').warn('Not inside a code chunk.')
  end
end

return M
