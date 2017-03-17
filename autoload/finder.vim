let s:NAME = "Precise Finder"
let s:BUFFER_NAME = "finder"
let s:ALLOWED_OPEN_BUFFER_COMMANDS = ["enew", "new", "vnew", "tabe"]
let s:LIMIT = 100
let s:HEADER_TITLE = 0
let s:HEADER_MATCHES = 1
let s:HEADER_MAPPINGS = 2
let s:HEADER_PLACEHOLDER_MATCHES_AMOUNT = "{matchesAmount}"
let s:HEADER_PLACEHOLDER_ITEMS_AMOUNT = "{itemsAmount}"
let s:HEADER_PLACEHOLDER_PATTERN = '{%s}'
let s:HEADER_PARAMETER_PATTERN = '{\zs\w\+\ze}'
let s:HEADER_QUICK_HELP_LABEL = "Quick Help"
let s:TAG_LINE_END = "#finderendline"
let s:SYNTAX_MATCH_REGION = '^.\+'
let s:DEFAULT_GLOBAL_OPTIONS = {}
let s:GLOBAL_OPTIONS = {
	\ "showmode": 0,
	\ "rulerformat": "%0(%)",
	\ "updatetime": 999999999,
	\ "number": 0,
	\ "relativenumber": 0,
	\ "laststatus": 0,
\ }

function! finder#files(...)
	call call("finder#files#index", a:000)
endfunction

function! finder#tags(...)
	call call("finder#tags#index", a:000)
endfunction

function! finder#lines(...)
	call call("finder#lines#index", a:000)
endfunction

function! finder#matches(...)
	call call("finder#matches#index", a:000)
endfunction

function! finder#splitted(...)
	call call("finder#splitted#index", a:000)
endfunction

function! finder#custom(items, ...)
	call call("finder#init", [a:items, get(a:, 1, {})])
	call finder#fill()
endfunction

function! finder#init(items, ...)
	if(len(a:items) == 0)
		return finder#error("Nothing to match.")
	endif

	let options = get(a:, 1, {})
	let openBufferCommand = get(options, "openBufferCommand", "enew")
	let bufferName = get(options, "bufferName", s:BUFFER_NAME)
	let allowedOpenBufferCommands = get(options, "allowedOpenBufferCommands", s:ALLOWED_OPEN_BUFFER_COMMANDS)
	let previousWindow = winnr()

	if(index(allowedOpenBufferCommands, openBufferCommand) == -1)
		return finder#error(printf("Not allowed command. Allowed: %s", allowedOpenBufferCommands))
	endif

	" set global options
	for [option, value] in items(s:GLOBAL_OPTIONS)
		let s:DEFAULT_GLOBAL_OPTIONS[option] = getbufvar("%", "&" . option)

		call setbufvar("%", "&" . option, value)
	endfor

	" need redraw to clear ruler
	redraw

	" creating a buffer
	execute openBufferCommand

	" post buffer commands
	execute printf("silent file %s", bufferName)
	mapclear <buffer>

	" set local options
	setlocal filetype=finder
	setlocal buftype=nofile
	setlocal nocursorline
	setlocal conceallevel=3
	setlocal concealcursor=nvic
	setlocal nowrap

	" set buffer variables
	let b:previousWindow = previousWindow
	let b:currentWindow = winnr()
	let b:currentBuffer = bufnr("%")
	let b:items = finder#getCompleteItems(a:items)
	let b:itemsAmount = len(b:items)
	let b:raw = exists("options.raw") ? options.raw : finder#getRaw(b:items)
	let b:limit = get(options, "limit", s:LIMIT)
	let b:finder = get(options, "finder", function("finder#getMatches"))

	" used for scrolling
	let b:hiddenLines = []

	let b:header = get(options, "header", finder#getHeader())
	let b:headerVariables = finder#getHeaderVariables(b:header)
	let b:headerContainedGroups = get(options, "headerContainedGroups", [])
	let b:queryLine = len(b:header) + 1
	let b:firstMatchLine = b:queryLine + 1
	let b:hoveredLine = b:firstMatchLine
	let b:cancelled = 1
	let b:prompt = get(options, "prompt", "> ")
	let b:startWith = get(options, "startWith", "")
	let b:query = b:startWith
	let b:previousQuery = b:startWith
	let b:keyPressed = 0
	let b:matchesAmount = min([b:itemsAmount, b:limit])
	let b:handler = get(options, "handler", function("finder#handler"))
	let b:comparator = get(options, "comparator", v:null)
	let b:grepCommand = printf("grep -ni -m %i %%s", b:limit)
	let b:queryStartColumn = len(b:prompt) + 1

	call finder#defineMappings()
	call finder#defineEventListeners()
	call finder#defineHighlighting()
	call finder#defineSyntax()
	call finder#setSyntaxMatchRegion(get(options, "syntaxMatchRegion", s:SYNTAX_MATCH_REGION))
endfunction

function! finder#getCompleteItems(items)
	let key = 0

	for item in a:items
		let item.key = key
		let key += 1
	endfor

	if(!has_key(a:items[0], "visibleLine"))
		for item in a:items
			let item.visibleLine = item.raw
		endfor
	endif

	if(!has_key(a:items[0], "comment"))
		for item in a:items
			let item.comment = ""
		endfor
	endif

	return a:items
endfunction

function! finder#fill()
	" insert header
	call finder#updateHeader()

	" white space at the end is used to avoid cursor jerk
	call finder#setQueryLine(b:startWith . " ")

	call timer_start(0, "finder#redraw")
	call feedkeys("s")
endfunction

function! finder#defineEventListeners()
	autocmd TextChangedI <buffer> call finder#textChangedI()
	autocmd InsertLeave <buffer> call finder#insertLeave()
endfunction

function! finder#defineMappings()
	inoremap <expr><buffer><BS> finder#canGoLeft() ? "\<BS>" : ""
	inoremap <expr><buffer><C-h> finder#canGoLeft() ? "\<BS>" : ""
	inoremap <expr><buffer><Del> col(".") == col("$") ? "" : "\<Del>"
	inoremap <expr><buffer><Left> finder#canGoLeft() ? "\<Left>" : ""
	inoremap <silent><buffer><C-a> <C-r>=finder#call("cursor", b:queryLine, b:queryStartColumn)<CR>
	inoremap <silent><buffer><C-e> <C-r>=finder#call("cursor", b:queryLine, col('$'))<CR>
	inoremap <silent><buffer><C-c> <C-r>=finder#call("finder#setQueryLine", "")<CR>
	inoremap <silent><buffer><C-j> <C-r>=finder#call("finder#selectNextItem")<CR>
	inoremap <silent><buffer><C-k> <C-r>=finder#call("finder#selectPreviousItem")<CR>
	inoremap <silent><buffer><Down> <C-r>=finder#call("finder#selectNextItem")<CR>
	inoremap <silent><buffer><Up> <C-r>=finder#call("finder#selectPreviousItem")<CR>
	inoremap <silent><buffer><Tab> <C-r>=finder#call("finder#selectNextItem")<CR>
	inoremap <silent><buffer><S-Tab> <C-r>=finder#call("finder#selectPreviousItem")<CR>
	inoremap <silent><buffer><CR> <C-r>=finder#call("finder#handle")<CR>
	inoremap <silent><buffer><C-o> <C-r>=finder#call("finder#handle")<CR>
endfunction

function! finder#call(fn, ...)
	call call(a:fn, a:000)

	return ""
endfunction

function! finder#defineSyntax()
	" header
	execute printf('syntax region finderHeader start=/\%%^/ end=/\%%%il$/ contains=finderHeaderLabel,finderHeaderValue,finderHeaderQuickHelp,%s', b:queryLine - 1, join(b:headerContainedGroups, ","))
	syntax match finderHeaderLabel /^\s*\zs.\{-}\ze:/ contained
	syntax match finderHeaderValue /: \zs.\+/ contained
	execute printf('syntax match finderHeaderQuickHelp /\%%(%s:\)\@<=.*/ contained contains=finderHeaderShortcut,finderHeaderShortcutSeparator,finderHeaderShortcutNote', s:HEADER_QUICK_HELP_LABEL)
	syntax match finderHeaderShortcut /\S\+\ze:/ contained
	syntax match finderHeaderShortcutSeparator /:/ contained
	syntax match finderHeaderShortcutNote /[^:]\{-}\ze\(  \|$\)/ contained

	" query line
	execute printf('syntax match finderQuery /\%%%il\%%%ic.*$/', b:queryLine, b:queryStartColumn)
	execute printf('syntax match finderPrompt /^\%%%il.\{%i\}/', b:queryLine, len(b:prompt))

	" body
	execute printf('syntax region finderBody start=/\%%%il/ end=/\%%$/ contains=finderSelected,finderMatch,finderHidden', b:firstMatchLine)
	execute printf('syntax match finderComment /\(%s\)\@<=.*$/ contained', s:TAG_LINE_END)
	execute printf('syntax match finderSelectedComment /\(%s\)\@<=.*$/ contained', s:TAG_LINE_END)
	execute printf('syntax match finderHidden /%s/ conceal contained', s:TAG_LINE_END)
endfunction

function! finder#defineHighlighting()
	hi link finderHeader Comment
	hi finderHeaderLabel ctermfg=109 ctermbg=NONE cterm=NONE
	hi finderHeaderValue ctermfg=215 ctermbg=NONE cterm=NONE
	hi finderHeaderShortcut ctermfg=222 ctermbg=NONE cterm=NONE
	hi link finderHeaderShortcutSeparator finderHeader
	hi finderHeaderShortcutNote ctermfg=255 ctermbg=NONE cterm=NONE
	hi finderPrompt ctermfg=81 ctermbg=NONE cterm=NONE
	hi finderQuery ctermfg=255 ctermbg=NONE cterm=NONE
	hi finderBody ctermfg=109 ctermbg=NONE cterm=NONE
	hi finderSelected ctermfg=109 ctermbg=0 cterm=bold
	hi finderComment ctermfg=109 ctermbg=NONE cterm=NONE
	hi finderSelectedComment ctermfg=109 ctermbg=0 cterm=bold
	hi finderMatch ctermfg=215 ctermbg=NONE cterm=bold,underline
	hi finderSelectedMatch ctermfg=215 ctermbg=0 cterm=bold,underline
endfunction

function! finder#setSyntaxMatchRegion(region)
	let b:syntaxMatchRegion = printf('\c%s%s.*$\&.\{-}%%s%s', a:region, s:TAG_LINE_END, s:TAG_LINE_END)
endfunction

function! finder#insertLeave()
	if(b:cancelled)
		call finder#exciteUserEvent("FinderCancelled")
		call finder#leave(b:currentBuffer)
	endif
endfunction

function! finder#handle()
	let b:cancelled = 0
	let currentBuffer = b:currentBuffer
	let item = finder#getSelectedItem()

	if(type(item) != v:t_dict)
		return finder#error("Nothing to handle.")
	endif

	stopinsert
	let stay = call(b:handler, [item])

	if(!stay)
		call finder#leave(currentBuffer)
	endif
endfunction

function! finder#leave(currentBuffer)
	for [option, value] in items(s:DEFAULT_GLOBAL_OPTIONS)
		call setbufvar("%", "&" . option, value)
	endfor

	autocmd! User
	execute "bdelete " . a:currentBuffer
endfunction

function! finder#textChangedI()
	let b:query = strpart(getline(b:queryLine), b:queryStartColumn - 1)

	if(b:query != b:previousQuery)
		call timer_start(0, "finder#redraw")
	endif
endfunction

function! finder#redraw(timer)
	let b:previousQuery = b:query
	let windowView = winsaveview()

	if(line('$') > b:queryLine)
		silent execute printf("%i,$d", b:firstMatchLine)
	endif

	call winrestview(windowView)

	let b:matches = call(b:finder, [b:items])

	if(type(b:comparator) == v:t_func)
		call sort(b:matches, b:comparator)
	endif

	let b:matchesAmount = len(b:matches)

	call finder#updateHeader()

	let i = b:firstMatchLine

	for m in b:matches
		let line = m.visibleLine . s:TAG_LINE_END . m.comment

		call setline(i, line)

		let i += 1
	endfor

	call finder#updateSyntax(b:query)

	if(b:matchesAmount > 0)
		call finder#hoverLine(b:firstMatchLine)
	endif

	let b:hiddenLines = []
	let b:keyPressed = 1
endfunction

function! finder#getMatches(items)
	let command = printf(b:grepCommand, shellescape(b:query))
	let matchedLines = systemlist(command, b:raw)
	let matches = []

	for line in matchedLines
		let separatorIndex = stridx(line, ":")
		let key = strpart(line, 0, separatorIndex) - 1

		call add(matches, a:items[key])
	endfor

	return matches
endfunction

function! finder#comparator(a, b)
	return len(a:a.raw) - len(a:b.raw)
endfunction

function! finder#updateSyntax(pattern)
	syntax clear finderMatch
	syntax clear finderSelectedMatch

	let pattern = a:pattern
	let patternLength = len(pattern)

	let hasCaret = pattern[0] == '^'
	let hasDollar = pattern[patternLength - 1] == '$' && (patternLength < 2 || pattern[patternLength - 2] != '\')

	if(hasDollar)
		let pattern = strpart(pattern, 0, patternLength - 1)
	endif

	if(hasCaret)
		let pattern = strpart(pattern, 1)
	endif

	let patternLength = len(pattern)

	if(patternLength == 0)
		return
	endif

	let pattern = escape(pattern, '/')

	if(hasCaret && hasDollar)
		let pattern = printf('\zs%s\ze', pattern)
	elseif(hasDollar)
		let pattern = printf('.*\zs%s\ze', pattern)
	elseif(hasCaret)
		let pattern = printf('\zs%s\ze.*', pattern)
	else
		let pattern = printf('\zs%s\ze.*', pattern)
	endif

	let matchPattern = printf(b:syntaxMatchRegion, pattern)
	let selectedMatchPattern = printf(b:syntaxMatchRegion, pattern)

	silent! execute printf('syntax match finderMatch /%s/ contained', matchPattern)
	silent! execute printf('syntax match finderSelectedMatch /%s/ contained', selectedMatchPattern)
endfunction

function! finder#handler(i)
	echo a:i

	return 1
endfunction

function! finder#getHeader(...)
	let options = get(a:, 1, {})
	let include = get(options, "include", [s:HEADER_TITLE, s:HEADER_MATCHES, s:HEADER_MAPPINGS])
	let separator = get(options, "separator", "=")
	let separatorWidth = get(options, "separatorWidth", 74)
	let header = []

	call add(header, repeat(separator, separatorWidth))

	if(index(include, s:HEADER_TITLE) != -1)
		call add(header, s:NAME)
	endif

	if(index(include, s:HEADER_MATCHES) != -1)
		call add(header, '  Matches: ' . s:HEADER_PLACEHOLDER_MATCHES_AMOUNT . '/' . s:HEADER_PLACEHOLDER_ITEMS_AMOUNT)
	endif

	if(index(include, s:HEADER_MAPPINGS) != -1)
		call add(header, printf("  %s: <C-a>:start  <C-e>:end  <C-c>:clear  <Esc>:exit  <CR>:choose", s:HEADER_QUICK_HELP_LABEL))
	endif

	call add(header, repeat(separator, separatorWidth))

	return header
endfunction

function! finder#updateHeader()
	let header = []

	for line in b:header
		let filledLine = line

		for variable in b:headerVariables
			let filledLine = substitute(filledLine, printf(s:HEADER_PLACEHOLDER_PATTERN, variable), getbufvar("%", variable), "g")
		endfor

		call add(header, filledLine)
	endfor

	call setline(1, header)
endfunction

function! finder#canGoLeft()
	return col('.') > b:queryStartColumn
endfunction

function! finder#setQueryLine(query)
	call setline(b:queryLine, b:prompt . a:query)
	call cursor(b:queryLine, col('$'))
endfunction

function! finder#selectNextItem()
	if(b:hoveredLine >= winheight(0) && b:hoveredLine != line('$'))
		let b:hoveredLine -= 1
		let dict = winsaveview()

		call add(b:hiddenLines, getline(b:firstMatchLine))
		execute b:firstMatchLine . "d"
		call winrestview(dict)
	endif

	if(b:hoveredLine < line('$'))
		call finder#hoverLine(b:hoveredLine + 1)
	endif
endfunction

function! finder#selectPreviousItem()
	if(b:hoveredLine == b:firstMatchLine && len(b:hiddenLines) > 0)
		let b:hoveredLine += 1
		let lastIndex = len(b:hiddenLines) - 1

		call append(b:queryLine, b:hiddenLines[lastIndex])
		call remove(b:hiddenLines, lastIndex)
	endif

	if(b:hoveredLine > b:firstMatchLine)
		call finder#hoverLine(b:hoveredLine - 1)
	endif
endfunction

function! finder#hoverLine(line)
	let b:hoveredLine = a:line
	syntax clear finderSelected
	execute printf('syntax match finderSelected /\%%%il.*$/ contains=finderSelectedComment,finderSelectedMatch,finderHidden contained', a:line)

	if(b:matchesAmount > 0 && b:keyPressed)
		call finder#exciteUserEvent("FinderItemSelected")
	endif
endfunction

function! finder#getSelectedItem()
	let key = b:hoveredLine - b:firstMatchLine + len(b:hiddenLines)

	return b:matchesAmount == 0 ? v:null : b:matches[key]
endfunction

function! finder#get(variable)
	return get(s:, a:variable, v:none)
endfunction

function! finder#error(error)
	echo a:error
endfunction

function! finder#exciteUserEvent(event)
	if(exists("#User#" . a:event))
		execute "doautocmd User " . a:event
	endif
endfunction

function! finder#getHeaderVariables(header)
	let variables = []

	for line in a:header
		let matches = finder#getStringMatches(line, s:HEADER_PARAMETER_PATTERN, 2)

		for m in matches
			call add(variables, m[0])
		endfor
	endfor

	return variables
endfunction

function! finder#getStringMatches(line, pattern, offsetType)
	let matches = []
	let offset = 0

	while(1)
		let match = matchstrpos(a:line, a:pattern, offset)

		if(match[1] == -1)
			return matches
		endif

		call add(matches, match)

		let offset = match[a:offsetType] + 1
	endwhile
endfunction

function! finder#getRaw(items)
	let b:raw = []

	for item in a:items
		call add(b:raw, item.raw)
	endfor

	return b:raw
endfunction
