local config = require("r.config").get_config()

--- Create maps.
--- For each noremap we need a vnoremap including <Esc> before the :call,
--- otherwise nvim will call the function as many times as the number of selected
--- lines. If we put <Esc> in the noremap, nvim will bell.
---@param mode string Modes to which create maps (normal, visual and insert)
--- and whether the cursor have to go the beginning of the line
---@param plug string The "<Plug>" name.
---@param combo string Key combination.
---@param target string The command or function to be called.
local create_maps = function(mode, plug, combo, target)
    if config.disable_cmds.plug then
        return
    end
    local tg
    local il
    if mode:find('0') then
        tg = target .. '<CR>0'
        il = 'i'
    elseif mode:find('%.') then
        tg = target
        il = 'a'
    else
        tg = target .. '<CR>'
        il = 'a'
    end
    local opts = { silent = true, noremap = true, expr = false }
    if mode:find("n") then
        vim.api.nvim_buf_set_keymap(0, 'n', '<Plug>' .. plug, tg, opts)
        if not config.user_maps_only and vim.fn.hasmapto('<Plug>' .. plug, "n") == 0 then
            vim.api.nvim_buf_set_keymap(0, 'n', '<LocalLeader>' .. combo, '<Plug>' .. plug, opts)
        end
    end
    if mode:find("v") then
        vim.api.nvim_buf_set_keymap(0, 'v', '<Plug>' .. plug, '<Esc>' .. tg, opts)
        if not config.user_maps_only and vim.fn.hasmapto('<Plug>' .. plug, "v") == 0 then
            vim.api.nvim_buf_set_keymap(0, 'v', '<LocalLeader>' .. combo, '<Esc>' .. tg, opts)
        end
    end
    if config.insert_mode_cmds and mode:find("i") then
        vim.api.nvim_buf_set_keymap(0, 'i', '<Plug>' .. plug, '<Esc>' .. tg .. il, opts)
        if not config.user_maps_only and vim.fn.hasmapto('<Plug>' .. plug, "i") == 0 then
            vim.api.nvim_buf_set_keymap(0, 'i', '<LocalLeader>' .. combo, '<Esc>' .. tg .. il, opts)
        end
    end
end

local control = function(file_type)
    -- List space, clear console, clear all
    create_maps('nvi', 'RListSpace',    'rl', ':lua require("r.send").cmd("ls()")')
    create_maps('nvi', 'RClearConsole', 'rr', ':call RClearConsole()')
    create_maps('nvi', 'RClearAll',     'rm', ':call RClearAll()')

    -- Print, names, structure
    create_maps('ni', 'RObjectPr',    'rp', ':call RAction("print")')
    create_maps('ni', 'RObjectNames', 'rn', ':call RAction("nvim.names")')
    create_maps('ni', 'RObjectStr',   'rt', ':call RAction("str")')
    create_maps('ni', 'RViewDF',      'rv', ':call RAction("viewobj")')
    create_maps('ni', 'RViewDFs',     'vs', ':call RAction("viewobj", ", howto=\'split\'")')
    create_maps('ni', 'RViewDFv',     'vv', ':call RAction("viewobj", ", howto=\'vsplit\'")')
    create_maps('ni', 'RViewDFa',     'vh', ':call RAction("viewobj", ", howto=\'above 7split\', nrows=6")')
    create_maps('ni', 'RDputObj',     'td', ':call RAction("dputtab")')

    create_maps('v', 'RObjectPr',     'rp', ':call RAction("print", "v")')
    create_maps('v', 'RObjectNames',  'rn', ':call RAction("nvim.names", "v")')
    create_maps('v', 'RObjectStr',    'rt', ':call RAction("str", "v")')
    create_maps('v', 'RViewDF',       'rv', ':call RAction("viewobj", "v")')
    create_maps('v', 'RViewDFs',      'vs', ':call RAction("viewobj", "v", ", howto=\'split\'")')
    create_maps('v', 'RViewDFv',      'vv', ':call RAction("viewobj", "v", ", howto=\'vsplit\'")')
    create_maps('v', 'RViewDFa',      'vh', ':call RAction("viewobj", "v", ", howto=\'above 7split\', nrows=6")')
    create_maps('v', 'RDputObj',      'td', ':call RAction("dputtab", "v")')

    -- Arguments, example, help
    create_maps('nvi', 'RShowArgs',   'ra', ':call RAction("args")')
    create_maps('nvi', 'RShowEx',     're', ':call RAction("example")')
    create_maps('nvi', 'RHelp',       'rh', ':call RAction("help")')

    -- Summary, plot, both
    create_maps('ni', 'RSummary',     'rs', ':call RAction("summary")')
    create_maps('ni', 'RPlot',        'rg', ':call RAction("plot")')
    create_maps('ni', 'RSPlot',       'rb', ':call RAction("plotsumm")')

    create_maps('v', 'RSummary',      'rs', ':call RAction("summary", "v")')
    create_maps('v', 'RPlot',         'rg', ':call RAction("plot", "v")')
    create_maps('v', 'RSPlot',        'rb', ':call RAction("plotsumm", "v")')

    -- Object Browser
    create_maps('nvi', 'RUpdateObjBrowser', 'ro', ':lua require("r.browser").start()')
    create_maps('nvi', 'ROpenLists',        'r=', ':lua require("r.browser").open_close_lists("O")')
    create_maps('nvi', 'RCloseLists',       'r-', ':lua require("r.browser").open_close_lists("C")')

    -- Render script with rmarkdown
    create_maps('nvi', 'RMakeRmd',    'kr', ':call RMakeRmd("default")')
    create_maps('nvi', 'RMakeAll',    'ka', ':call RMakeRmd("all")')
    if file_type == "quarto" then
        create_maps('nvi', 'RMakePDFK',   'kp', ':call RMakeRmd("pdf")')
        create_maps('nvi', 'RMakePDFKb',  'kl', ':call RMakeRmd("beamer")')
        create_maps('nvi', 'RMakeWord',   'kw', ':call RMakeRmd("docx")')
        create_maps('nvi', 'RMakeHTML',   'kh', ':call RMakeRmd("html")')
        create_maps('nvi', 'RMakeODT',    'ko', ':call RMakeRmd("odt")')
    else
        create_maps('nvi', 'RMakePDFK',   'kp', ':call RMakeRmd("pdf_document")')
        create_maps('nvi', 'RMakePDFKb',  'kl', ':call RMakeRmd("beamer_presentation")')
        create_maps('nvi', 'RMakeWord',   'kw', ':call RMakeRmd("word_document")')
        create_maps('nvi', 'RMakeHTML',   'kh', ':call RMakeRmd("html_document")')
        create_maps('nvi', 'RMakeODT',    'ko', ':call RMakeRmd("odt_document")')
    end
end

local start = function()
    -- Start
    create_maps('nvi', 'RStart',       'rf', ':lua require("r.run").start_R("R")')
    create_maps('nvi', 'RCustomStart', 'rc', ':lua require("r.run").start_R("custom")')

    -- Close
    create_maps('nvi', 'RClose',       'rq', ":lua require('r.run').quit_R('nosave')")
    create_maps('nvi', 'RSaveClose',   'rw', ":lua require('r.run').quit_R('save')")
end

local edit = function()
    -- Edit
    -- Replace <M--> with ' <- '
    if config.assign then
        vim.api.nvim_buf_set_keymap(0, 'i', config.assign_map, '<Esc>:lua require("r.edit").assign()<CR>a', {silent = true})
    end
    create_maps('nvi', 'RSetwd',    'rd', ':call RSetWD()')
end

local send = function(file_type)
    -- Block
    create_maps('ni', 'RSendMBlock',     'bb', ':call SendMBlockToR("silent", "stay")')
    create_maps('ni', 'RESendMBlock',    'be', ':call SendMBlockToR("echo", "stay")')
    create_maps('ni', 'RDSendMBlock',    'bd', ':call SendMBlockToR("silent", "down")')
    create_maps('ni', 'REDSendMBlock',   'ba', ':call SendMBlockToR("echo", "down")')

    -- Function
    create_maps('nvi', 'RSendFunction',  'ff', ':call SendFunctionToR("silent", "stay")')
    create_maps('nvi', 'RDSendFunction', 'fe', ':call SendFunctionToR("echo", "stay")')
    create_maps('nvi', 'RDSendFunction', 'fd', ':call SendFunctionToR("silent", "down")')
    create_maps('nvi', 'RDSendFunction', 'fa', ':call SendFunctionToR("echo", "down")')

    -- Selection
    create_maps('n', 'RSendSelection',   'ss', ':call SendSelectionToR("silent", "stay", "normal")')
    create_maps('n', 'RESendSelection',  'se', ':call SendSelectionToR("echo", "stay", "normal")')
    create_maps('n', 'RDSendSelection',  'sd', ':call SendSelectionToR("silent", "down", "normal")')
    create_maps('n', 'REDSendSelection', 'sa', ':call SendSelectionToR("echo", "down", "normal")')

    create_maps('v', 'RSendSelection',   'ss', ':call SendSelectionToR("silent", "stay")')
    create_maps('v', 'RESendSelection',  'se', ':call SendSelectionToR("echo", "stay")')
    create_maps('v', 'RDSendSelection',  'sd', ':call SendSelectionToR("silent", "down")')
    create_maps('v', 'REDSendSelection', 'sa', ':call SendSelectionToR("echo", "down")')
    create_maps('v', 'RSendSelAndInsertOutput', 'so', ':call SendSelectionToR("echo", "stay", "NewtabInsert")')

    -- Paragraph
    create_maps('ni', 'RSendParagraph',   'pp', ':lua require("r.send").paragraph("silent", "stay")')
    create_maps('ni', 'RESendParagraph',  'pe', ':lua require("r.send").paragraph("echo", "stay")')
    create_maps('ni', 'RDSendParagraph',  'pd', ':lua require("r.send").paragraph("silent", "down")')
    create_maps('ni', 'REDSendParagraph', 'pa', ':lua require("r.send").paragraph("echo", "down")')

    if file_type == "rnoweb" or file_type == "rmd" or file_type == "quarto" then
        create_maps('ni', 'RSendChunkFH', 'ch', ':call SendFHChunkToR()')
    end

    -- *Line*
    create_maps('ni',  'RSendLine', 'l', ':lua require("r.send").line("stay")')
    create_maps('ni0', 'RDSendLine', 'd', ':lua require("r.send").line("down")')
    create_maps('ni0', '(RInsertLineOutput)', 'o', ':lua require("r.run").insert_commented()')
    create_maps('v',   '(RInsertLineOutput)', 'o', ':lua require("r").warn("This command does not work over a selection of lines.")')
    create_maps('i',   'RSendLAndOpenNewOne', 'q', ':lua require("r.send").line("newline")')
    create_maps('ni.', 'RSendMotion', 'm', ':set opfunc=SendMotionToR<CR>g@')
    create_maps('n',   'RNLeftPart', 'r<left>', ':call RSendPartOfLine("left", 0)')
    create_maps('n',   'RNRightPart', 'r<right>', ':call RSendPartOfLine("right", 0)')
    create_maps('i',   'RILeftPart', 'r<left>', 'l:call RSendPartOfLine("left", 1)')
    create_maps('i',   'RIRightPart', 'r<right>', 'l:call RSendPartOfLine("right", 1)')
    if file_type == "r" then
        create_maps('n', 'RSendAboveLines',  'su', ':require("r.send").above_lines()')
        create_maps('ni', 'RSendFile',  'aa', ':require("r.send").source_file("silent")')
        create_maps('ni', 'RESendFile', 'ae', ':require("r.send").source_file("echo")')
        create_maps('ni', 'RShowRout',  'ao', ':lua require("r").show_R_out()')
    end
    if file_type == "rmd" or file_type == "quarto" then
        create_maps('nvi', 'RKnit',           'kn', ':call RKnit()')
        create_maps('ni',  'RSendChunk',      'cc', ':lua require("r.rmd").send_R_chunk("silent", "stay")')
        create_maps('ni',  'RESendChunk',     'ce', ':lua require("r.rmd").send_R_chunk("echo", "stay")')
        create_maps('ni',  'RDSendChunk',     'cd', ':lua require("r.rmd").send_R_chunk("silent", "down")')
        create_maps('ni',  'REDSendChunk',    'ca', ':lua require("r.rmd").send_R_chunk("echo", "down")')
        create_maps('n',   'RNextRChunk',     'gn', ':lua require("r.rmd").next_chunk()')
        create_maps('n',   'RPreviousRChunk', 'gN', ':lua require("r.rmd").previous_chunk()')
    end
    if file_type == "quarto" then
        create_maps('n', 'RQuartoRender',  'qr', ':lua require("r.quarto").command("render")')
        create_maps('n', 'RQuartoPreview', 'qp', ':lua require("r.quarto").command("preview")')
        create_maps('n', 'RQuartoStop',    'qs', ':lua require("r.quarto").command("stop")')
    end
    if file_type == "rnoweb" then
        create_maps('nvi', 'RSweave',      'sw', ':lua require("r.rnw").weave("nobib", false, false)')
        create_maps('nvi', 'RMakePDF',     'sp', ':lua require("r.rnw").weave("nobib", false, true)')
        create_maps('nvi', 'RBibTeX',      'sb', ':lua require("r.rnw").weave("bibtex", false, true)')
        if config.rm_knit_cache then
            create_maps('nvi', 'RKnitRmCache', 'kr', ':lua require("r.rnw").rm_knit_cache()')
        end
        create_maps('nvi', 'RKnit',        'kn', ':lua require("r.rnw").weave("nobib", true, false)')
        create_maps('nvi', 'RMakePDFK',    'kp', ':lua require("r.rnw").weave("nobib", true, true)')
        create_maps('nvi', 'RBibTeXK',     'kb', ':lua require("r.rnw").weave("bibtex", true, true)')
        create_maps('ni',  'RSendChunk',   'cc', ':lua require("r.rnw").send_chunk("silent", "stay")')
        create_maps('ni',  'RESendChunk',  'ce', ':lua require("r.rnw").send_chunk("echo", "stay")')
        create_maps('ni',  'RDSendChunk',  'cd', ':lua require("r.rnw").send_chunk("silent", "down")')
        create_maps('ni',  'REDSendChunk', 'ca', ':lua require("r.rnw").send_chunk("echo", "down")')
        create_maps('nvi', 'ROpenPDF',     'op', ':lua require("r.pdf").open("Get Master")')
        if config.synctex then
            create_maps('ni', 'RSyncFor',  'gp', ':lua require("r.rnw").SyncTeX_forward(false)')
            create_maps('ni', 'RGoToTeX',  'gt', ':lua require("r.rnw").SyncTeX_forward(true)')
        end
        create_maps('n', 'RNextRChunk',     'gn', ':lua require("r.rnw").next_chunk()')
        create_maps('n', 'RPreviousRChunk', 'gN', ':lua require("r.rnw").previous_chunk()')
    end
end

M = {}

M.create = function (file_type)
    control(file_type)
    if file_type == "rbrowser" then
        return
    end
    send(file_type)
    if file_type == "rdoc" then
        return
    end
    start()
    edit()
end

return M
