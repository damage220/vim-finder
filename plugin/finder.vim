if(v:version < 800)
	echo "Finder requires Vim 8 or above."
endif

command! -nargs=* -complete=file Files call s:files(<f-args>)
command! Lines call finder#lines()
command! Tags call finder#tags()
command! -nargs=1 Matches call finder#matches(<f-args>)

function! s:files(...)
	if(a:0 == 0)
		call finder#files()
	elseif(a:0 == 1)
		call finder#files({"directory": a:1})
	elseif(a:0 == 2)
		call finder#files({"directory": a:1, "openBufferCommand": a:2})
	endif
endfunction
