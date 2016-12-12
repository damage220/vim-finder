function! finder#lines#index(...)
	let options = get(a:, 1, {})
	let options.bufferName = get(options, "bufferName", "lines")
	let options.prompt = get(options, "prompt", "Lines> ")

	let lines = getline(0, "$")

	if(len(lines) == 1 && lines[0] == "")
		return finder#error("Buffer is empty.")
	endif

	let items = []
	let lineNumber = 0

	for line in lines
		let lineNumber += 1
		let item = {}
		let item.raw = line
		let item.position = [lineNumber, -1]
		
		call add(items, item)
	endfor

	call finder#splitted(items, options)
endfunction
