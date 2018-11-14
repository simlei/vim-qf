" vim-qf - Tame the quickfix windomw
" Maintainer:	romainl <romainlafourcade@gmail.com>
" Version:	0.2.0
" License:	MIT
" Location:	autoload/qf.vim
" Website:	https://github.com/romainl/vim-qf
"
" Use this command to get help on vim-qf:
"
"     :help qf
"
" If this doesn't work and you installed vim-qf manually, use the following
" command to index vim-qf's documentation:
"
"     :helptags ~/.vim/doc
"
" or read your runtimepath/plugin manager documentation.

let s:save_cpo = &cpo
set cpo&vim

" open the current entry in th preview window
function! qf#PreviewFileUnderCursor()
    let cur_list = b:qf_isLoc == 1 ? getloclist('.') : getqflist()
    let cur_line = getline(line('.'))
    let cur_file = fnameescape(substitute(cur_line, '|.*$', '', ''))
    if cur_line =~ '|\d\+'
        let cur_pos  = substitute(cur_line, '^\(.\{-}|\)\(\d\+\)\(.*\)', '\2', '')
        execute "pedit +" . cur_pos . " " . cur_file
    else
        execute "pedit " . cur_file
    endif
endfunction

" helper function
" returns 1 if the window with the given number is a quickfix window
"         0 if the window with the given number is not a quickfix window
" TODO (Nelo-T. Wallus): make a:nbmr optional and return current window
"                        by default
function! qf#IsQfWindow(nmbr)
    if getwinvar(a:nmbr, "&filetype") == "qf"
        return qf#IsLocWindow(a:nmbr) ? 0 : 1
    endif

    return 0
endfunction

" helper function
" returns 1 if the window with the given number is a location window
"         0 if the window with the given number is not a location window
function! qf#IsLocWindow(nmbr)
    let indicator = 0
    if has('quickfix')
        let indicator = getwininfo(win_getid(a:nmbr))[0]['loclist']
    endif
    return getbufvar(winbufnr(a:nmbr), "qf_isLoc") == 1 || indicator
endfunction


"TODO: doc, rename
function! qf#type(nbr)
    if qf#IsQfWindow(a:nbr)
        return 1
    elseif qf#IsLocWindow(a:nbr)
        return 2
    else
        return 0
    endif
endf

fun! qf#getWinForLoclist(loclistWNr) abort
    if !qf#type(a:loclistWNr)
        echoerr "cannot call qf#getWinForLoclist for a non-loclist"
        return
    endif
    return win_id2win(getloclist(a:loclistWNr, {'filewinid': 0})['filewinid'])
    " let reflist = getloclist(a:loclistWNr)
    " for winnum in range(1, winnr('$'))
    "     if qf#type(winnum) > 0
    "         continue
    "     endif
    "     let loclist = getloclist(winnum)
    "     if loclist ==# reflist
    "         return winnum
    "     endif
    " endfor
    " return -1
endf
fun! qf#getLoclistForWin(winNr) abort
    for winnum in range(1, winnr('$'))
        if qf#type(winnum) != 2
            continue
        endif
        if qf#getWinForLoclist(winnum) == a:winNr
            return winnum
        endif
    endfor
    return -1
    " deprecated, as inflecting getWinForLoclist is more precise
    " let reflist = getloclist(a:winNr)
    " for winnum in range(1, winnr('$'))
    "     if qf#type(winnum) != 2
    "         continue
    "     endif
    "     let loclist = getloclist(winnum)
    "     if loclist ==# reflist
    "         return winnum
    "     endif
    " endfor
    " return -1
endf

" TODO: doc
function! qf#switch(toType, permitReopen, takeAnyLoclist)
    let curtype = qf#type(winnr())
    let curwinnr = winnr()
    if a:toType == 1
        if curtype != 1
            if qf#IsQfWindowOpen()
                exec qf#GetAnyWindow(a:toType)."wincmd w"
                return
                "TODO: unify to use one method
            else
                if a:permitReopen
                    call qf#toggle#ToggleQfWindow(winnr())
                    return
                else
                    "apparenty, nothing happens
                    return
                endif
            endif
        else
            wincmd p
            " no return, may need to de-panic
        endif
    elseif a:toType == 2
        if curtype != 2
            let locForWin = qf#getLoclistForWin(curwinnr)
            if locForWin > -1
                exec locForWin."wincmd w"
                return
            else
                let anyLoc = qf#GetAnyWindow(2)
                if anyLoc > -1
                    if a:takeAnyLoclist
                        exec anyLoc."wincmd w"
                        return
                    else " any loc aint good enough, go to co-if routine
                    endif
                endif
                if a:permitReopen
                    call qf#toggle#ToggleLocWindow(winnr())
                    return
                else
                    " apparently, nothing happens. TODO: not even anyLoc?
                    return
                endif
            endif
        else
            let winnr = qf#getWinForLoclist(winnr())
            if winnr > -1
                exec winnr."wincmd w"
                return
            else
                wincmd p
                " no return, may need to de-panic
            endif
        endif
    endif
    " de-panic after wincmd p (did not return above); when that failed
    if curtype == a:toType
        let afterType = qf#type(winnr())
        " check if we are still in the same type of window. Maybe the window belonging to the loclist was not open. Most likely the jump list got corrupted, that happens frequently. Then: panic and try to find a window that is not the same
        if afterType == curtype
            for winnum in range(1, winnr('$'))
                let tpe = qf#type(winnum)
                if tpe == 0
                    exec winnum."wincmd W"
                endif
            endfor
        endif
    else
        " this should not be necessary
        " for winnum in range(1, winnr('$'))
        "     let tpe = qf#type(winnum)
        "     if tpe == a:toType
        "         exec winnum."wincmd W"
        "         return
        "     endif
        " endfor
    endif
endf

" returns bool: Is quickfix window open?
function! qf#IsQfWindowOpen() abort
    for winnum in range(1, winnr('$'))
        if qf#IsQfWindow(winnum)
            return 1
        endif
    endfor
    return 0
endfunction

" returns bool: Is location window for window with given number open?
function! qf#IsLocWindowOpen(nmbr) abort
    return qf#getLoclistForWin(a:nmbr)>-1
endfunction

" looks for a loc window corresponding to any window.
function! qf#GetAnyWindow(type) abort
    if type(winnr()) == a:type " special treatment for current window to get preference
        return winnr
    endif
    for winnum in range(1, winnr('$'))
        if qf#type(winnum) == a:type
            return winnum
        endif
    endfor
    return 0
endfunction

" returns location list of the current loclist if isLoc is set
"         qf list otherwise
function! qf#GetList()
    if get(b:, 'qf_isLoc', 0)
        return getloclist(winnr())
    else
        return getqflist()
    endif
endfunction

" sets location or qf list based in b:qf_isLoc to passed newlist
function! qf#SetList(newlist, ...)
    " generate partial
    let Func = get(b:, 'qf_isLoc', 0)
                \ ? function('setloclist', [0, a:newlist])
                \ : function('setqflist', [a:newlist])

    " get user-defined maximum height
    let max_height = get(g:, 'qf_max_height', 10) < 1 ? 10 : get(g:, 'qf_max_height', 10)

    " call partial with optional arguments
    call call(Func, a:000)

    if get(b:, 'qf_isLoc', 0)
        execute get(g:, "qf_auto_resize", 1) ? 'lclose|' . min([ max_height, len(getloclist(0)) ]) . 'lwindow' : 'lwindow'
    else
        execute get(g:, "qf_auto_resize", 1) ? 'cclose|' . min([ max_height, len(getqflist()) ]) . 'cwindow' : 'cwindow'
    endif
endfunction

function! qf#GetEntryPath(line) abort
    "                          +- match from the first pipe to the end of line
    "                          |  declaring EOL explicitly is faster than implicitly
    "                          |      +- replace match with nothing
    "                          |      |   +- no flags
    return substitute(a:line, '|.*$', '', '')
endfunction

" open the quickfix window if there are valid errors
function! qf#OpenQuickfix()
    if get(g:, 'qf_auto_open_quickfix', 1)
        " get user-defined maximum height
        let max_height = get(g:, 'qf_max_height', 10) < 1 ? 10 : get(g:, 'qf_max_height', 10)
        execute get(g:, "qf_auto_resize", 1) ? 'cclose|' . min([ max_height, len(getqflist()) ]) . 'cwindow' : 'cwindow'
    endif
endfunction

" open a location window if there are valid locations
function! qf#OpenLoclist()
    if get(g:, 'qf_auto_open_loclist', 1)
        " get user-defined maximum height
        let max_height = get(g:, 'qf_max_height', 10) < 1 ? 10 : get(g:, 'qf_max_height', 10)
        execute get(g:, "qf_auto_resize", 1) ? 'lclose|' . min([ max_height, len(getloclist(0)) ]) . 'lwindow' : 'lwindow'
    endif
endfunction

let &cpo = s:save_cpo
