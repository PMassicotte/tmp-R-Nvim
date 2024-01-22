
function ROpenPDF2(fullpath)
    call system(g:Rcfg.pdfviewer . " '" . a:fullpath . "' 2>/dev/null >/dev/null &")
endfunction

function SyncTeX_forward2(tpath, ppath, texln, tryagain)
    call RWarningMsg("Nvim-R has no support for SyncTeX with '" . g:Rcfg.pdfviewer . "'")
    return
endfunction
