if vim.fn.exists("g:R_filetypes") == 1 and type(vim.g.R_filetypes) == "table" and vim.fn.index(vim.g.R_filetypes, 'rnoweb') == -1 then
    return
end

require("r.config").real_setup()

local config = require("r.config").get_config()

if config.rnowebchunk then
    -- Write code chunk in rnoweb files
    vim.api.nvim_buf_set_keymap(0, 'i', "<", "<Esc>:lua require('r.rnw').write_chunk()<CR>a", {silent = true})
end

-- Pointers to functions whose purposes are the same in rnoweb, rmd,
-- rhelp and rdoc and which are called at common_global.vim
-- FIXME: replace with references to Lua functions when they are written.
vim.b.IsInRCode = require("r.rnw").is_in_R_code

vim.api.nvim_buf_set_var(0, "rplugin_knitr_pattern", "^<<.*>>=$")

-- Key bindings
require("r.maps").create("rnoweb")

vim.schedule(function ()
    require("r.pdf").setup()
    require("r.rnw").set_pdf_dir()
end)

-- FIXME: not working:
if vim.fn.exists("b:undo_ftplugin") == 1 then
    vim.api.nvim_buf_set_var(0, "undo_ftplugin", vim.b.undo_ftplugin .. " | unlet! b:IsInRCode")
else
    vim.api.nvim_buf_set_var(0, "undo_ftplugin", "unlet! b:IsInRCode")
end
