![preview](https://raw.githubusercontent.com/damage220/vim-finder/master/preview.png)

Finder
------
Vim plugin to search files, tags, lines and matches
([demonstration](https://www.youtube.com/watch?v=TvBJhOOSlOc)).
It also provides an API to build your own extensions.

Dependencies
------------
 - Vim 8.0
 - Exuberant ctags
 - Unix find, grep tools

Installation
------------
It is recommended to use a plugin manager like [vim-plug](https://github.com/junegunn/vim-plug) or others.

```vim
Plug 'damage220/vim-finder'
```

Synopsis
--------
Function                             | Command                                 | Description
---                                  | ---                                     | ---
`finder#files([options])`            | `Files [directory] [openBufferCommand]` | List files. Be careful, by default, files are shown in the current buffer. See `openBufferCommand` below.
`finder#tags([options])`             | `Tags`                                  | List buffer tags.
`finder#lines([options])`            | `Lines`                                 | List buffer lines.
`finder#matches(pattern, [options])` | `Matches pattern`                       | List buffer matches.

Where `pattern` is the vim pattern (:help pattern) and `options` is an optional
`Dictionary`. Here is common and mode-specific options.

#### options

Option                  | Type    | Default                       | Description
---                     | ---     | ---                           | ---
`openBufferCommand`     | String  | enew                          | Is used to open new buffer. One of the list `[enew, new, vnew, tabe]`
`bufferName`            | String  | finder                        | Title for the tabline.
`prompt`                | String  | >                             | Text is shown near the query.
`startWith`             | String  |                               | Prepend query with given string.
`handler`               | Funcref | function("finder#handler")    | Do some job with selected item.
`limit`                 | Number  | 100                           | Maximum amount of occurrences.
`finder`                | Funcref | function("finder#getMatches") | Returns List of matched items.
`header`                | List    | see code                      | Block of text shown at the top of the buffer. To hide, pass empty List.
`comparator`            | Funcref | v:null                        | Is passed to vim `sort` function. To disable sorting, pass non-Funcref value.
`grepCommand`           | String  | grep -ni -m %i %%s            | GNU grep pattern used for searching. Used for default `finder`.
`headerContainedGroups` | List    | []                            | List of additional contained syntax groups in the `header`. Useful when you want to define custom syntax highlighting for the `header`.
`syntaxMatchRegion`     | String  | ^.\+                          | Syntax region where matches should be highlighted. For instance, useful to restrict the highlighting only for basename part.

#### finder#files

Option         | Type    | Default                      | Description
---            | ---     | ---                          | ---
`directory`    | String  | .                            | Directory to search in.
`command`      | String  | find %s -type f              | Unix find pattern.
`ignoredPaths` | List    | ["\*/.git/\*", "\*/.svn/\*"] | List of strings are passed to `! -path` flag.
`baseName`     | Boolean | 1                            | Whether or not use basename instead of full path.

**Note:** there are no shortcuts like `<C-v>` and `<C-x>` to open file in
splitted window. You should firstly open one with `:new` or `:vnew` command
and then execute `:Files` command. It is also possible to execute `:Files . vnew`
command. To toggle basename mode use `<C-b>`.

#### finder#tags

Option        | Type    | Default                                              | Description
---           | ---     | ---                                                  | ---
`command`     | String  | ctags -x --sort=no --format=2 --language-force=%s %s | Exuberant ctags pattern.
`showPreview` | Boolean | 1                                                    | Focus tag while navigating.

#### finder#lines

Option        | Type    | Default | Description
---           | ---     | ---     | ---
`showPreview` | Boolean | 1       | Focus line while navigating.

#### finder#matches

Option        | Type    | Default | Description
---           | ---     | ---     | ---
`offsetType`  | Number  | 2       | Specify from which position the next match should be looked for in the string. 1 - after the start of previous match, 2 - after the end.
`showPreview` | Boolean | 1       | Focus match while navigating.

#### Examples

```vim
:call finder#files({"openBufferCommand": "tabe"})
:call finder#matches('function! \zs.\{-}\ze(')
```

Syntax
------
Group                                   |
---                                     |
`finderHeader`                          |
`finderHeaderLabel`                     |
`finderHeaderValue`                     |
`finderHeaderShortcut`                  |
`finderHeaderShortcutSeparator`         |
`finderHeaderShortcutNote`              |
`finderFilesHeaderIgnoredPaths`         |
`finderFilesHeaderIgnoredPath`          |
`finderFilesHeaderIgnoredPathSeparator` |
`finderPrompt`                          |
`finderQuery`                           |
`finderBody`                            |
`finderSelected`                        |
`finderComment`                         |
`finderSelectedComment`                 |
`finderMatch`                           |
`finderSelectedMatch`                   |

Extending
---------
You are free to add your own extensions. To do this, simply call
`finder#custom(items, [options])` or `finder#splitted(items, [options])`
function. The first one is the base that all functions are "inherited" from.
The second is useful when you work with the data in the buffer and, probably,
want to see a preview while navigating. `items` is a List of Dictionaries.
Dictionary should contain at least `raw` key. `finder#splitted` also requires
`item.position` that is a List of two elements: line and column where item
is placed in the buffer.

#### items
Key           | Type   | Required | Default | Description
---           | ---    | ---      | ---     | ---
`raw`         | String | Yes      |         | Used to make search.
`visibleLine` | String | No       | `raw`   | Used to show in the buffer.
`comment`     | String | No       |         | Used to show to the right of the `visibleLine`.

#### Events
Event                | Description
---                  | ---
`FinderCancelled`    | Triggered when `<Esc>` has been pressed.
`FinderItemSelected` | Triggered when new item has been selected.

#### Example

```vim
function! ListFiles(...)
    let options = get(a:, 1, {})
	let options.prompt = "Files> "
	let options.openBufferCommand = "tabe"
    let options.handler = function("OpenFile")

    let items = []
    let files = systemlist("find . -type f")

    if(len(files) == 0)
        return finder#error("There are no files in this directory.")
    endif

    for file in files
        let item = {}
        let item.raw = file
        " You probably want to add something else to this dictionary.

        call add(items, item)
    endfor

	call finder#custom(items, options)
endfunction

function! OpenFile(item)
    execute printf("edit %s", fnameescape(a:item.raw))
endfunction
```

When `<CR>` or `<C-o>` has been pressed, `OpenFile` function will be called
and the selected item will be passed to the `handler`.

#### header

```vim
function! ListFiles(...)
    let options = get(a:, 1, {})
	let options.header = [
		\ repeat("=", 17),
		\ "Foobar: {foobar}",
		\ repeat("=", 17),
	\ ]

	" create items list
	let items ...

	call finder#init(items, options)

	let b:foobar = "some value"

	call finder#fill()
endfunction
```

String wrapped with {} is a variable. `Finder` parses all strings in `header`,
find variables and fill them with appropriate buffer variables. That is why in
this example we do not use `finder#custom` function, because it also includes
header rendering and since there is no `b:foobar` variable we need firstly
create a buffer, assign variable and then call `finder#fill` function.
Then you can change `b:foobar` as much as you want. Do not forget to call
`finder#updateHeader` after resetting value. Of course, if you need not complex
logic it is more rational to use static text. You also can overload
`finder#getHeader` function in your `.vimrc` to apply new header globally.

Default header uses `b:matchesAmount` and `b:itemsAmount`. You can use them too
and all other buffer variables defined by default. You can list all buffer
variables typing `:echo b:` and pressing `<Tab>`. Of course, you can simply
open the source code.

License
-------
MIT License
