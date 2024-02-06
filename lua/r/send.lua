-- TODO: Make the echo/silent option work

local config = require("r.config").get_config()
local warn = require("r").warn
local cursor = require("r.cursor")
local paragraph = require("r.paragraph")

local clean_oxygen_line = function(line)
    if line:find("^%s*#'") then
        local synID = vim.fn.synID(vim.fn.line("."), vim.fn.col("."), 1)
        local synName = vim.fn.synIDattr(synID, "name")
        if synName == "rOExamples" then line = string.gsub(line, "^%s*#'", "") end
    end
    return line
end

local clean_current_line = function()
    local lnum = vim.fn.line(".")
    local curline = vim.api.nvim_buf_get_lines(0, lnum, lnum, true)[1]
    curline = string.gsub(curline, "^%s*", "")
    if vim.bo.filetype == "r" then curline = clean_oxygen_line(curline) end
    return curline
end

local M = {}

M.set_send_cmd_fun = function()
    if config.RStudio_cmd then
        M.cmd = require("r.rstudio").send_cmd_to_RStudio
    elseif type(config.external_term) == "boolean" and config.external_term == false then
        M.cmd = require("r.term").send_cmd_to_term
    elseif config.is_windows then
        M.cmd = require("r.windows").send_cmd_to_Rgui
    elseif config.is_darwin and config.applescript then
        M.cmd = require("r.osx").send_cmd_to_Rapp
    else
        M.cmd = require("r.external_term").send_cmd_to_external_term
    end
    vim.g.R_Nvim_status = 7
end

M.not_ready = function(_) require("r").warn("R is not ready yet.") end

--- Send a string to R Console.
---@param _ string The line to be sent.
M.not_running = function(_) require("r").warn("Did you start R?") end

M.cmd = M.not_running

M.get_source_args = function(e)
    -- local sargs = config.source_args or ''
    local sargs = ""
    if config.source_args ~= "" then sargs = ", " .. config.source_args end

    if e == "echo" then sargs = sargs .. ", echo=TRUE" end
    return sargs
end

M.source_lines = function(lines, verbose, what)
    require("r.edit").add_for_deletion(config.source_write)

    if vim.o.filetype == "rmd" or vim.o.filetype == "quarto" then
        lines =
            vim.fn.map(vim.deepcopy(lines), 'substitute(v:val, "^\\(``\\)\\?", "", "")')
    end

    if what and what == "NewtabInsert" then
        vim.fn.writefile(lines, config.source_write)
        require("r.run").send_to_nvimcom(
            "E",
            'nvimcom:::nvim_capture_source_output("'
                .. config.source_read
                .. '", "NewtabInsert")'
        )
        return 1
    end

    local rcmd

    -- The "bracketed paste" option is not documented because it is not well
    -- tested and source() have always worked flawlessly.
    -- FIXME: document it
    if config.source_args == "bracketed paste" then
        rcmd = "\033[200~" .. table.concat(lines, "\n") .. "\033[201~"
    else
        vim.fn.writefile(lines, config.source_write)
        local sargs = string.gsub(M.get_source_args(verbose), "^, ", "")
        if what then
            rcmd = "NvimR." .. what .. "(" .. sargs .. ")"
        else
            rcmd = "NvimR.source(" .. sargs .. ")"
        end
    end

    if what and what == "PythonCode" then
        rcmd = 'reticulate::py_run_file("' .. config.source_read .. '")'
    end

    local ok = M.cmd(rcmd)
    return ok
end

M.above_lines = function()
    local lines = vim.api.nvim_buf_get_lines(0, 1, vim.fn.line(".") - 1, false)

    -- Remove empty lines from the end of the list
    local result =
        table.concat(vim.tbl_filter(function(line) return line ~= "" end, lines), "\n")

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

    local lines = vim.api.nvim_buf_get_lines(0, start_line, end_line, false)
    M.cmd(table.concat(lines, "\n"))

    if m == "down" then cursor.move_next_paragraph() end
end

M.line = function(m)
    local current_line = vim.fn.line(".")
    local line = vim.api.nvim_buf_get_lines(0, current_line - 1, current_line, false)[1]
    if line == "" and m == "down" then cursor.move_next_line() end

    M.cmd(line)

    if m == "down" then cursor.move_next_line() end
end

M.line_part = function(direction, correctpos)
    local lin = vim.api.nvim_buf_get_lines(0, vim.fn.line("."), vim.fn.line("."), true)[1]
    local idx = vim.fn.col(".") - 1
    if correctpos then vim.fn.cursor(vim.fn.line("."), idx) end
    local rcmd
    if direction == "right" then
        rcmd = string.sub(lin, idx + 1)
    else
        rcmd = string.sub(lin, 1, idx + 1)
    end
    M.cmd(rcmd)
end

-- Send the current function
M.fun = function()
    warn(
        "Sending function not implemented. It will be either implemented using treesitter or never implemented."
    )
end

return M
