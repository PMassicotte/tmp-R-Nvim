"==============================================================================
" Functions that might be called even before R is started.
"
" The functions and variables defined here are common for all buffers of all
" file types supported by Nvim-R and must be defined only once.
"==============================================================================


set encoding=utf-8
scriptencoding utf-8

" Do this only once
if exists("s:did_global_stuff")
    finish
endif
let s:did_global_stuff = 1

" Internal variables
" FIXME: Don't use a global variable when VimScript is completely
" replaced with Lua
let g:rplugin = {
            \ 'debug_info': { 'Time': {'common_global.vim': reltime() } },
            \ 'libs_in_nrs': [],
            \ 'nrs_running': 0,
            \ 'myport': 0,
            \ 'R_pid': 0 }

let g:Rcfg = luaeval('require("r.config").get_config()')

"==============================================================================
" Check if there is more than one copy of Nvim-R
" (e.g. from the Vimballl and from a plugin manager)
"==============================================================================

if exists("*RWarningMsg")
    " A common_global.vim script was sourced from another version of NvimR.
    finish
endif

function UpdateLocalFunctions(...)
    " avoid nvimrclient error until incorporating code from @she3o
endfunction

"==============================================================================
" WarningMsg
"==============================================================================

function RWarningMsg(wmsg)
    exe "lua vim.notify('" . a:wmsg . "', vim.log.levels.WARN, {title = 'Nvim-R'})"
endfunction


"==============================================================================
" Check Vim/Neovim version
"==============================================================================

if !has("nvim-0.6.0")
    call RWarningMsg("Nvim-R requires Neovim >= 0.6.0.")
    let g:rplugin.failed = 1
    finish
endif

" Convert <M--> into <-
function RAssign()
    lua require("r.edit").assign()
endfunction

" Get the word either under or after the cursor.
" Works for word(| where | is the cursor position.
function RGetKeyword()
    " Go back some columns if character under cursor is not valid
    let line = getline(".")
    let i = col(".") - 1
    if strlen(line) == 0
        return ""
    endif
    " line index starts in 0; cursor index starts in 1:
    " Skip opening braces
    while i > 0 && line[i] =~ '(\|\[\|{'
        let i -= 1
    endwhile
    " Go to the beginning of the word
    " See https://en.wikipedia.org/wiki/UTF-8#Codepage_layout
    while i > 0 && line[i-1] =~ '\k\|@\|\$\|\:\|_\|\.' || (line[i-1] > "\x80" && line[i-1] < "\xf5")
        let i -= 1
    endwhile
    " Go to the end of the word
    let j = i
    while line[j] =~ '\k\|@\|\$\|\:\|_\|\.' || (line[j] > "\x80" && line[j] < "\xf5")
        let j += 1
    endwhile
    let rkeyword = strpart(line, i, j - i)
    return rkeyword
endfunction

" Get the name of the first object after the opening parenthesis. Useful to
" call a specific print, summary, ..., method instead of the generic one.
function RGetFirstObj(rkeyword, ...)
    let firstobj = ""
    if a:0 == 3
        let line = substitute(a:1, '#.*', '', "")
        let begin = a:2
        let listdf = a:3
    else
        let line = substitute(getline("."), '#.*', '', "")
        let begin = col(".")
        let listdf = v:false
    endif
    if strlen(line) > begin
        let piece = strpart(line, begin)
        while piece !~ '^' . a:rkeyword && begin >= 0
            let begin -= 1
            let piece = strpart(line, begin)
        endwhile

        " check if the first argument is being passed through a pipe operator
        if begin > 2
            let part1 = strpart(line, 0, begin)
            if part1 =~ '\k\+\s*\(|>\|%>%\)'
                let pipeobj = substitute(part1, '.\{-}\(\k\+\)\s*\(|>\|%>%\)\s*', '\1', '')
                return [pipeobj, v:true]
            endif
        endif
        let pline = substitute(getline(line('.') - 1), '#.*$', '', '')
        if pline =~ '\k\+\s*\(|>\|%>%\)\s*$'
            let pipeobj = substitute(pline, '.\{-}\(\k\+\)\s*\(|>\|%>%\)\s*$', '\1', '')
            return [pipeobj, v:true]
        endif

        let line = piece
        if line !~ '^\k*\s*('
            return [firstobj, v:false]
        endif
        let begin = 1
        let linelen = strlen(line)
        while line[begin] != '(' && begin < linelen
            let begin += 1
        endwhile
        let begin += 1
        let line = strpart(line, begin)
        let line = substitute(line, '^\s*', '', "")
        if (line =~ '^\k*\s*(' || line =~ '^\k*\s*=\s*\k*\s*(') && line !~ '[.*('
            let idx = 0
            while line[idx] != '('
                let idx += 1
            endwhile
            let idx += 1
            let nparen = 1
            let len = strlen(line)
            let lnum = line(".")
            while nparen != 0
                if idx == len
                    let lnum += 1
                    while lnum <= line("$") && strlen(substitute(getline(lnum), '#.*', '', "")) == 0
                        let lnum += 1
                    endwhile
                    if lnum > line("$")
                        return ["", v:false]
                    endif
                    let line = line . substitute(getline(lnum), '#.*', '', "")
                    let len = strlen(line)
                endif
                if line[idx] == '('
                    let nparen += 1
                else
                    if line[idx] == ')'
                        let nparen -= 1
                    endif
                endif
                let idx += 1
            endwhile
            let firstobj = strpart(line, 0, idx)
        elseif line =~ '^\(\k\|\$\)*\s*[' || line =~ '^\(k\|\$\)*\s*=\s*\(\k\|\$\)*\s*[.*('
            let idx = 0
            while line[idx] != '['
                let idx += 1
            endwhile
            let idx += 1
            let nparen = 1
            let len = strlen(line)
            let lnum = line(".")
            while nparen != 0
                if idx == len
                    let lnum += 1
                    while lnum <= line("$") && strlen(substitute(getline(lnum), '#.*', '', "")) == 0
                        let lnum += 1
                    endwhile
                    if lnum > line("$")
                        return ["", v:false]
                    endif
                    let line = line . substitute(getline(lnum), '#.*', '', "")
                    let len = strlen(line)
                endif
                if line[idx] == '['
                    let nparen += 1
                else
                    if line[idx] == ']'
                        let nparen -= 1
                    endif
                endif
                let idx += 1
            endwhile
            let firstobj = strpart(line, 0, idx)
        else
            let firstobj = substitute(line, ').*', '', "")
            let firstobj = substitute(firstobj, ',.*', '', "")
            let firstobj = substitute(firstobj, ' .*', '', "")
        endif
    endif

    if firstobj =~ "="
        let firstobj = ""
    endif

    if firstobj[0] == '"' || firstobj[0] == "'"
        let firstobj = "#c#"
    elseif firstobj[0] >= "0" && firstobj[0] <= "9"
        let firstobj = "#n#"
    endif


    if firstobj =~ '"'
        let firstobj = substitute(firstobj, '"', '\\"', "g")
    endif

    return [firstobj, v:false]
endfunction

function ROpenPDF(fullpath)
    exe 'lua require("r.pdf").open("' . a:fullpath . '")'
endfunction

function RCreateMaps(type, plug, combo, target)
    exe 'lua require("r.maps").create("' . a:type . '", "' . a:plug . '", "' .  a:combo . '" , "' .  substitute(a:target, '"', '\\"', 'g') . '")'
endfunction

function RControlMaps()
    lua require("r.maps").control()
endfunction

function RCreateStartMaps()
    lua require("r.maps").start()
endfunction

function RCreateEditMaps()
    lua require("r.maps").edit()
endfunction

function RCreateSendMaps()
    lua require("r.maps").send()
endfunction

function RBufEnter()
    lua require("r.edit").buf_enter()
endfunction

" Store list of files to be deleted on VimLeave
function AddForDeletion(fname)
    exe 'lua require("r.edit").add_for_deletion("' . a:fname . '")'
endfunction

" Function to send commands
" return 0 on failure and 1 on success
function SendCmdToR_fake(...)
    call RWarningMsg("Did you already start R?")
    return 0
endfunction

function StartR(whatr)
    if !exists("*ReallyStartR")
        exe "source " . substitute(g:rplugin.home, " ", "\\ ", "g") . "/R/start_r.vim"
    endif
    let g:rplugin.debug_info['Time']['start_R'] = reltime()
    call ReallyStartR(a:whatr)
endfunction

function AutoStartR(...)
    if string(g:SendCmdToR) != "function('SendCmdToR_fake')"
        return
    endif
    if v:vim_did_enter == 0 || g:rplugin.nrs_running == 0
        call timer_start(100, 'AutoStartR')
        return
    endif
    call StartR("R")
endfunction

command -nargs=1 -complete=customlist,RLisObjs Rinsert :call RInsert(<q-args>, "here")
command -range=% Rformat <line1>,<line2>:call RFormatCode()
command RBuildTags :call RBuildTags()
command -nargs=? -complete=customlist,RLisObjs Rhelp :call RAskHelp(<q-args>)
command -nargs=? -complete=dir RSourceDir :call RSourceDirectory(<q-args>)
command RStop :call SignalToR('SIGINT')
command RKill :call SignalToR('SIGKILL')
command -nargs=? RSend :call g:SendCmdToR(<q-args>)
command RDebugInfo :lua require("r.edit").show_debug_info()

"==============================================================================
" Temporary links to be deleted when start_r.vim is sourced

function RNotRunning(...)
    echohl WarningMsg
    echon "R is not running"
    echohl None
endfunction

let g:RAction = function('RNotRunning')
let g:RAskHelp = function('RNotRunning')
let g:RBrOpenCloseLs = function('RNotRunning')
let g:RBuildTags = function('RNotRunning')
let g:RClearAll = function('RNotRunning')
let g:RClearConsole = function('RNotRunning')
let g:RFormatCode = function('RNotRunning')
let g:RInsert = function('RNotRunning')
let g:RMakeRmd = function('RNotRunning')
let g:RObjBrowser = function('RNotRunning')
let g:RQuit = function('RNotRunning')
let g:RSendPartOfLine = function('RNotRunning')
let g:RSourceDirectory = function('RNotRunning')
let g:SendCmdToR = function('SendCmdToR_fake')
let g:SendFileToR = function('SendCmdToR_fake')
let g:SendFunctionToR = function('RNotRunning')
let g:SendLineToR = function('RNotRunning')
let g:SendLineToRAndInsertOutput = function('RNotRunning')
let g:SendMBlockToR = function('RNotRunning')
let g:SendParagraphToR = function('RNotRunning')
let g:SendSelectionToR = function('RNotRunning')
let g:SignalToR = function('RNotRunning')


"==============================================================================
" Global variables
" Convention: R_        for user options
"             rplugin_  for internal parameters
"==============================================================================

" g:rplugin.home should be the directory where the plugin files are.
" For users installing the plugin from the Vimball it will be at
" either ~/.vim or ~/vimfiles.
let g:rplugin.home = expand("<sfile>:h:h")

" g:rplugin.uservimfiles must be a writable directory. It will be g:rplugin.home
" unless it's not writable. Then it wil be ~/.vim or ~/vimfiles.
if filewritable(g:rplugin.home) == 2
    let g:rplugin.uservimfiles = g:rplugin.home
else
    let g:rplugin.uservimfiles = split(&runtimepath, ",")[0]
endif

" From changelog.vim, with bug fixed by "Si" ("i5ivem")
" Windows logins can include domain, e.g: 'DOMAIN\Username', need to remove
" the backslash from this as otherwise cause file path problems.
if $LOGNAME != ""
    let g:rplugin.userlogin = $LOGNAME
elseif $USER != ""
    let g:rplugin.userlogin = $USER
elseif $USERNAME != ""
    let g:rplugin.userlogin = $USERNAME
elseif $HOME != ""
    let g:rplugin.userlogin = substitute($HOME, '.*/', '', '')
elseif executable("whoami")
    silent let g:rplugin.userlogin = system('whoami')
else
    call RWarningMsg("Could not determine user name.")
    let g:rplugin.failed = 1
    finish
endif
let g:rplugin.userlogin = substitute(substitute(g:rplugin.userlogin, '.*\\', '', ''), '\W', '', 'g')
if g:rplugin.userlogin == ""
    call RWarningMsg("Could not determine user name.")
    let g:rplugin.failed = 1
    finish
endif

if has("win32")
    let g:rplugin.home = substitute(g:rplugin.home, "\\", "/", "g")
    let g:rplugin.uservimfiles = substitute(g:rplugin.uservimfiles, "\\", "/", "g")
endif

if has_key(g:Rcfg, "compldir")
    let g:rplugin.compldir = expand(g:Rcfg.compldir)
elseif has("win32") && $APPDATA != "" && isdirectory($APPDATA)
    let g:rplugin.compldir = $APPDATA . "\\Nvim-R"
elseif $XDG_CACHE_HOME != "" && isdirectory($XDG_CACHE_HOME)
    let g:rplugin.compldir = $XDG_CACHE_HOME . "/Nvim-R"
elseif isdirectory(expand("~/.cache"))
    let g:rplugin.compldir = expand("~/.cache/Nvim-R")
elseif isdirectory(expand("~/Library/Caches"))
    let g:rplugin.compldir = expand("~/Library/Caches/Nvim-R")
else
    let g:rplugin.compldir = g:rplugin.uservimfiles . "/R/objlist/"
endif

" Create the directory if it doesn't exist yet
if !isdirectory(g:rplugin.compldir)
    call mkdir(g:rplugin.compldir, "p")
endif

if filereadable(g:rplugin.compldir . "/uname")
    if readfile(g:rplugin.compldir . "/uname")[0] =~ "Darwin"
        let g:rplugin.is_darwin = v:true
    endif
else
    silent let s:uname = system("uname")
    if s:uname =~ "Darwin"
        let g:rplugin.is_darwin = v:true
    endif
    call writefile([s:uname], g:rplugin.compldir . "/uname")
    unlet s:uname
endif

" Create or update the README (omnils_ files will be regenerated if older than
" the README).
let s:need_readme = 0
let s:first_line = 'Last change in this file: 2023-12-24'
if !filereadable(g:rplugin.compldir . "/README")
    let s:need_readme = 1
else
    if readfile(g:rplugin.compldir . "/README")[0] != s:first_line
        let s:need_readme = 1
    endif
endif
if s:need_readme
    call delete(g:rplugin.compldir . "/nvimcom_info")
    call delete(g:rplugin.compldir . "/pack_descriptions")
    call delete(g:rplugin.compldir . "/path_to_nvimcom")
    let s:flist = split(glob(g:rplugin.compldir . '/fun_*'), "\n")
    let s:flist += split(glob(g:rplugin.compldir . '/omnils_*'), "\n")
    let s:flist += split(glob(g:rplugin.compldir . '/args_*'), "\n")

    " TODO: Delete the line below after the release of a stable version (2022-12-08)
    let s:flist += split(glob(g:rplugin.compldir . '/descr_*'), "\n")

    if len(s:flist)
        for s:f in s:flist
            call delete(s:f)
        endfor
        unlet s:f
    endif
    unlet s:flist
    let s:readme = [s:first_line,
                \ '',
                \ 'The files in this directory were generated by Nvim-R automatically:',
                \ 'The omnils_ and args_ are used for omni completion, the fun_ files for ',
                \ 'syntax highlighting, and the inst_libs for library description in the ',
                \ 'Object Browser. If you delete them, they will be regenerated.',
                \ '',
                \ 'When you load a new version of a library, their files are replaced.',
                \ '',
                \ 'Files corresponding to uninstalled libraries are not automatically deleted.',
                \ 'You should manually delete them if you want to save disk space.',
                \ '',
                \ 'If you delete this README file, all omnils_, args_ and fun_ files will be ',
                \ 'regenerated.',
                \ '',
                \ 'All lines in the omnils_ files have 7 fields with information on the object',
                \ 'separated by the byte \006:',
                \ '',
                \ '  1. Name.',
                \ '',
                \ '  2. Single character representing the Type (look at the function',
                \ '     nvimcom_glbnv_line at R/nvimcom/src/nvimcom.c to know the meaning of the',
                \ '     characters).',
                \ '',
                \ '  3. Class.',
                \ '',
                \ '  4. Either package or environment of the object.',
                \ '',
                \ '  5. If the object is a function, the list of arguments using Vim syntax for',
                \ '     lists (which is the same as Python syntax).',
                \ '',
                \ '  6. Short description.',
                \ '',
                \ '  7. Long description.',
                \ '',
                \ 'Notes:',
                \ '',
                \ '  - There is a final \006 at the end of the line.',
                \ '',
                \ '  - All single quotes are replaced with the byte \x13.',
                \ '',
                \ '  - All \x12 will later be replaced with single quotes.',
                \ '',
                \ '  - Line breaks are indicated by \x14.']

    call writefile(s:readme, g:rplugin.compldir . "/README")
    " Useful to force update of omnils_ files after a change in its format.
    unlet s:readme
endif
unlet s:need_readme
unlet s:first_line

let $NVIMR_COMPLDIR = g:rplugin.compldir

if has_key(g:Rcfg, "tmpdir")
    let g:rplugin.tmpdir = expand(g:Rcfg.tmpdir)
else
    if has("win32")
        if isdirectory($TMP)
            let g:rplugin.tmpdir = $TMP . "/NvimR-" . g:rplugin.userlogin
        elseif isdirectory($TEMP)
            let g:rplugin.tmpdir = $TEMP . "/Nvim-R-" . g:rplugin.userlogin
        else
            let g:rplugin.tmpdir = g:rplugin.uservimfiles . "/R/tmp"
        endif
        let g:rplugin.tmpdir = substitute(g:rplugin.tmpdir, "\\", "/", "g")
    else
        if isdirectory($TMPDIR)
            if $TMPDIR =~ "/$"
                let g:rplugin.tmpdir = $TMPDIR . "Nvim-R-" . g:rplugin.userlogin
            else
                let g:rplugin.tmpdir = $TMPDIR . "/Nvim-R-" . g:rplugin.userlogin
            endif
        elseif isdirectory("/dev/shm")
            let g:rplugin.tmpdir = "/dev/shm/Nvim-R-" . g:rplugin.userlogin
        elseif isdirectory("/tmp")
            let g:rplugin.tmpdir = "/tmp/Nvim-R-" . g:rplugin.userlogin
        else
            let g:rplugin.tmpdir = g:rplugin.uservimfiles . "/R/tmp"
        endif
    endif
endif

" When accessing R remotely, a local tmp directory is used by the
" nvimrserver to save the contents of the ObjectBrowser to avoid traffic
" over the ssh connection
let g:rplugin.localtmpdir = g:rplugin.tmpdir

if has_key(g:Rcfg, "remote_compldir")
    let $NVIMR_REMOTE_COMPLDIR = g:Rcfg.remote_compldir
    let $NVIMR_REMOTE_TMPDIR = g:Rcfg.remote_compldir . '/tmp'
    let g:rplugin.tmpdir = g:Rcfg.compldir . '/tmp'
    if !isdirectory(g:rplugin.tmpdir)
        call mkdir(g:rplugin.tmpdir, "p", 0700)
    endif
else
    let $NVIMR_REMOTE_COMPLDIR = g:rplugin.compldir
    let $NVIMR_REMOTE_TMPDIR = g:rplugin.tmpdir
endif
if !isdirectory(g:rplugin.localtmpdir)
    call mkdir(g:rplugin.localtmpdir, "p", 0700)
endif
let $NVIMR_TMPDIR = g:rplugin.tmpdir

" Default values of some variables

if has('win32') && !(type(g:Rcfg.external_term) == v:t_bool && g:Rcfg.external_term == v:false)
    " Sending multiple lines at once to Rgui on Windows does not work.
    let g:Rcfg.parenblock = 0
else
    let g:Rcfg.parenblock = 1
endif

if type(g:Rcfg.external_term) == v:t_bool && g:Rcfg.external_term == v:false
    let g:Rcfg.nvimpager = 'vertical'
    let g:Rcfg.save_win_pos = 0
    let g:Rcfg.arrange_windows  = 0
else
    let g:Rcfg.nvimpager = 'tab'
endif

if has("win32")
    let g:Rcfg.save_win_pos    = 1
    let g:Rcfg.arrange_windows = 1
else
    let g:Rcfg.save_win_pos    = 0
    let g:Rcfg.arrange_windows = 0
endif

" The environment variables NVIMR_COMPLCB and NVIMR_COMPLInfo must be defined
" before starting the nvimrserver because it needs them at startup.
let g:rplugin.update_glbenv = 0
if type(luaeval("package.loaded['cmp_nvim_r']")) == v:t_dict
    let g:rplugin.update_glbenv = 1
endif
let $NVIMR_COMPLCB = "v:lua.require'cmp_nvim_r'.asynccb"
let $NVIMR_COMPLInfo = "v:lua.require'cmp_nvim_r'.complinfo"

" Look for invalid options

let objbrplace = split(g:Rcfg.objbr_place, ',')
if len(objbrplace) > 2
    call RWarningMsg('Too many options for R_objbr_place.')
    let g:rplugin.failed = 1
    finish
endif
for pos in objbrplace
    if pos !=? 'console' && pos !=? 'script' &&
                \ pos !=# 'left' && pos !=# 'right' &&
                \ pos !=# 'LEFT' && pos !=# 'RIGHT' &&
                \ pos !=# 'above' && pos !=# 'below' &&
                \ pos !=# 'TOP' && pos !=# 'BOTTOM'
        call RWarningMsg('Invalid value for R_objbr_place: "' . pos . ". Please see Nvim-R's documentation.")
        let g:rplugin.failed = 1
        finish
    endif
endfor
unlet pos
unlet objbrplace

"==============================================================================
" Check if default mean of communication with R is OK
"==============================================================================

" Minimum width for the Object Browser
if g:Rcfg.objbr_w < 10
    let g:Rcfg.objbr_w = 10
endif

" Minimum height for the Object Browser
if g:Rcfg.objbr_h < 4
    let g:Rcfg.objbr_h = 4
endif

autocmd BufEnter * call RBufEnter()
if &filetype != "rbrowser"
    autocmd VimLeave * lua require("r.edit").vim_leave()
endif

if v:windowid != 0 && $WINDOWID == ""
    let $WINDOWID = v:windowid
endif

" Current view of the object browser: .GlobalEnv X loaded libraries
let g:rplugin.curview = "None"

exe "source " . substitute(g:rplugin.home, " ", "\\ ", "g") . "/R/nvimrcom.vim"

" SyncTeX options
let g:rplugin.has_wmctrl = 0
let g:rplugin.has_awbt = 0

" Set the name of R executable
if has_key(g:Rcfg, "R_app")
    let g:rplugin.R = g:Rcfg.R_app
    if !has("win32") && !has_key(g:Rcfg, "R_cmd")
        let g:Rcfg.R_cmd = g:Rcfg.R_app
    endif
else
    if has("win32")
        if type(g:Rcfg.external_term) == v:t_bool && g:Rcfg.external_term == v:false
            let g:rplugin.R = "Rterm.exe"
        else
            let g:rplugin.R = "Rgui.exe"
        endif
    else
        let g:rplugin.R = "R"
    endif
endif

" Set the name of R executable to be used in `R CMD`
if has_key(g:Rcfg, "cmd")
    let g:rplugin.Rcmd = g:Rcfg.R_cmd
else
    let g:rplugin.Rcmd = "R"
endif

if exists("g:RStudio_cmd")
    exe "source " . substitute(g:rplugin.home, " ", "\\ ", "g") . "/R/rstudio.vim"
endif

if has("win32")
    exe "source " . substitute(g:rplugin.home, " ", "\\ ", "g") . "/R/windows.vim"
else
    exe "source " . substitute(g:rplugin.home, " ", "\\ ", "g") . "/R/unix.vim"
endif

if g:Rcfg.applescript
    exe "source " . substitute(g:rplugin.home, " ", "\\ ", "g") . "/R/osx.vim"
endif

if type(g:Rcfg.external_term) == v:t_bool && g:Rcfg.external_term == v:false
    exe "source " . substitute(g:rplugin.home, " ", "\\ ", "g") . "/R/nvimbuffer.vim"
endif

function GlobalRInit(...)
    let g:rplugin.debug_info['Time']['GlobalRInit'] = reltime()
    exe 'source ' . substitute(g:rplugin.home, " ", "\\ ", "g") . "/R/start_nrs.vim"
    " Set security variables
    if !has("nvim-0.7.0")
        let $NVIMR_ID = substitute(string(reltimefloat(reltime())), '.*\.', '', '')
        let $NVIMR_SECRET = substitute(string(reltimefloat(reltime())), '.*\.', '', '')
    else
        let $NVIMR_ID = rand(srand())
        let $NVIMR_SECRET = rand()
    end
    call CheckNvimcomVersion()
    let g:rplugin.debug_info['Time']['GlobalRInit'] = reltimefloat(reltime(g:rplugin.debug_info['Time']['GlobalRInit'], reltime()))
endfunction

if v:vim_did_enter == 0
    autocmd VimEnter * call timer_start(1, "GlobalRInit")
else
    call timer_start(1, "GlobalRInit")
endif
let g:rplugin.debug_info['Time']['common_global.vim'] = reltimefloat(reltime(g:rplugin.debug_info['Time']['common_global.vim'], reltime()))
