    " Map <leader> space space to open terminal and call 'aider'
    nnoremap <leader><Space><Space> :call OpenAider()<CR>

    function! OpenAider()
        " Create a new buffer for the terminal
        let l:buf = nvim_create_buf(v:false, v:true)
        " Get the user's preferred window type
        let l:window_type = get(g:, 'aider_window_type', 'vsplit')
        " Open the terminal in the preferred window type
        if l:window_type == 'vsplit'
            vnew | terminal
        elseif l:window_type == 'hsplit'
            new | terminal
        else
            " Calculate the size and position of the floating window
            let l:width = nvim_win_get_width(0) - 4
            let l:height = nvim_win_get_height(0) - 4
            let l:row = 2
            let l:col = 2
            " Create a new floating window for the terminal
            let l:win = nvim_open_win(l:buf, v:true, {'relative': 'editor', 'width': l:width, 'height': l:height, 'row': l:row, 'col': l:col})
        endif
        " Run 'aider' in the terminal
        call termopen('aider', {'on_exit': function('s:OnExit')})
        " Make the terminal window active
        call nvim_set_current_win(l:win)
    endfunction

    function! s:OnExit(job_id, data, event)
        " Close the terminal window when 'aider' exits
        call nvim_win_close(0, v:true)
    endfunction
