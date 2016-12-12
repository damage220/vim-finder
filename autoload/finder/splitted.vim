function! finder#splitted#index(items, ...)
	let options = get(a:, 1, {})
	let options.openBufferCommand = get(options, "openBufferCommand", "vnew")
	let options.allowedOpenBufferCommands = ["new", "vnew"]
	let options.handler = get(options, "handler", function("s:handler"))

	let previousWindowView = winsaveview()
	let showPreview = get(options, "showPreview", 1)

	call finder#init(a:items, options)

	if(has_key(options, "windowSize"))
		execute "vertical resize " . options.windowSize
	endif

	call finder#fill()

	execute printf("autocmd User FinderCancelled wincmd w | call winrestview(%s) | wincmd w", string(previousWindowView))

	if(showPreview)
		autocmd User FinderItemSelected call <SID>preview(finder#getSelectedItem())
	endif
endfunction

function! s:handler(item)
	execute printf("%iwincmd w", b:previousWindow)

	call s:moveCursor(a:item.position[0], a:item.position[1])
endfunction

function! s:preview(item)
	let currentWindow = b:currentWindow
	execute printf("%iwincmd w", b:previousWindow)

	call s:moveCursor(a:item.position[0], a:item.position[1])

	set cursorline!
	set cursorline!
	execute printf("%iwincmd w", currentWindow)
endfunction

function! s:moveCursor(line, column)
	if(a:column == -1)
		call cursor(a:line, 0)
		normal ^
	else
		call cursor(a:line, a:column)
	endif

	normal zzl
endfunction
