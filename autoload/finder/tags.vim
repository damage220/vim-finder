let s:MIN_COLUMNS = 25

function! finder#tags#index(...)
	if(!executable("ctags"))
		return finder#error("Ctags was not found in your $PATH.")
	endif

	if(!filereadable(expand("%")))
		return finder#error("File cannot be read.")
	endif

	if(&ft == "")
		return finder#error("Please specify filetype.")
	endif

	let options = get(a:, 1, {})
	let options.bufferName = get(options, "bufferName", "tags")
	let options.prompt = get(options, "prompt", "Tags> ")
	let options.header = get(options, "header", [])

	let command = get(options, "command", "ctags -x --sort=no --format=2 --language-force=%s %s")
	let tags = systemlist(printf(command, &ft, shellescape(expand("%"))))

	if(v:shell_error || len(tags) == 0)
		return finder#error("No tags were found.")
	endif

	let maxTagLength = 0

	" find max tag length
	for tag in tags
		let parts = split(tag, '\s\+')

		if(len(parts[0]) > maxTagLength)
			let maxTagLength = len(parts[0])
		endif
	endfor

	let columns = max([s:MIN_COLUMNS, maxTagLength + max([len(options.prompt) + 1, 5])])
	let windowSize = get(options, "windowSize", columns)
	let options.windowSize = min([windowSize, winwidth(0) / 2])
	let items = []

	for tag in tags
		let parts = split(tag, '\s\+')
		let spaceDiff = columns - len(parts[0])

		let item = {}
		let item.raw = parts[0]
		let item.comment = repeat(" ", spaceDiff - 1) . parts[1][0]
		let item.position = [parts[2], -1]

		call add(items, item)
	endfor

	call finder#splitted(items, options)
endfunction
