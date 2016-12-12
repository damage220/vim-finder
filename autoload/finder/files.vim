let s:BASENAME_SYNTAX_MATCH_REGION = '\(^\|\%(\/\)\@<=\)[^\/]\+'
let s:HEADER_PLACEHOLDER_MODE = "{mode}"
let s:HEADER_IGNORED_LABEL = "Ignored"
let s:HEADER_IGNORED_PATH_SEPARATOR = ", "

function! finder#files#index(...)
	let options = get(a:, 1, {})
	let options.bufferName = get(options, "bufferName", "files")
	let options.prompt = get(options, "prompt", "Files> ")
	let options.handler = get(options, "handler", function("s:handler"))
	let options.startWith = get(options, "startWith", "^")
	let options.comparator = get(options, "comparator", function("finder#comparator"))
	let options.headerContainedGroups = get(options, "headerContainedGroups", ["finderFilesHeaderIgnoredPaths"])

	let directory = get(options, "directory", ".")
	let command = get(options, "command", "find %s -type f")
	let ignoredPaths = get(options, "ignoredPaths", ["*/.git/*", "*/.svn/*"])
	let baseName = get(options, "baseName", 1)
	let options.header = get(options, "header", s:getHeader(directory, ignoredPaths))

	if(!isdirectory(fnamemodify(directory, ":p")))
		return finder#error("Directory is not exist.")
	endif

	" assign directory
	let command = printf(command, directory)

	for path in ignoredPaths
		let command .= printf(" ! -path '%s'", path)
	endfor

	" remove ./ at the beginning of the line
	let command .= ' | sed "s|^\./||"'

	let paths = systemlist(command)
	let baseNames = []
	let options.raw = baseName ? baseNames : paths

	if(len(paths) == 0)
		return finder#error("There are no files in this directory.")
	endif

	let items = []

	for path in paths
		let item = {}
		let item.raw = path

		call add(items, item)
		call add(baseNames, fnamemodify(path, ":t"))
	endfor

	call finder#init(items, options)
	call s:defineSyntax()
	call s:defineHighlighting()

	let b:baseName = baseName
	let b:paths = paths
	let b:baseNames = baseNames

	inoremap <silent><buffer><C-b> <C-r>=finder#call("<SID>toggleBaseName")<CR>

	if(b:baseName)
		call s:enableBaseName()
	else
		call s:disableBaseName()
	endif

	call finder#fill()
endfunction

function! s:handler(item)
	execute printf("silent edit %s", fnameescape(a:item.raw))
endfunction

function! s:toggleBaseName()
	if(b:baseName)
		call s:disableBaseName()
	else
		call s:enableBaseName()
	endif

	call timer_start(0, "finder#redraw")
endfunction

function! s:enableBaseName()
	let b:raw = b:baseNames
	let b:mode = "basename"
	let b:baseName = 1

	call finder#setSyntaxMatchRegion(s:BASENAME_SYNTAX_MATCH_REGION)
endfunction

function! s:disableBaseName()
	let b:raw = b:paths
	let b:mode = "default"
	let b:baseName = 0

	call finder#setSyntaxMatchRegion(finder#get("SYNTAX_MATCH_REGION"))
endfunction

function! s:getHeader(directory, ignoredPaths)
	let header = finder#getHeader()
	let directory = fnamemodify(a:directory, ":~")

	call insert(header, '  Directory: ' . directory, 2)
	call insert(header, printf("  %s: %s", s:HEADER_IGNORED_LABEL, join(a:ignoredPaths, s:HEADER_IGNORED_PATH_SEPARATOR)), 3)
	call insert(header, '  Mode: ' . s:HEADER_PLACEHOLDER_MODE, 4)

	return header
endfunction

function! s:defineSyntax()
	execute printf('syntax match finderFilesHeaderIgnoredPaths /\%%(%s:\)\@<=.*/ contained contains=finderFilesHeaderIgnoredPath,finderFilesHeaderIgnoredPathSeparator', s:HEADER_IGNORED_LABEL)
	execute printf('syntax match finderFilesHeaderIgnoredPath /.\{-}\ze\(%s\|$\)/ contained', s:HEADER_IGNORED_PATH_SEPARATOR)
	execute printf('syntax match finderFilesHeaderIgnoredPathSeparator /%s\ze/ contained', s:HEADER_IGNORED_PATH_SEPARATOR)
endfunction

function! s:defineHighlighting()
	hi link finderFilesHeaderIgnoredPath finderHeaderValue
	hi link finderFilesHeaderIgnoredPathSeparator finderHeaderValue
endfunction
