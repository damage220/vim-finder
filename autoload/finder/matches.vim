function! finder#matches#index(pattern, ...)
	let options = get(a:, 1, {})
	let options.bufferName = get(options, "bufferName", "matches")
	let options.prompt = get(options, "prompt", "Matches> ")
	let options.header = get(options, "header", s:getHeader(a:pattern))

	let offsetType = get(options, "offsetType", 2)
	let lines = getline(0, "$")
	let items = []
	let lineNumber = 0

	for line in lines
		let matchesInString = finder#getStringMatches(line, a:pattern, offsetType)
		let lineNumber += 1

		for m in matchesInString
			let item = {}
			let item.raw = m[0]
			let item.position = [lineNumber, m[1] + 1]

			call add(items, item)
		endfor
	endfor

	if(len(items) == 0)
		return finder#error("No matches were found.")
	endif

	call finder#splitted(items, options)
endfunction

function! s:getHeader(pattern)
	let header = finder#getHeader()

	call insert(header, "  Pattern: " . a:pattern, 2)

	return header
endfunction
