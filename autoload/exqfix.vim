" variables {{{1
let s:title = "-QFix-" 

let s:exQF_quick_view_title = '__exQF_QuickViewWindow__'
let s:exQF_short_title = 'Select'
let s:exQF_cur_filename = ''

" ------------------------------------------------------------------ 
" Desc: general
" ------------------------------------------------------------------ 

let s:exQF_fold_start = '<<<<<<'
let s:exQF_fold_end = '>>>>>>'
let s:exQF_need_search_again = 0
let s:exQF_compile_dir = ''
let s:exQF_error_file_size = 0
let s:exQF_compiler = 'gcc'

" ------------------------------------------------------------------ 
" Desc: select variable
" ------------------------------------------------------------------ 

let s:exQF_select_idx = 1
let s:exQF_need_update_select_window = 0

" ------------------------------------------------------------------ 
" Desc: quick view variable
" ------------------------------------------------------------------ 

let s:exQF_quick_view_idx = 1
let s:exQF_picked_search_result = []
let s:exQF_quick_view_search_pattern = ''
let s:exQF_need_update_quick_view_window = 0


let s:zoom_in = 0
let s:keymap = {}

let s:help_open = 0
let s:help_text_short = [
            \ '" Press ? for help',
            \ '',
            \ ]
let s:help_text = s:help_text_short

let s:compiler = "gcc" 
let s:qfix_file = './error.qfix'
" }}}

" functions {{{1

" exqfix#bind_mappings {{{2
function exqfix#bind_mappings()
    call ex#keymap#bind( s:keymap )
endfunction

" exqfix#register_hotkey {{{2
function exqfix#register_hotkey( priority, local, key, action, desc )
    call ex#keymap#register( s:keymap, a:priority, a:local, a:key, a:action, a:desc )
endfunction

function exqfix#locate_word(word)
    call search(a:word)
endfunction

" exqfix#toggle_help {{{2

" s:update_help_text {{{2
function s:update_help_text()
    if s:help_open
        let s:help_text = ex#keymap#helptext(s:keymap)
    else
        let s:help_text = s:help_text_short
    endif
endfunction

function exqfix#toggle_help()
    if !g:ex_qfix_enable_help
        return
    endif

    let s:help_open = !s:help_open
    silent exec '1,' . len(s:help_text) . 'd _'
    call s:update_help_text()
    silent call append ( 0, s:help_text )
    silent keepjumps normal! gg
    call ex#hl#clear_confirm()
endfunction

" exqfix#open_window {{{2

function exqfix#init_buffer()
    " NOTE: ex-project window open can happen during VimEnter. According to  
    " Vim's documentation, event such as BufEnter, WinEnter will not be triggered
    " during VimEnter.
    " When I open exqfix window and read the file through vimentry scripts,
    " the events define in exqfix/ftdetect/exqfix.vim will not execute.
    " I guess this is because when you are in BufEnter event( the .vimentry
    " enters ), and open the other buffers, the Vim will not trigger other
    " buffers' event 
    " This is why I set the filetype manually here. 
    set filetype=exqfix
    au! BufWinLeave <buffer> call <SID>on_close()

    if line('$') <= 1 && g:ex_qfix_enable_help
        silent call append ( 0, s:help_text )
        silent exec '$d _'
    else
        silent loadview
    endif
endfunction

function s:on_close()
    let s:zoom_in = 0
    let s:help_open = 0
    silent mkview

    " go back to edit buffer
    call ex#window#goto_edit_window()
    call ex#hl#clear_target()
endfunction

function exqfix#open_window()
    let winnr = winnr()
    if ex#window#check_if_autoclose(winnr)
        call ex#window#close(winnr)
    endif
    call ex#window#goto_edit_window()

    let winnr = bufwinnr(s:title)
    if winnr == -1
        call ex#window#open( 
                    \ s:title, 
                    \ g:ex_qfix_winsize,
                    \ g:ex_qfix_winpos,
                    \ 1,
                    \ 1,
                    \ function('exqfix#init_buffer')
                    \ )
    else
        exe winnr . 'wincmd w'
    endif
endfunction

" exqfix#toggle_window {{{2
function exqfix#toggle_window()
    let result = exqfix#close_window()
    if result == 0
        call exqfix#open_window()
    endif
endfunction

" exqfix#close_window {{{2
function exqfix#close_window()
    let winnr = bufwinnr(s:title)
    if winnr != -1
        call ex#window#close(winnr)
        return 1
    endif
    return 0
endfunction

" exqfix#toggle_zoom {{{2
function exqfix#toggle_zoom()
    let winnr = bufwinnr(s:title)
    if winnr != -1
        if s:zoom_in == 0
            let s:zoom_in = 1
            call ex#window#resize( winnr, g:ex_qfix_winpos, g:ex_qfix_winsize_zoom )
        else
            let s:zoom_in = 0
            call ex#window#resize( winnr, g:ex_qfix_winpos, g:ex_qfix_winsize )
        endif
    endif
endfunction

"function exqfix#confirm_select(modifier)
"     call exqfix#goto(-1)
" endfunction
" exqfix#confirm_select {{{2
" modifier: '' or 'shift'
function exqfix#confirm_select(modifier)
    " check if the line is valid file line
    let line = getline('.') 
    let s:confirm_at = line('.')

    " get filename 
    let filename = line

    " NOTE: GSF,GSFW only provide filepath information, so we don't need special process.
    let idx = stridx(line, '|') 
    if idx > 0 
        let filename = strpart(line, 0, idx) "DISABLE: escape(strpart(line, 0, idx), ' ') 
    endif 

    let make_enter_dir_line = getline(search("Entering directory", 'b'))
    let make_enter_dir_idx = stridx(make_enter_dir_line, "'") 
    let make_enter_dir_ridx = strridx(make_enter_dir_line, "'") 
    let make_enter_dir = strpart(make_enter_dir_line, make_enter_dir_idx+1, make_enter_dir_ridx-make_enter_dir_idx-1)
    " echomsg "make_enter_dir_line make_enter_dir " . make_enter_dir_line . make_enter_dir
    let filename = substitute(filename, '\', '/', 'g') " for windows 
    " if no 'Entering directory' line, let make_enter_dir = '.'
    if make_enter_dir == ''
       let  make_enter_dir = '.'
    endif
    let filename = make_enter_dir."/".filename
    " echomsg "filename ". filename

    " check if file exists
    if findfile(filename) == '' 
        call ex#warning( filename . ' not found!' ) 
        return
    endif 

    " confirm the selection
    " let s:confirm_at = line('.')
    call ex#hl#confirm_line(s:confirm_at)
    exec "normal" . s:confirm_at . "G"

    " goto edit window
    call ex#window#goto_edit_window()

    " open the file
    if bufnr('%') != bufnr(filename) 
        exe ' silent e ' . escape(filename,' ') 
    endif 

    if idx > 0 
        " get line number 
        let line = strpart(line, idx+1) 
        let idx = stridx(line, " ") 
        let linestr = strpart(line, 0, idx)
        if 0 == match(linestr, "[0-9]")
            let linenr  = eval(linestr) 
            exec ' call cursor(linenr, 1)' 

            " jump to the pattern if the code have been modified 
            " WINDOWS下，这段代码有问题，linux里还没有试,先加个if has ("unix")
            if has("unix")
            let pattern = strpart(line, idx+2) 
            let pattern = '\V' . substitute( pattern, '\', '\\\', "g" ) 
            if search(pattern, 'cw') == 0 
                call ex#warning('Line pattern not found: ' . pattern)
            endif 
            endif
        else
        endif
    endif 

    " go back to global search window 
    exe 'normal! zz'
    call ex#hl#target_line(line('.'))
    " call ex#window#goto_plugin_window()
endfunction

" exqfix#open {{{2
function exqfix#open(filename)
    let qfile = a:filename
    if qfile == ''
        let qfile = s:qfix_file
    endif

    if findfile(qfile) == ''
        call ex#warning( 'Can not find qfix file: ' . qfile )
        return
    endif

    " open the qfix window
    call exqfix#open_window()

    " clear screen and put new result
    silent exec '1,$d _'

    " add online help 
    if g:ex_qfix_enable_help
        silent call append ( 0, s:help_text )
        silent exec '$d _'
        let start_line = len(s:help_text)
    else
        let start_line = 1
    endif

    " read qfix files
    let qfixlist = readfile(qfile)
    call append( start_line, qfixlist )

    " get the quick fix result
    " silent exec 'cgetb'

    "
    call cursor( start_line, 0 )
endfunction

" exqfix#paste
function exqfix#paste(reg)
    " open the global search window
    call exqfix#open_window()

    " clear screen and put new result
    silent exec '1,$d _'

    " add online help 
    if g:ex_gsearch_enable_help
        silent call append ( 0, s:help_text )
        silent exec '$d _'
        let start_line = len(s:help_text)
    else
        let start_line = 0
    endif

    silent put =getreg(a:reg)

    " get the quick fix result
    silent exec 'cgetb'

    "
    call cursor( start_line, 0 )

endfunction

" exqfix#build
function exqfix#build(opt)
    let result = system( &makeprg . ' ' . a:opt )

    " open the global search window
    call exqfix#open_window()

    " clear screen and put new result
    silent exec '1,$d _'

    " add online help 
    if g:ex_gsearch_enable_help
        silent call append ( 0, s:help_text )
        silent exec '$d _'
        let start_line = len(s:help_text)
    else
        let start_line = 0
    endif

    silent put =result

    " get the quick fix result
    silent exec 'cgetb'

    "
    call cursor( start_line, 0 )
endfunction

" exqfix#goto
function exqfix#goto(idx)
    let idx = a:idx
    if idx == -1
        let idx = line('.')
    endif

    " start jump
    call ex#window#goto_edit_window()
    try
        silent exec "cr".idx
    catch /^Vim\%((\a\+)\)\=:E42/
        call ex#warning('No Errors')
    catch /^Vim\%((\a\+)\)\=:E325/ " this would happen when editting the same file with another programme.
        call ex#warning('Another programme is edit the same file.')
        try " now we try this again.
            silent exec 'cr'.idx
        catch /^Vim\%((\a\+)\)\=:E42/
            call ex#warning('No Errors')
        endtry
    endtry

    " go back
    exe 'normal! zz'
    call ex#hl#target_line(line('.'))
    call ex#window#goto_plugin_window()
endfunction

" exqfix#set_compiler
function exqfix#set_compiler(compiler)
    " setup compiler
    let s:compiler = a:compiler
    exec 'compiler! '. s:compiler
endfunction

" exqfix#set_qfix_file
function exqfix#set_qfix_file(path)
    let s:qfix_file = a:path
endfunction

" TODO: getqflist(), getloclist()
" ------------------------------------------------------------------ 
" Desc: get error file and load quick fix list
" ------------------------------------------------------------------ 

function exqfix#get_qfix_result( file_name ) " <<<
    let full_file_name = globpath( getcwd(), a:file_name )
    if full_file_name == ''
        let full_file_name = a:file_name
    endif
    if findfile(full_file_name) != ''
        " save the file size end file name
        let s:exqfix_error_file_size = getfsize(full_file_name)
        let s:exqfix_cur_filename = full_file_name

        " update quick view window
        let s:exQF_need_update_quick_view_window = 1

        " open and goto search window first
        let gs_winnr = bufwinnr(s:title)
        if gs_winnr == -1
            " open window
            call exqfix#toggle_window()
        else
            exe gs_winnr . 'wincmd w'
        endif

        " clear all the text and put the text to the buffer, by YJR
        silent exec '1,$d _'
        silent call append( 0 , readfile( full_file_name ) )
        silent normal gg
        
        " choose compiler automatically
        " call exqfix#choose_compiler ()

        " init compiler dir and current working dir
        let s:exqfix_compile_dir = vimentry#get('project_cwd')
        let cur_dir = getcwd()

        " get the quick fix result
        silent exec 'cd '.s:exqfix_compile_dir
        silent exec 'cgetb'
        silent exec 'cd '.cur_dir
    else
        call ex#warning('file: ' . full_file_name . ' not found')
    endif
endfunction " >>>

" ------------------------------------------------------------------ 
" Desc: Update exQuickFix window 
" ------------------------------------------------------------------ 

function exqfix#update_quickviewwindow() " <<<
    silent call cursor(s:exQF_quick_view_idx, 1)
    let s:confirm_at = line('.')
    call ex#hl#confirm_line(s:confirm_at)
    if s:exQF_need_update_quick_view_window
        let s:exQF_need_update_quick_view_window = 0

        "
        silent redir =>quickfix_list
        silent! exec 'cl!'
        silent redir END
        silent exec '1,$d _'
        silent put! = quickfix_list
        silent exec 'normal! gg'
    endif
endfunction " >>>


" ------------------------------------------------------------------ 
" Desc: goto select line
" ------------------------------------------------------------------ 

function exqfix#goto_in_quickviewwindow() " <<<
    let s:exQF_quick_view_idx = line(".")
    let s:confirm_at = line('.')
    call ex#hl#confirm_line(s:confirm_at)
    let cur_line = getline('.')
    " if this is empty line, skip check
    if cur_line == ""
        call ex#warning('pls select a quickfix result')
        return
    endif
    let idx_start = match(cur_line, '\d\+' )
    let idx_end = matchend(cur_line, '\d\+' )
    let idx = eval(strpart(getline('.'),idx_start,idx_end))
    call exqfix#goto(idx)
endfunction " >>>

" ------------------------------------------------------------------ 
" Desc: copy the quick view result with search pattern
" ------------------------------------------------------------------ 

function exqfix#copypickedline( search_pattern, line_start, line_end, search_method ) " <<<
    if a:search_pattern == ''
        let search_pattern = @/
    else
        let search_pattern = a:search_pattern
    endif
    if search_pattern == ''
        let s:exQF_quick_view_search_pattern = ''
        call ex#warning('search pattern not exists')
        return
    else
        let s:exQF_quick_view_search_pattern = '----------' . search_pattern . '----------'
        let full_search_pattern = search_pattern
        if a:search_method == 'pattern'
            "let full_search_pattern = '^.\+:\d.\+:.*\zs' . search_pattern
            let full_search_pattern = search_pattern
        elseif a:search_method == 'file'
            let full_search_pattern = '\(.\+:\d.\+:\)\&' . search_pattern
        endif
        " save current cursor position
        let save_cursor = getpos(".")
        " clear down lines
        if a:line_end < line('$')
            silent call cursor( a:line_end, 1 )
            silent exec 'normal! j"_dG'
        endif
        " clear up lines
        if a:line_start > 1
            silent call cursor( a:line_start, 1 )
            silent exec 'normal! k"_dgg'
        endif
        silent call cursor( 1, 1 )

        " clear the last search result
        if !empty( s:exQF_picked_search_result )
            silent call remove( s:exQF_picked_search_result, 0, len(s:exQF_picked_search_result)-1 )
        endif

        silent exec 'v/' . full_search_pattern . '/d'

        " clear pattern result
        while search('----------.\+----------', 'w') != 0
            silent exec 'normal! "_dd'
        endwhile

        " copy picked result
        let s:exQF_picked_search_result = getline(1,'$')

        " recover
        silent exec 'normal! u'

        " go back to the original position
        silent call setpos(".", save_cursor)
    endif
endfunction " >>>

" ------------------------------------------------------------------ 
" Desc: show the picked result in the quick view window
" ------------------------------------------------------------------ 

function exqfix#showpickedresult( search_pattern, line_start, line_end, edit_mode, search_method ) " <<<
    call s:exqfix#copypickedline( a:search_pattern, a:line_start, a:line_end, a:search_method )
    call s:exQF_SwitchWindow('QuickView')
    if a:edit_mode == 'replace'
        silent exec '1,$d _'
        silent put = s:exQF_quick_view_search_pattern
        "silent put = s:exQF_fold_start
        silent put = s:exQF_picked_search_result
        "silent put = s:exQF_fold_end
    elseif a:edit_mode == 'append'
        silent exec 'normal! G'
        silent put = ''
        silent put = s:exQF_quick_view_search_pattern
        "silent put = s:exQF_fold_start
        silent put = s:exQF_picked_search_result
        "silent put = s:exQF_fold_end
    endif
endfunction " >>>

" ------------------------------------------------------------------ 
" Desc: show the picked result in the quick view window
" ------------------------------------------------------------------ 

function s:exQF_ShowPickedResultNormalMode( search_pattern, edit_mode, search_method ) " <<<
    let line_start = 1
    let line_end = line('$')
    call s:exqfix#showpickedresult( a:search_pattern, line_start, line_end, a:edit_mode, a:search_method )
endfunction " >>>

" ------------------------------------------------------------------ 
" Desc: show the picked result in the quick view window
" ------------------------------------------------------------------ 

function s:exQF_ShowPickedResultVisualMode( search_pattern, edit_mode, search_method ) " <<<
    let line_start = 3
    let line_end = line('$')

    let tmp_start = line("'<")
    let tmp_end = line("'>")
    if line_start < tmp_start
        let line_start = tmp_start
    endif
    if line_end > tmp_end
        let line_end = tmp_end
    endif

    call s:exqfix#showpickedresult( a:search_pattern, line_start, line_end, a:edit_mode, a:search_method )
endfunction " >>>

" ------------------------------------------------------------------ 
" Desc: choose compiler 
" ------------------------------------------------------------------ 

function exqfix#choose_compiler() " <<<
    " choose compiler
    let s:compiler = 'gcc'
    let multi_core = 0
    for line in getline( 1, 4 ) " actual we just need to check line 1-2, but give a protected buffer check to 4 in case. 
        " process gcc error log formation
        if match(line, '^<<<<<< \S\+: ' . "'" . '\a\+\' . "'" ) != -1
            let s:compiler = 'exgcc'
        elseif match(line, '^<<<<<< \S\+ error log >>>>>>') != -1
            " TODO: use the text choose compiler
            let s:compiler = 'exmsvc'
        elseif match(line, '^.*------ Build started.*------') != -1
            let s:compiler = 'exmsvc'
            if match(line, '^\d\+>') != -1
                let multi_core = 1
            endif
        elseif match(line, '^<<<<<< SWIG: ' ) != -1
            let s:compiler = 'swig'
        endif
    endfor

    " FIXME: this is a bug, the :comiler! xxx not have effect at second time
    " NOTE: the errorformat matches by order, so the first matches order will
    "       be used. That's why we put %f:%l:%c in front of %f:%l
    silent! exec 'compiler! '.s:compiler
    if s:compiler == 'exgcc'
        silent set errorformat=\%*[^\"]\"%f\"%*\\D%l:\ %m
        silent set errorformat+=\"%f\"%*\\D%l:\ %m
        silent set errorformat+=%-G%f:%l:\ %trror:\ (Each\ undeclared\ identifier\ is\ reported\ only\ once
        silent set errorformat+=%-G%f:%l:\ %trror:\ for\ each\ function\ it\ appears\ in.)
        silent set errorformat+=%f:%l:%c:\ %m
        silent set errorformat+=%f:%l:\ %m
        silent set errorformat+=\"%f\"\\,\ line\ %l%*\\D%c%*[^\ ]\ %m
        silent set errorformat+=%D%\\S%\\+:\ Entering\ directory\ '%f'%.%#
        silent set errorformat+=%X%\\S%\\+:\ Leaving\ directory\ '%f'%.%#
        silent set errorformat+=%DEntering\ directory\ '%f'%.%#
        silent set errorformat+=%XLeaving\ directory\ '%f'%.%#
        silent set errorformat+=%D\<\<\<\<\<\<\ %\\S%\\+:\ '%f'%.%#
        silent set errorformat+=%X\>\>\>\>\>\>\ %\\S%\\+:\ '%f'%.%#
    elseif s:compiler == 'exmsvc'
        if multi_core
            silent set errorformat=%D%\\d%\\+\>------\ %.%#Project:\ %f%.%#%\\,%.%#
            silent set errorformat+=%X%\\d%\\+\>%.%#%\\d%\\+\ error(s)%.%#%\\d%\\+\ warning(s)
            silent set errorformat+=%\\d%\\+\>%f(%l)\ :\ %t%*\\D%n:\ %m
            silent set errorformat+=%\\d%\\+\>\ %#%f(%l)\ :\ %m
        else
            silent set errorformat=%D------\ %.%#Project:\ %f%.%#%\\,%.%#
            silent set errorformat+=%X%%.%#%\\d%\\+\ error(s)%.%#%\\d%\\+\ warning(s)
            silent set errorformat+=%f(%l)\ :\ %t%*\\D%n:\ %m
            silent set errorformat+=\ %#%f(%l)\ :\ %m
        endif
        silent set errorformat+=%f(%l\\,%c):\ %m " csharp error-format
    elseif s:compiler == 'swig'
        silent set errorformat+=%f(%l):\ %m
    elseif s:compiler == 'gcc'
        " this is for exGlobaSearch result, some one may copy the global search result to exQuickFix
        silent set errorformat+=%f:%l:%m
        silent set errorformat+=%f(%l\\,%c):\ %m " fxc shader error-format
        silent set errorformat+=%f:%l:\ %t:\ %m
    endif

    "
    let error_pattern = '^\d\+>'
    if s:compiler != 'exgcc' && search(error_pattern, 'W') != 0
        silent exec 'sort nr /'.error_pattern.'/'
    endif
endfunction " >>>


" }}}1



" vim:ts=4:sw=4:sts=4 et fdm=marker:
