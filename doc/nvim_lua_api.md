# Lua - Neovim docs

_Nvim `:help` pages, generated from source using the tree-sitter-vimdoc parser._

* * *

Lua engine `Lua`

INTRODUCTION lua-intro
------------------------------------

The Lua 5.1 script engine is builtin and always available. Try this command to get an idea of what lurks beneath:

```
:lua vim.print(package.loaded)
```

Nvim includes a "standard library" lua-stdlib for Lua. It complements the "editor stdlib" (builtin-functions and Ex-commands) and the API, all of which can be used from Lua code (lua-vimscript vim.api). Together these "namespaces" form the Nvim programming interface.

Lua plugins and user config are automatically discovered and loaded, just like Vimscript. See lua-guide for practical guidance.

You can also run Lua scripts from your shell using the \-l argument:

```
nvim -l foo.lua [args...]
```

`lua-compat` Lua 5.1 is the permanent interface for Nvim Lua. Plugins should target Lua 5.1 as specified in luaref; later versions (which are essentially different, incompatible, dialects) are not supported. This includes extensions such as `goto` that some Lua 5.1 interpreters like LuaJIT may support.

`lua-luajit` While Nvim officially only requires Lua 5.1 support, it should be built with LuaJIT or a compatible fork on supported platforms for performance reasons. LuaJIT also comes with useful extensions such as `ffi`, lua-profile, and enhanced standard library functions; these cannot be assumed to be available, and Lua code in init.lua or plugins should check the `jit` global variable before using them:

```
if jit then
  -- code for luajit
else
  -- code for plain lua 5.1
end
```

`lua-bit` One exception is the LuaJIT `bit` extension, which is always available: when built with PUC Lua, Nvim includes a fallback implementation which provides `require("bit")`.

`lua-profile` If Nvim is built with LuaJIT, Lua code can be profiled via

```
-- Start a profiling session:
require('jit.p').start('ri1', '/tmp/profile')
-- Perform arbitrary tasks (use plugins, scripts, etc.) ...
-- Stop the session. Profile is written to /tmp/profile.
require('jit.p').stop()
```

See <https://luajit.org/ext\_profiler.html> or the `p.lua` source for details:

```
:lua vim.cmd.edit(package.searchpath('jit.p', package.path))
```

LUA CONCEPTS AND IDIOMS lua-concepts
-----------------------------------------------------

Lua is very simple, and \_consistent\_: while there are some quirks, once you internalize those quirks, everything works the same everywhere. Scopes (closures) in particular are very consistent, unlike JavaScript or most other languages.

Lua has three fundamental mechanisms—one for "each major aspect of programming": tables, closures, and coroutines. <https://www.lua.org/doc/cacm2018.pdf>

Tables are the "object" or container datastructure: they represent both lists and maps, you can extend them to represent your own datatypes and change their behavior using metatables (like Python's "datamodel").

EVERY scope in Lua is a closure: a function is a closure, a module is a closure, a `do` block (lua-do) is a closure--and they all work the same. A Lua module is literally just a big closure discovered on the "path" (where your modules are found: package.cpath).

Stackful coroutines enable cooperative multithreading, generators, and versatile control for both Lua and its host (Nvim).

`lua-error-handling` Lua functions may throw lua-errors for exceptional (unexpected) failures, which you can handle with pcall()). `lua-result-or-message` When failure is normal and expected, it's idiomatic to return `nil` which signals to the caller that failure is not "exceptional" and must be handled. This "result-or-message" pattern is expressed as the multi-value return type `any|nil,nil|string`, or in LuaLS notation:

```
---@return any|nil    # result on success, nil on failure.
---@return nil|string # nil on success, error message on failure.
```

Examples of the "result-or-message" pattern:

When a caller can't proceed on failure, it's idiomatic to `assert()` the "result-or-message" result:

```
local value = assert(fn())
```

Guidance: use the "result-or-message" pattern for...

Functions where failure is expected, especially when communicating with the external world. E.g. HTTP requests or LSP requests often fail because of server problems, even if the caller did everything right.

Functions that return a value, e.g. Foo:new().

When there is a list of known error codes which can be returned as a third value (like luv-error-handling).

`iterator` An iterator is just a function that can be called repeatedly to get the "next" value of a collection (or any other iterable). This interface is expected by for-in loops, produced by pairs()), supported by vim.iter, etc. <https://www.lua.org/pil/7.1.html>

`iterable` An "iterable" is anything that vim.iter()) can consume: tables, dicts, lists, iterator functions, tables implementing the \_\_call()) metamethod, and vim.iter()) objects.

`list-iterator` Iterators on lua-list tables have a "middle" and "end", whereas iterators in general may be logically infinite. Therefore some vim.iter operations (e.g. Iter:rev())) make sense only on list-like tables (which are finite by definition).

`lua-function-call` Lua functions can be called in multiple ways. Consider the function:

```
local foo = function(a, b)
    print("A: ", a)
    print("B: ", b)
end
```

The first way to call this function is:

```
foo(1, 2)
-- ==== Result ====
-- A: 1
-- B: 2
```

This way of calling a function is familiar from most scripting languages. In Lua, any missing arguments are passed as `nil`, and extra parameters are silently discarded. Example:

```
foo(1)
-- ==== Result ====
-- A: 1
-- B: nil
```

`kwargs` When calling a function, you can omit the parentheses if the function takes exactly one string literal (`"foo"`) or table literal (`{1,2,3}`). The latter is often used to mimic "named parameters" ("kwargs" or "keyword args") as in languages like Python and C#. Example:

```
local func_with_opts = function(opts)
    local will_do_foo = opts.foo
    local filename = opts.filename
    ...
end
func_with_opts { foo = true, filename = "hello.world" }
```

There's nothing special going on here except that parentheses are implicitly added. But visually, this small bit of sugar gets reasonably close to a "keyword args" interface.

`lua-regex` Lua intentionally does not support regular expressions, instead it has limited lua-patterns which avoid the performance pitfalls of extended regex. Lua scripts can also use Vim regex via vim.regex()).

Examples:

```
print(string.match("foo123bar123", "%d+"))
-- 123
print(string.match("foo123bar123", "[^%d]+"))
-- foo
print(string.match("foo123bar123", "[abc]+"))
-- ba
print(string.match("foo.bar", "%.bar"))
-- .bar
```

IMPORTING LUA MODULES lua-module-load
---------------------------------------------------------

Modules are searched for under the directories specified in 'runtimepath', in the order they appear. Any "." in the module name is treated as a directory separator when searching. For a module `foo.bar`, each directory is searched for `lua/foo/bar.lua`, then `lua/foo/bar/init.lua`. If no files are found, the directories are searched again for a shared library with a name matching `lua/foo/bar.?`, where `?` is a list of suffixes (such as `so` or `dll`) derived from the initial value of package.cpath. If still no files are found, Nvim falls back to Lua's default search mechanism. The first script found is run and `require()` returns the value returned by the script if any, else `true`.

The return value is cached after the first call to `require()` for each module, with subsequent calls returning the cached value without searching for, or executing any script. For further details see require()).

For example, if 'runtimepath' is `foo,bar` and package.cpath was `./?.so;./?.dll` at startup, `require('mod')` searches these paths in order and loads the first module found ("first wins"):

```
foo/lua/mod.lua
foo/lua/mod/init.lua
bar/lua/mod.lua
bar/lua/mod/init.lua
foo/lua/mod.so
foo/lua/mod.dll
bar/lua/mod.so
bar/lua/mod.dll
```

`lua-package-path` Nvim automatically adjusts package.path and package.cpath according to the effective 'runtimepath' value. Adjustment happens whenever 'runtimepath' is changed. `package.path` is adjusted by simply appending `/lua/?.lua` and `/lua/?/init.lua` to each directory from 'runtimepath' (`/` is actually the first character of `package.config`).

Similarly to package.path, modified directories from 'runtimepath' are also added to package.cpath. In this case, instead of appending `/lua/?.lua` and `/lua/?/init.lua` to each runtimepath, all unique `?`\-containing suffixes of the existing package.cpath are used. Example:

1\. Given that

initial package.cpath (defined at compile-time or derived from `$LUA_CPATH` / `$LUA_INIT`) contains `./?.so;/def/ghi/a?d/j/g.elf;/def/?.so`.

2\. It finds `?`\-containing suffixes `/?.so`, `/a?d/j/g.elf` and `/?.so`, in order: parts of the path starting from the first path component containing question mark and preceding path separator.

3\. The suffix of `/def/?.so`, namely `/?.so` is not unique, as it’s the same as the suffix of the first path from package.path (i.e. `./?.so`). Which leaves `/?.so` and `/a?d/j/g.elf`, in this order.

4\. 'runtimepath' has three paths: `/foo/bar`, `/xxx;yyy/baz` and `/abc`. The second one contains a semicolon which is a paths separator so it is out, leaving only `/foo/bar` and `/abc`, in order.

5\. The cartesian product of paths from 4. and suffixes from 3. is taken, giving four variants. In each variant a `/lua` path segment is inserted between path and suffix, leaving:

`/foo/bar/lua/?.so`

`/foo/bar/lua/a?d/j/g.elf`

`/abc/lua/?.so`

`/abc/lua/a?d/j/g.elf`

6\. New paths are prepended to the original package.cpath.

The result will look like this:

```
/foo/bar,/xxx;yyy/baz,/abc ('runtimepath')
× ./?.so;/def/ghi/a?d/j/g.elf;/def/?.so (package.cpath)
= /foo/bar/lua/?.so;/foo/bar/lua/a?d/j/g.elf;/abc/lua/?.so;/abc/lua/a?d/j/g.elf;./?.so;/def/ghi/a?d/j/g.elf;/def/?.so
```

**Note:**

To track 'runtimepath' updates, paths added at previous update are remembered and removed at the next update, while all paths derived from the new 'runtimepath' are prepended as described above. This allows removing paths when path is removed from 'runtimepath', adding paths when they are added and reordering package.path/|package.cpath| content if 'runtimepath' was reordered.

Although adjustments happen automatically, Nvim does not track current values of package.path or package.cpath. If you happen to delete some paths from there you can set 'runtimepath' to trigger an update:

```
let &runtimepath = &runtimepath
```

Skipping paths from 'runtimepath' which contain semicolons applies both to package.path and package.cpath. Given that there are some badly written plugins using shell, which will not work with paths containing semicolons, it is better to not have them in 'runtimepath' at all.

COMMANDS lua-commands
--------------------------------------

These commands execute a Lua chunk from either the command line (:lua, :luado) or a file (:luafile) on the given line \[range\]. As always in Lua, each chunk has its own scope (closure), so only global variables are shared between command calls. The lua-stdlib modules, user modules, and anything else on package.path are available.

The Lua print() function redirects its output to the Nvim message area, with arguments separated by " " (space) instead of "\\t" (tab).

`:lua=` `:lua` :lua `{chunk}` Executes Lua chunk `{chunk}`. If `{chunk}` starts with "=" the rest of the chunk is evaluated as an expression and printed. `:lua =expr` and `:=expr` are equivalent to `:lua vim.print(expr)`.

Examples:

```
:lua vim.api.nvim_command('echo "Hello, Nvim!"')
```

To see the Lua version:

```
:lua print(_VERSION)
```

To see the LuaJIT version:

```
:lua =jit.version
```

:{range}lua Executes buffer lines in `{range}` as Lua code. Unlike :source, this always treats the lines as Lua code.

Example: select the following code and type ":lua<Enter>" to execute it:

```
print(string.format(
    'unix time: %s', os.time()))
```

`:lua-heredoc` :lua << \[trim\] \[`{endmarker}`\] `{script}` `{endmarker}` Executes Lua script `{script}` from within Vimscript. You can omit \[endmarker\] after the "<<" and use a dot "." after `{script}` (similar to :append, :insert). Refer to :let-heredoc for more information.

Example:

```
function! CurrentLineInfo()
lua << EOF
local linenr = vim.api.nvim_win_get_cursor(0)[1]
local curline = vim.api.nvim_buf_get_lines(0, linenr - 1, linenr, false)[1]
print(string.format('Line [%d] has %d bytes', linenr, #curline))
EOF
endfunction
```

Note that the `local` variables will disappear when the block finishes. But not globals.

`:luado` :\[range\]luado `{body}` Executes Lua chunk "function(line, linenr) `{body}` end" for each buffer line in \[range\], where `line` is the current line text (without `<EOL>`), and `linenr` is the current line number. If the function returns a string that becomes the text of the corresponding buffer line. Default \[range\] is the whole file: "1,$".

Examples:

```
:luado return string.format("%s\t%d", line:reverse(), #line)
:lua require"lpeg"
:lua -- balanced parenthesis grammar:
:lua bp = lpeg.P{ "(" * ((1 - lpeg.S"()") + lpeg.V(1))^0 * ")" }
:luado if bp:match(line) then return "=>\t" .. line end
```

`:luafile` :luafile `{file}` Execute Lua script in `{file}`. The whole argument is used as the filename (like :edit), spaces do not need to be escaped. Alternatively you can :source Lua files.

Examples:

```
:luafile script.lua
:luafile %
```

luaeval() lua-eval
-------------------------------

The (dual) equivalent of "vim.eval" for passing Lua values to Nvim is "luaeval". "luaeval" takes an expression string and an optional argument used for \_A inside expression and returns the result of the expression. It is semantically equivalent in Lua to:

```
local chunkheader = "local _A = select(1, ...) return "
function luaeval (expstr, arg)
    local chunk = assert(loadstring(chunkheader .. expstr, "luaeval"))
    return chunk(arg) -- return typval
end
```

Lua nils, numbers, strings, tables and booleans are converted to their respective Vimscript types. If a Lua string contains a NUL byte, it will be converted to a Blob. Conversion of other Lua types is an error.

The magic global "\_A" contains the second argument to luaeval().

Example:

```
:echo luaeval('_A[1] + _A[2]', [40, 2])
" 42
:echo luaeval('string.match(_A, "[a-z]+")', 'XYXfoo123')
" foo
```

`lua-table-ambiguous` Lua tables are used as both dictionaries and lists, so it is impossible to decide whether empty table is a list or a dict. Also Lua does not have integer numbers. To disambiguate these cases, we define: `lua-list` 0. Empty table is a list. Use vim.empty\_dict()) to represent empty dict. 1. Table with N consecutive (no `nil` values, aka "holes") integer keys 1…N is a list. See also list-iterator. `lua-dict` 2. Table with string keys, none of which contains NUL byte, is a dict. 3. Table with string keys, at least one of which contains NUL byte, is also considered to be a dictionary, but this time it is converted to a msgpack-special-map. `lua-special-tbl` 4. Table with `vim.type_idx` key may be a dictionary, a list or floating-point value:

`{[vim.type_idx]=vim.types.float, [vim.val_idx]=1}` is converted to a floating-point 1.0. Note that by default integral Lua numbers are converted to Numbers, non-integral are converted to Floats. This variant allows integral Floats.

`{[vim.type_idx]=vim.types.dictionary}` is converted to an empty dictionary, `{[vim.type_idx]=vim.types.dictionary, [42]=1, a=2}` is converted to a dictionary `{'a': 42}`: non-string keys are ignored. Without `vim.type_idx` key tables with keys not fitting in 1., 2. or 3. are errors.

`{[vim.type_idx]=vim.types.array}` is converted to an empty list. As well as `{[vim.type_idx]=vim.types.array, [42]=1}`: integral keys that do not form a 1-step sequence from 1 to N are ignored, as well as all non-integral keys.

Examples:

```
:echo luaeval('math.pi')
:function Rand(x,y) " random uniform between x and y
:  return luaeval('(_A.y-_A.x)*math.random()+_A.x', {'x':a:x,'y':a:y})
:  endfunction
:echo Rand(1,10)
```

**Note:** Second argument to `luaeval` is converted ("marshalled") from Vimscript to Lua, so changes to Lua containers do not affect values in Vimscript. Return value is also always converted. When converting, msgpack-special-dicts are treated specially.

Vimscript v:lua interface v:lua-call
-----------------------------------------------------

From Vimscript the special `v:lua` prefix can be used to call Lua functions which are global or accessible from global tables. The expression

```
call v:lua.func(arg1, arg2)
```

is equivalent to the Lua chunk

```
return func(...)
```

where the args are converted to Lua values. The expression

```
call v:lua.somemod.func(args)
```

is equivalent to the Lua chunk

```
return somemod.func(...)
```

In addition, functions of packages can be accessed like

```
call v:lua.require'mypack'.func(arg1, arg2)
call v:lua.require'mypack.submod'.func(arg1, arg2)
```

**Note:** Only single quote form without parens is allowed. Using `require"mypack"` or `require('mypack')` as prefixes do NOT work (the latter is still valid as a function call of itself, in case require returns a useful value).

The `v:lua` prefix may be used to call Lua functions as methods. For example:

```
:eval arg1->v:lua.somemod.func(arg2)
```

You can use `v:lua` in "func" options like 'tagfunc', 'omnifunc', etc. For example consider the following Lua omnifunc handler:

```
function mymod.omnifunc(findstart, base)
  if findstart == 1 then
    return 0
  else
    return {'stuff', 'steam', 'strange things'}
  end
end
vim.bo[buf].omnifunc = 'v:lua.mymod.omnifunc'
```

**Note:** The module ("mymod" in the above example) must either be a Lua global, or use require() as shown above to access it from a package.

**Note:** `v:lua` without a call is not allowed in a Vimscript expression: Funcrefs cannot represent Lua functions. The following are errors:

```
let g:Myvar = v:lua.myfunc        " Error
call SomeFunc(v:lua.mycallback)   " Error
let g:foo = v:lua                 " Error
let g:foo = v:['lua']             " Error
```

Lua standard modules lua-stdlib
----------------------------------------------

The Nvim Lua "standard library" (stdlib) is the `vim` module, which exposes various functions and sub-modules. It is always loaded, thus `require("vim")` is unnecessary.

You can peek at the module properties:

```
:lua vim.print(vim)
```

Result is something like this:

```
{
  _os_proc_children = <function 1>,
  _os_proc_info = <function 2>,
  ...
  api = {
    nvim__id = <function 5>,
    nvim__id_array = <function 6>,
    ...
  },
  deepcopy = <function 106>,
  gsplit = <function 107>,
  ...
}
```

To find documentation on e.g. the "deepcopy" function:

```
:help vim.deepcopy()
```

Note that underscore-prefixed functions (e.g. "\_os\_proc\_children") are internal/private and must not be used by plugins.

### VIM.UV lua-loop vim.uv

`vim.uv` exposes the "luv" Lua bindings for the libUV library that Nvim uses for networking, filesystem, and process management, see luvref.txt. In particular, it allows interacting with the main Nvim luv-event-loop.

`E5560` `lua-loop-callbacks` It is an error to directly invoke `vim.api` functions (except api-fast) in `vim.uv` callbacks. For example, this is an error:

```
local timer = vim.uv.new_timer()
timer:start(1000, 0, function()
  vim.api.nvim_command('echomsg "test"')
end)
```

To avoid the error use vim.schedule\_wrap()) to defer the callback:

```
local timer = vim.uv.new_timer()
timer:start(1000, 0, vim.schedule_wrap(function()
  vim.api.nvim_command('echomsg "test"')
end))
```

(For one-shot timers, see vim.defer\_fn()), which automatically adds the wrapping.)

Example: repeating timer 1. Save this code to a file. 2. Execute it with ":luafile %".

```
-- Create a timer handle (implementation detail: uv_timer_t).
local timer = vim.uv.new_timer()
local i = 0
-- Waits 1000ms, then repeats every 750ms until timer:close().
timer:start(1000, 750, function()
  print('timer invoked! i='..tostring(i))
  if i > 4 then
    timer:close()  -- Always close handles to avoid leaks.
  end
  i = i + 1
end)
print('sleeping');
```

Example: File-change detection `watch-file` 1. Save this code to a file. 2. Execute it with ":luafile %". 3. Use ":Watch %" to watch any file. 4. Try editing the file from another text editor. 5. Observe that the file reloads in Nvim (because on\_change() calls :checktime).

```
local w = vim.uv.new_fs_event()
local function on_change(err, fname, status)
  -- Do work...
  vim.api.nvim_command('checktime')
  -- Debounce: stop/start.
  w:stop()
  watch_file(fname)
end
function watch_file(fname)
  local fullpath = vim.api.nvim_call_function(
    'fnamemodify', {fname, ':p'})
  w:start(fullpath, {}, vim.schedule_wrap(function(...)
    on_change(...) end))
end
vim.api.nvim_command(
  "command! -nargs=1 Watch call luaeval('watch_file(_A)', expand('<args>'))")
```

`inotify-limitations` When on Linux you may need to increase the maximum number of `inotify` watches and queued events as the default limit can be too low. To increase the limit, run:

```
sysctl fs.inotify.max_user_watches=494462
```

This will increase the limit to 494462 watches and queued events. These lines can be added to `/etc/sysctl.conf` to make the changes persistent.

Note that each watch is a structure in the Kernel, thus available memory is also a bottleneck for using inotify. In fact, a watch can take up to 1KB of space. This means a million watches could result in 1GB of extra RAM usage.

Example: TCP echo-server `tcp-server` 1. Save this code to a file. 2. Execute it with ":luafile %". 3. Note the port number. 4. Connect from any TCP client (e.g. "nc 0.0.0.0 36795"):

```
local function create_server(host, port, on_connect)
  local server = vim.uv.new_tcp()
  server:bind(host, port)
  server:listen(128, function(err)
    assert(not err, err)  -- Check for errors.
    local sock = vim.uv.new_tcp()
    server:accept(sock)  -- Accept client connection.
    on_connect(sock)  -- Start reading messages.
  end)
  return server
end
local server = create_server('0.0.0.0', 0, function(sock)
  sock:read_start(function(err, chunk)
    assert(not err, err)  -- Check for errors.
    if chunk then
      sock:write(chunk)  -- Echo received messages to the channel.
    else  -- EOF (stream closed).
      sock:close()  -- Always close handles to avoid leaks.
    end
  end)
end)
print('TCP echo-server listening on port: '..server:getsockname().port)
```

Multithreading `lua-loop-threading`

Plugins can perform work in separate (os-level) threads using the threading APIs in luv, for instance `vim.uv.new_thread`. Note that every thread gets its own separate Lua interpreter state, with no access to Lua globals in the main thread. Neither can the state of the editor (buffers, windows, etc) be directly accessed from threads.

A subset of the `vim.*` API is available in threads. This includes:

`vim.uv` with a separate event loop per thread.

`vim.mpack` and `vim.json` (useful for serializing messages between threads)

`require` in threads can use Lua packages from the global package.path

`print()` and `vim.inspect`

`vim.diff`

most utility functions in `vim.*` for working with pure Lua values like `vim.split`, `vim.tbl_*`, `vim.list_*`, and so on.

`vim.is_thread()` returns true from a non-main thread.

VIM.HIGHLIGHT vim.highlight
---------------------------------------------

vim.highlight.on\_yank(`{opts}`) `vim.highlight.on_yank())` Highlight the yanked text during a TextYankPost event.

Add the following to your `init.vim`:

```
autocmd TextYankPost * silent! lua vim.highlight.on_yank {higroup='Visual', timeout=300}
```

Parameters:

`{opts}` (`table?`) Optional parameters

higroup highlight group for yanked region (default "IncSearch")

timeout time in ms before highlight is cleared (default 150)

on\_macro highlight when executing macro (default false)

on\_visual highlight when yanking visual selection (default true)

event event structure (default vim.v.event)

vim.highlight.priorities `vim.highlight.priorities` Table with default priorities used for highlighting:

`syntax`: `50`, used for standard syntax highlighting

`treesitter`: `100`, used for treesitter-based highlighting

`semantic_tokens`: `125`, used for LSP semantic token highlighting

`diagnostics`: `150`, used for code analysis such as diagnostics

`user`: `200`, used for user-triggered highlights such as LSP document symbols or `on_yank` autocommands

`vim.highlight.range())` vim.highlight.range(`{bufnr}`, `{ns}`, `{higroup}`, `{start}`, `{finish}`, `{opts}`) Apply highlight group to range of text.

Parameters:

`{bufnr}` (`integer`) Buffer number to apply highlighting to

`{ns}` (`integer`) Namespace to add highlight to

`{higroup}` (`string`) Highlight group to use for highlighting

`{start}` (`integer[]|string`) Start of region as a (line, column) tuple or string accepted by getpos())

`{finish}` (`integer[]|string`) End of region as a (line, column) tuple or string accepted by getpos())

`{opts}` (`table?`) A table with the following fields:

`{regtype}` (`string`, default: `'v'` i.e. charwise) Type of range. See getregtype())

`{inclusive}` (`boolean`, default: `false`) Indicates whether the range is end-inclusive

`{priority}` (`integer`, default: `vim.highlight.priorities.user`) Indicates priority of highlight

VIM.DIFF vim.diff
------------------------------

vim.diff(`{a}`, `{b}`, `{opts}`) `vim.diff())` Run diff on strings `{a}` and `{b}`. Any indices returned by this function, either directly or via callback arguments, are 1-based.

Examples:

```
vim.diff('a\n', 'b\nc\n')
-- =>
-- @@ -1 +1,2 @@
-- -a
-- +b
-- +c
vim.diff('a\n', 'b\nc\n', {result_type = 'indices'})
-- =>
-- {
--   {1, 1, 1, 2}
-- }
```

Parameters:

`{a}` (`string`) First string to compare

`{b}` (`string`) Second string to compare

`{opts}` (`table`) Optional parameters:

`{on_hunk}` (`fun(start_a: integer, count_a: integer, start_b: integer, count_b: integer): integer`) Invoked for each hunk in the diff. Return a negative number to cancel the callback for any remaining hunks. Arguments:

`start_a` (`integer`): Start line of hunk in `{a}`.

`count_a` (`integer`): Hunk size in `{a}`.

`start_b` (`integer`): Start line of hunk in `{b}`.

`count_b` (`integer`): Hunk size in `{b}`.

`{result_type}` (`'unified'|'indices'`, default: `'unified'`) Form of the returned diff:

`unified`: String in unified format.

`indices`: Array of hunk locations. **Note:** This option is ignored if `on_hunk` is used.

`{linematch}` (`boolean|integer`) Run linematch on the resulting hunks from xdiff. When integer, only hunks upto this size in lines are run through linematch. Requires `result_type = indices`, ignored otherwise.

`{algorithm}` (`'myers'|'minimal'|'patience'|'histogram'`, default: `'myers'`) Diff algorithm to use. Values:

`myers`: the default algorithm

`minimal`: spend extra time to generate the smallest possible diff

`patience`: patience diff algorithm

`histogram`: histogram diff algorithm

`{ctxlen}` (`integer`) Context length

`{interhunkctxlen}` (`integer`) Inter hunk context length

`{ignore_whitespace}` (`boolean`) Ignore whitespace

`{ignore_whitespace_change}` (`boolean`) Ignore whitespace change

`{ignore_whitespace_change_at_eol}` (`boolean`) Ignore whitespace change at end-of-line.

`{ignore_cr_at_eol}` (`boolean`) Ignore carriage return at end-of-line

`{ignore_blank_lines}` (`boolean`) Ignore blank lines

`{indent_heuristic}` (`boolean`) Use the indent heuristic for the internal diff library.

Return:

(`string|integer[]`) See `{opts.result_type}`. `nil` if `{opts.on_hunk}` is given.

VIM.MPACK vim.mpack
---------------------------------

This module provides encoding and decoding of Lua objects to and from msgpack-encoded strings. Supports vim.NIL and vim.empty\_dict()).

vim.mpack.decode(`{str}`) `vim.mpack.decode())` Decodes (or "unpacks") the msgpack-encoded `{str}` to a Lua object.

Parameters:

`{str}` (`string`)

vim.mpack.encode(`{obj}`) `vim.mpack.encode())` Encodes (or "packs") Lua object `{obj}` as msgpack in a Lua string.

VIM.JSON vim.json
------------------------------

This module provides encoding and decoding of Lua objects to and from JSON-encoded strings. Supports vim.NIL and vim.empty\_dict()).

vim.json.decode(`{str}`, `{opts}`) `vim.json.decode())` Decodes (or "unpacks") the JSON-encoded `{str}` to a Lua object.

Decodes JSON "null" as vim.NIL (controllable by `{opts}`, see below).

Decodes empty array as `{}` (empty Lua table).

Example:

```
vim.print(vim.json.decode('{"bar":[],"foo":{},"zub":null}'))
-- { bar = {}, foo = vim.empty_dict(), zub = vim.NIL }
```

Parameters:

`{str}` (`string`) Stringified JSON data.

`{opts}` (`table<string,any>?`) Options table with keys:

luanil: (table) Table with keys:

object: (boolean) When true, converts `null` in JSON objects to Lua `nil` instead of vim.NIL.

array: (boolean) When true, converts `null` in JSON arrays to Lua `nil` instead of vim.NIL.

vim.json.encode(`{obj}`) `vim.json.encode())` Encodes (or "packs") Lua object `{obj}` as JSON in a Lua string.

VIM.BASE64 vim.base64
------------------------------------

vim.base64.decode(`{str}`) `vim.base64.decode())` Decode a Base64 encoded string.

Parameters:

`{str}` (`string`) Base64 encoded string

Return:

(`string`) Decoded string

vim.base64.encode(`{str}`) `vim.base64.encode())` Encode `{str}` using Base64.

Parameters:

`{str}` (`string`) String to encode

Return:

(`string`) Encoded string

VIM.SPELL vim.spell
---------------------------------

vim.spell.check(`{str}`) `vim.spell.check())` Check `{str}` for spelling errors. Similar to the Vimscript function spellbadword()).

Example:

```
vim.spell.check("the quik brown fox")
-- =>
-- {
--     {'quik', 'bad', 5}
-- }
```

Parameters:

`{str}` (`string`)

Return:

(`[string, 'bad'|'rare'|'local'|'caps', integer][]`) List of tuples with three items:

The badly spelled word.

The type of the spelling error: "bad" spelling mistake "rare" rare word "local" word only valid in another region "caps" word should start with Capital

The position in `{str}` where the word begins.

VIM vim.builtin
-------------------------------

vim.api.{func}(`{...}`) `vim.api` Invokes Nvim API function `{func}` with arguments `{...}`. Example: call the "nvim\_get\_current\_line()" API function:

```
print(tostring(vim.api.nvim_get_current_line()))
```

vim.NIL `vim.NIL` Special value representing NIL in RPC and v:null in Vimscript conversion, and similar cases. Lua `nil` cannot be used as part of a Lua table representing a Dictionary or Array, because it is treated as missing: `{"foo", nil}` is the same as `{"foo"}`.

vim.type\_idx `vim.type_idx` Type index for use in lua-special-tbl. Specifying one of the values from vim.types allows typing the empty table (it is unclear whether empty Lua table represents empty list or empty array) and forcing integral numbers to be Float. See lua-special-tbl for more details.

vim.val\_idx `vim.val_idx` Value index for tables representing Floats. A table representing floating-point value 1.0 looks like this:

```
{
  [vim.type_idx] = vim.types.float,
  [vim.val_idx] = 1.0,
}
```

vim.types `vim.types` Table with possible values for vim.type\_idx. Contains two sets of key-value pairs: first maps possible values for vim.type\_idx to human-readable strings, second maps human-readable type names to values for vim.type\_idx. Currently contains pairs for `float`, `array` and `dictionary` types.

**Note:** One must expect that values corresponding to `vim.types.float`, `vim.types.array` and `vim.types.dictionary` fall under only two following assumptions: 1. Value may serve both as a key and as a value in a table. Given the properties of Lua tables this basically means “value is not `nil`”. 2. For each value in `vim.types` table `vim.types[vim.types[value]]` is the same as `value`. No other restrictions are put on types, and it is not guaranteed that values corresponding to `vim.types.float`, `vim.types.array` and `vim.types.dictionary` will not change or that `vim.types` table will only contain values for these three types.

`log_levels` `vim.log.levels` Log levels are one of the values defined in `vim.log.levels`:

vim.log.levels.DEBUG vim.log.levels.ERROR vim.log.levels.INFO vim.log.levels.TRACE vim.log.levels.WARN vim.log.levels.OFF

vim.empty\_dict() `vim.empty_dict())` Creates a special empty table (marked with a metatable), which Nvim converts to an empty dictionary when translating Lua values to Vimscript or API types. Nvim by default converts an empty table `{}` without this metatable to an list/array.

**Note:** If numeric keys are present in the table, Nvim ignores the metatable marker and converts the dict to a list/array anyway.

vim.iconv(`{str}`, `{from}`, `{to}`) `vim.iconv())` The result is a String, which is the text `{str}` converted from encoding `{from}` to encoding `{to}`. When the conversion fails `nil` is returned. When some characters could not be converted they are replaced with "?". The encoding names are whatever the iconv() library function can accept, see ":Man 3 iconv".

Parameters:

`{str}` (`string`) Text to convert

`{from}` (`string`) Encoding of `{str}`

`{to}` (`string`) Target encoding

Return:

(`string?`) Converted string if conversion succeeds, `nil` otherwise.

vim.in\_fast\_event() `vim.in_fast_event())` Returns true if the code is executing as part of a "fast" event handler, where most of the API is disabled. These are low-level events (e.g. lua-loop-callbacks) which can be invoked whenever Nvim polls for input. When this is `false` most API functions are callable (but may be subject to other restrictions such as textlock).

vim.rpcnotify(`{channel}`, `{method}`, `{...}`) `vim.rpcnotify())` Sends `{event}` to `{channel}` via RPC and returns immediately. If `{channel}` is 0, the event is broadcast to all channels.

Parameters:

`{channel}` (`integer`)

`{method}` (`string`)

`{...}` (`any?`)

vim.rpcrequest(`{channel}`, `{method}`, `{...}`) `vim.rpcrequest())` Sends a request to `{channel}` to invoke `{method}` via RPC and blocks until a response is received.

**Note:** NIL values as part of the return value is represented as vim.NIL special value

Parameters:

`{channel}` (`integer`)

`{method}` (`string`)

`{...}` (`any?`)

vim.schedule(`{fn}`) `vim.schedule())` Schedules `{fn}` to be invoked soon by the main event-loop. Useful to avoid textlock or other temporary restrictions.

vim.str\_byteindex(`{str}`, `{index}`, `{use_utf16}`) `vim.str_byteindex())` Convert UTF-32 or UTF-16 `{index}` to byte index. If `{use_utf16}` is not supplied, it defaults to false (use UTF-32). Returns the byte index.

Invalid UTF-8 and NUL is treated like in vim.str\_utfindex()). An `{index}` in the middle of a UTF-16 sequence is rounded upwards to the end of that sequence.

Parameters:

`{str}` (`string`)

`{index}` (`integer`)

`{use_utf16}` (`boolean?`)

vim.str\_utf\_end(`{str}`, `{index}`) `vim.str_utf_end())` Gets the distance (in bytes) from the last byte of the codepoint (character) that `{index}` points to.

Examples:

```
-- The character 'æ' is stored as the bytes '\xc3\xa6' (using UTF-8)
-- Returns 0 because the index is pointing at the last byte of a character
vim.str_utf_end('æ', 2)
-- Returns 1 because the index is pointing at the penultimate byte of a character
vim.str_utf_end('æ', 1)
```

Parameters:

`{str}` (`string`)

`{index}` (`integer`)

vim.str\_utf\_pos(`{str}`) `vim.str_utf_pos())` Gets a list of the starting byte positions of each UTF-8 codepoint in the given string.

Embedded NUL bytes are treated as terminating the string.

Parameters:

`{str}` (`string`)

vim.str\_utf\_start(`{str}`, `{index}`) `vim.str_utf_start())` Gets the distance (in bytes) from the starting byte of the codepoint (character) that `{index}` points to.

The result can be added to `{index}` to get the starting byte of a character.

Examples:

```
-- The character 'æ' is stored as the bytes '\xc3\xa6' (using UTF-8)
-- Returns 0 because the index is pointing at the first byte of a character
vim.str_utf_start('æ', 1)
-- Returns -1 because the index is pointing at the second byte of a character
vim.str_utf_start('æ', 2)
```

Parameters:

`{str}` (`string`)

`{index}` (`integer`)

vim.str\_utfindex(`{str}`, `{index}`) `vim.str_utfindex())` Convert byte index to UTF-32 and UTF-16 indices. If `{index}` is not supplied, the length of the string is used. All indices are zero-based.

Embedded NUL bytes are treated as terminating the string. Invalid UTF-8 bytes, and embedded surrogates are counted as one code point each. An `{index}` in the middle of a UTF-8 sequence is rounded upwards to the end of that sequence.

Parameters:

`{str}` (`string`)

`{index}` (`integer?`)

Return (multiple):

(`integer`) UTF-32 index (`integer`) UTF-16 index

vim.stricmp(`{a}`, `{b}`) `vim.stricmp())` Compares strings case-insensitively.

Parameters:

`{a}` (`string`)

`{b}` (`string`)

Return:

(`0|1|-1`) if strings are equal, `{a}` is greater than `{b}` or `{a}` is lesser than `{b}`, respectively.

vim.ui\_attach(`{ns}`, `{options}`, `{callback}`) `vim.ui_attach())` Attach to ui events, similar to nvim\_ui\_attach()) but receive events as Lua callback. Can be used to implement screen elements like popupmenu or message handling in Lua.

`{options}` should be a dictionary-like table, where `ext_...` options should be set to true to receive events for the respective external element.

`{callback}` receives event name plus additional parameters. See ui-popupmenu and the sections below for event format for respective events.

**WARNING:** This api is considered experimental. Usability will vary for different screen elements. In particular `ext_messages` behavior is subject to further changes and usability improvements. This is expected to be used to handle messages when setting 'cmdheight' to zero (which is likewise experimental).

Example (stub for a ui-popupmenu implementation):

```
ns = vim.api.nvim_create_namespace('my_fancy_pum')
vim.ui_attach(ns, {ext_popupmenu=true}, function(event, ...)
  if event == "popupmenu_show" then
    local items, selected, row, col, grid = ...
    print("display pum ", #items)
  elseif event == "popupmenu_select" then
    local selected = ...
    print("selected", selected)
  elseif event == "popupmenu_hide" then
    print("FIN")
  end
end)
```

Parameters:

`{ns}` (`integer`)

`{options}` (`table<string, any>`)

`{callback}` (`fun()`)

vim.ui\_detach(`{ns}`) `vim.ui_detach())` Detach a callback previously attached with vim.ui\_attach()) for the given namespace `{ns}`.

Parameters:

`{ns}` (`integer`)

vim.wait(`{time}`, `{callback}`, `{interval}`, `{fast_only}`) `vim.wait())` Wait for `{time}` in milliseconds until `{callback}` returns `true`.

Executes `{callback}` immediately and at approximately `{interval}` milliseconds (default 200). Nvim still processes other events during this time.

Cannot be called while in an api-fast event.

Examples:

```
---
-- Wait for 100 ms, allowing other events to process
vim.wait(100, function() end)
---
-- Wait for 100 ms or until global variable set.
vim.wait(100, function() return vim.g.waiting_for_var end)
---
-- Wait for 1 second or until global variable set, checking every ~500 ms
vim.wait(1000, function() return vim.g.waiting_for_var end, 500)
---
-- Schedule a function to set a value in 100ms
vim.defer_fn(function() vim.g.timer_result = true end, 100)
-- Would wait ten seconds if results blocked. Actually only waits  100 ms
if vim.wait(10000, function() return vim.g.timer_result end) then
  print('Only waiting a little bit of time!')
end
```

Parameters:

`{time}` (`integer`) Number of milliseconds to wait

`{callback}` (`fun(): boolean?`) Optional callback. Waits until `{callback}` returns true

`{interval}` (`integer?`) (Approximate) number of milliseconds to wait between polls

`{fast_only}` (`boolean?`) If true, only api-fast events will be processed.

Return (multiple):

(`boolean`) (`-1|-2?`)

If `{callback}` returns `true` during the `{time}`: `true, nil`

If `{callback}` never returns `true` during the `{time}`: `false, -1`

If `{callback}` is interrupted during the `{time}`: `false, -2`

If `{callback}` errors, the error is raised.

LUA-VIMSCRIPT BRIDGE lua-vimscript
----------------------------------------------------

Nvim Lua provides an interface or "bridge" to Vimscript variables and functions, and editor commands and options.

Objects passed over this bridge are COPIED (marshalled): there are no "references". lua-guide-variables For example, using `vim.fn.remove()` on a Lua list copies the list object to Vimscript and does NOT modify the Lua list:

```
local list = { 1, 2, 3 }
vim.fn.remove(list, 0)
vim.print(list)  --> "{ 1, 2, 3 }"
```

vim.fn.{func}(`{...}`) `vim.fn` Invokes vim-function or user-function `{func}` with arguments `{...}`. To call autoload functions, use the syntax:

```
vim.fn'some#function'
```

Unlike vim.api.|nvim\_call\_function()| this converts directly between Vim objects and Lua objects. If the Vim function returns a float, it will be represented directly as a Lua number. Empty lists and dictionaries both are represented by an empty table.

**Note:** v:null values as part of the return value is represented as vim.NIL special value

**Note:** vim.fn keys are generated lazily, thus `pairs(vim.fn)` only enumerates functions that were called at least once.

**Note:** The majority of functions cannot run in api-fast callbacks with some undocumented exceptions which are allowed.

`lua-vim-variables` The Vim editor global dictionaries g: w: b: t: v: can be accessed from Lua conveniently and idiomatically by referencing the `vim.*` Lua tables described below. In this way you can easily read and modify global Vimscript variables from Lua.

Example:

```
vim.g.foo = 5     -- Set the g:foo Vimscript variable.
print(vim.g.foo)  -- Get and print the g:foo Vimscript variable.
vim.g.foo = nil   -- Delete (:unlet) the Vimscript variable.
vim.b[2].foo = 6  -- Set b:foo for buffer 2
```

Note that setting dictionary fields directly will not write them back into Nvim. This is because the index into the namespace simply returns a copy. Instead the whole dictionary must be written as one. This can be achieved by creating a short-lived temporary.

Example:

```
vim.g.my_dict.field1 = 'value'  -- Does not work
local my_dict = vim.g.my_dict   --
my_dict.field1 = 'value'        -- Instead do
vim.g.my_dict = my_dict         --
```

vim.g `vim.g` Global (g:) editor variables. Key with no value returns `nil`.

vim.b `vim.b` Buffer-scoped (b:) variables for the current buffer. Invalid or unset key returns `nil`. Can be indexed with an integer to access variables for a specific buffer.

vim.w `vim.w` Window-scoped (w:) variables for the current window. Invalid or unset key returns `nil`. Can be indexed with an integer to access variables for a specific window.

vim.t `vim.t` Tabpage-scoped (t:) variables for the current tabpage. Invalid or unset key returns `nil`. Can be indexed with an integer to access variables for a specific tabpage.

vim.v `vim.v` v: variables. Invalid or unset key returns `nil`.

Vim options can be accessed through vim.o, which behaves like Vimscript :set.

To set a boolean toggle: Vimscript: `set number` Lua: `vim.o.number = true`

To set a string value: Vimscript: `set wildignore=*.o,*.a,__pycache__` Lua: `vim.o.wildignore = '*.o,*.a,__pycache__'`

Similarly, there is vim.bo and vim.wo for setting buffer-scoped and window-scoped options. Note that this must NOT be confused with local-options and :setlocal. There is also vim.go that only accesses the global value of a global-local option, see :setglobal.

A special interface vim.opt exists for conveniently interacting with list- and map-style option from Lua: It allows accessing them as Lua tables and offers object-oriented method for adding and removing entries.

The following methods of setting a list-style option are equivalent: In Vimscript:

```
set wildignore=*.o,*.a,__pycache__
```

In Lua using `vim.o`:

```
vim.o.wildignore = '*.o,*.a,__pycache__'
```

In Lua using `vim.opt`:

```
vim.opt.wildignore = { '*.o', '*.a', '__pycache__' }
```

To replicate the behavior of :set+=, use:

```
vim.opt.wildignore:append { "*.pyc", "node_modules" }
```

To replicate the behavior of :set^=, use:

```
vim.opt.wildignore:prepend { "new_first_value" }
```

To replicate the behavior of :set-=, use:

```
vim.opt.wildignore:remove { "node_modules" }
```

The following methods of setting a map-style option are equivalent: In Vimscript:

```
set listchars=space:_,tab:>~
```

In Lua using `vim.o`:

```
vim.o.listchars = 'space:_,tab:>~'
```

In Lua using `vim.opt`:

```
vim.opt.listchars = { space = '_', tab = '>~' }
```

Note that vim.opt returns an `Option` object, not the value of the option, which is accessed through vim.opt:get()):

The following methods of getting a list-style option are equivalent: In Vimscript:

```
echo wildignore
```

In Lua using `vim.o`:

```
print(vim.o.wildignore)
```

In Lua using `vim.opt`:

```
vim.print(vim.opt.wildignore:get())
```

In any of the above examples, to replicate the behavior :setlocal, use `vim.opt_local`. Additionally, to replicate the behavior of :setglobal, use `vim.opt_global`.

Option:append(`{value}`) `vim.opt:append())` Append a value to string-style options. See :set+=

These are equivalent:

```
vim.opt.formatoptions:append('j')
vim.opt.formatoptions = vim.opt.formatoptions + 'j'
```

Parameters:

`{value}` (`string`) Value to append

Option:get() `vim.opt:get())` Returns a Lua-representation of the option. Boolean, number and string values will be returned in exactly the same fashion.

For values that are comma-separated lists, an array will be returned with the values as entries in the array:

```
vim.cmd [[set wildignore=*.pyc,*.o]]
vim.print(vim.opt.wildignore:get())
-- { "*.pyc", "*.o", }
for _, ignore_pattern in ipairs(vim.opt.wildignore:get()) do
    print("Will ignore:", ignore_pattern)
end
-- Will ignore: *.pyc
-- Will ignore: *.o
```

For values that are comma-separated maps, a table will be returned with the names as keys and the values as entries:

```
vim.cmd [[set listchars=space:_,tab:>~]]
vim.print(vim.opt.listchars:get())
--  { space = "_", tab = ">~", }
for char, representation in pairs(vim.opt.listchars:get()) do
    print(char, "=>", representation)
end
```

For values that are lists of flags, a set will be returned with the flags as keys and `true` as entries.

```
vim.cmd [[set formatoptions=njtcroql]]
vim.print(vim.opt.formatoptions:get())
-- { n = true, j = true, c = true, ... }
local format_opts = vim.opt.formatoptions:get()
if format_opts.j then
    print("J is enabled!")
end
```

Return:

(`string|integer|boolean?`) value of option

Option:prepend(`{value}`) `vim.opt:prepend())` Prepend a value to string-style options. See :set^=

These are equivalent:

```
vim.opt.wildignore:prepend('*.o')
vim.opt.wildignore = vim.opt.wildignore ^ '*.o'
```

Parameters:

`{value}` (`string`) Value to prepend

Option:remove(`{value}`) `vim.opt:remove())` Remove a value from string-style options. See :set-=

These are equivalent:

```
vim.opt.wildignore:remove('*.pyc')
vim.opt.wildignore = vim.opt.wildignore - '*.pyc'
```

Parameters:

`{value}` (`string`) Value to remove

vim.bo\[`{bufnr}`\] `vim.bo` Get or set buffer-scoped options for the buffer with number `{bufnr}`. If `{bufnr}` is omitted then the current buffer is used. Invalid `{bufnr}` or key is an error.

**Note:** this is equivalent to `:setlocal` for global-local options and `:set` otherwise.

Example:

```
local bufnr = vim.api.nvim_get_current_buf()
vim.bo[bufnr].buflisted = true    -- same as vim.bo.buflisted = true
print(vim.bo.comments)
print(vim.bo.baz)                 -- error: invalid key
```

vim.env `vim.env` Environment variables defined in the editor session. See expand-env and :let-environment for the Vimscript behavior. Invalid or unset key returns `nil`.

Example:

```
vim.env.FOO = 'bar'
print(vim.env.TERM)
```

vim.go `vim.go` Get or set global options. Like `:setglobal`. Invalid key is an error.

**Note:** this is different from vim.o because this accesses the global option value and thus is mostly useful for use with global-local options.

Example:

```
vim.go.cmdheight = 4
print(vim.go.columns)
print(vim.go.bar)     -- error: invalid key
```

vim.o `vim.o` Get or set options. Like `:set`. Invalid key is an error.

**Note:** this works on both buffer-scoped and window-scoped options using the current buffer and window.

Example:

```
vim.o.cmdheight = 4
print(vim.o.columns)
print(vim.o.foo)     -- error: invalid key
```

vim.wo\[`{winid}`\]\[`{bufnr}`\] `vim.wo` Get or set window-scoped options for the window with handle `{winid}` and buffer with number `{bufnr}`. Like `:setlocal` if setting a global-local option or if `{bufnr}` is provided, like `:set` otherwise. If `{winid}` is omitted then the current window is used. Invalid `{winid}`, `{bufnr}` or key is an error.

**Note:** only `{bufnr}` with value `0` (the current buffer in the window) is supported.

Example:

```
local winid = vim.api.nvim_get_current_win()
vim.wo[winid].number = true    -- same as vim.wo.number = true
print(vim.wo.foldmarker)
print(vim.wo.quux)             -- error: invalid key
vim.wo[winid][0].spell = false -- like ':setlocal nospell'
```

Lua module: vim lua-vim
-----------------------------------

vim.cmd(`{command}`) `vim.cmd())` Executes Vim script commands.

Note that `vim.cmd` can be indexed with a command name to return a callable function to the command.

Example:

```
vim.cmd('echo 42')
vim.cmd([[
  augroup My_group
    autocmd!
    autocmd FileType c setlocal cindent
  augroup END
]])
-- Ex command :echo "foo"
-- Note string literals need to be double quoted.
vim.cmd('echo "foo"')
vim.cmd { cmd = 'echo', args = { '"foo"' } }
vim.cmd.echo({ args = { '"foo"' } })
vim.cmd.echo('"foo"')
-- Ex command :write! myfile.txt
vim.cmd('write! myfile.txt')
vim.cmd { cmd = 'write', args = { "myfile.txt" }, bang = true }
vim.cmd.write { args = { "myfile.txt" }, bang = true }
vim.cmd.write { "myfile.txt", bang = true }
-- Ex command :colorscheme blue
vim.cmd('colorscheme blue')
vim.cmd.colorscheme('blue')
```

Parameters:

`{command}` (`string|table`) Command(s) to execute. If a string, executes multiple lines of Vim script at once. In this case, it is an alias to nvim\_exec2()), where `opts.output` is set to false. Thus it works identical to :source. If a table, executes a single command. In this case, it is an alias to nvim\_cmd()) where `opts` is empty.

vim.defer\_fn(`{fn}`, `{timeout}`) `vim.defer_fn())` Defers calling `{fn}` until `{timeout}` ms passes.

Use to do a one-shot timer that calls `{fn}` **Note:** The `{fn}` is vim.schedule\_wrap())ped automatically, so API functions are safe to call.

Parameters:

`{fn}` (`function`) Callback to call once `timeout` expires

`{timeout}` (`integer`) Number of milliseconds to wait before calling `fn`

Return:

(`table`) timer luv timer object

`vim.deprecate())` vim.deprecate(`{name}`, `{alternative}`, `{version}`, `{plugin}`, `{backtrace}`) Shows a deprecation message to the user.

Parameters:

`{name}` (`string`) **Deprecated** feature (function, API, etc.).

`{alternative}` (`string?`) Suggested alternative feature.

`{version}` (`string`) Version when the deprecated function will be removed.

`{plugin}` (`string?`) Name of the plugin that owns the deprecated feature. Defaults to "Nvim".

`{backtrace}` (`boolean?`) Prints backtrace. Defaults to true.

Return:

(`string?`) **Deprecated** message, or nil if no message was shown.

vim.inspect() `vim.inspect())` Gets a human-readable representation of the given object.

vim.keycode(`{str}`) `vim.keycode())` Translates keycodes.

Example:

```
local k = vim.keycode
vim.g.mapleader = k'<bs>'
```

Parameters:

`{str}` (`string`) String to be converted.

vim.lua\_omnifunc(`{find_start}`) `vim.lua_omnifunc())` Omnifunc for completing Lua values from the runtime Lua interpreter, similar to the builtin completion for the `:lua` command.

Activate using `set omnifunc=v:lua.vim.lua_omnifunc` in a Lua buffer.

Parameters:

`{find_start}` (`1|0`)

vim.notify(`{msg}`, `{level}`, `{opts}`) `vim.notify())` Displays a notification to the user.

This function can be overridden by plugins to display notifications using a custom provider (such as the system notification provider). By default, writes to :messages.

Parameters:

`{msg}` (`string`) Content of the notification to show to the user.

`{level}` (`integer?`) One of the values from vim.log.levels.

`{opts}` (`table?`) Optional parameters. Unused by default.

vim.notify\_once(`{msg}`, `{level}`, `{opts}`) `vim.notify_once())` Displays a notification only one time.

Like vim.notify()), but subsequent calls with the same message will not display a notification.

Parameters:

`{msg}` (`string`) Content of the notification to show to the user.

`{level}` (`integer?`) One of the values from vim.log.levels.

`{opts}` (`table?`) Optional parameters. Unused by default.

Return:

(`boolean`) true if message was displayed, else false

vim.on\_key(`{fn}`, `{ns_id}`) `vim.on_key())` Adds Lua function `{fn}` with namespace id `{ns_id}` as a listener to every, yes every, input key.

The Nvim command-line option \-w is related but does not support callbacks and cannot be toggled dynamically.

**Note:**

`{fn}` will be removed on error.

Parameters:

`{fn}` (`fun(key: string, typed: string)?`) Function invoked on every key press. i\_CTRL-V `{key}` is the key after mappings have been applied, and `{typed}` is the key(s) before mappings are applied, which may be empty if `{key}` is produced by non-typed keys. When `{fn}` is nil and `{ns_id}` is specified, the callback associated with namespace `{ns_id}` is removed.

`{ns_id}` (`integer?`) Namespace ID. If nil or 0, generates and returns a new nvim\_create\_namespace()) id.

Return:

(`integer`) Namespace id associated with `{fn}`. Or count of all callbacks if on\_key() is called without arguments.

vim.paste(`{lines}`, `{phase}`) `vim.paste())` Paste handler, invoked by nvim\_paste()).

**Note:** This is provided only as a "hook", don't call it directly; call nvim\_paste()) instead, which arranges redo (dot-repeat) and invokes `vim.paste`.

Example: To remove ANSI color codes when pasting:

```
vim.paste = (function(overridden)
  return function(lines, phase)
    for i,line in ipairs(lines) do
      -- Scrub ANSI color codes from paste input.
      lines[i] = line:gsub('\27%[[0-9;mK]+', '')
    end
    overridden(lines, phase)
  end
end)(vim.paste)
```

Parameters:

`{phase}` (`-1|1|2|3`) -1: "non-streaming" paste: the call contains all lines. If paste is "streamed", `phase` indicates the stream state:

1: starts the paste (exactly once)

2: continues the paste (zero or more times)

3: ends the paste (exactly once)

Return:

(`boolean`) result false if client should cancel the paste.

vim.print(`{...}`) `vim.print())` "Pretty prints" the given arguments and returns them unmodified.

Example:

```
local hl_normal = vim.print(vim.api.nvim_get_hl(0, { name = 'Normal' }))
```

Return:

(`any`) given arguments.

vim.schedule\_wrap(`{fn}`) `vim.schedule_wrap())` Returns a function which calls `{fn}` via vim.schedule()).

The returned function passes all arguments to `{fn}`.

Example:

```
function notify_readable(_err, readable)
  vim.notify("readable? " .. tostring(readable))
end
vim.uv.fs_access(vim.fn.stdpath("config"), "R", vim.schedule_wrap(notify_readable))
```

Parameters:

`{fn}` (`function`)

vim.system(`{cmd}`, `{opts}`, `{on_exit}`) `vim.system())` Runs a system command or throws an error if `{cmd}` cannot be run.

Examples:

```
local on_exit = function(obj)
  print(obj.code)
  print(obj.signal)
  print(obj.stdout)
  print(obj.stderr)
end
-- Runs asynchronously:
vim.system({'echo', 'hello'}, { text = true }, on_exit)
-- Runs synchronously:
local obj = vim.system({'echo', 'hello'}, { text = true }):wait()
-- { code = 0, signal = 0, stdout = 'hello', stderr = '' }
```

See uv.spawn()) for more details. **Note:** unlike uv.spawn()), vim.system throws an error if `{cmd}` cannot be run.

Parameters:

`{cmd}` (`string[]`) Command to execute

`{opts}` (`vim.SystemOpts?`) Options:

cwd: (string) Set the current working directory for the sub-process.

env: table<string,string> Set environment variables for the new process. Inherits the current environment with `NVIM` set to v:servername.

clear\_env: (boolean) `env` defines the job environment exactly, instead of merging current environment.

stdin: (string|string\[\]|boolean) If `true`, then a pipe to stdin is opened and can be written to via the `write()` method to SystemObj. If string or string\[\] then will be written to stdin and closed. Defaults to `false`.

stdout: (boolean|function) Handle output from stdout. When passed as a function must have the signature `fun(err: string, data: string)`. Defaults to `true`

stderr: (boolean|function) Handle output from stderr. When passed as a function must have the signature `fun(err: string, data: string)`. Defaults to `true`.

text: (boolean) Handle stdout and stderr as text. Replaces `\r\n` with `\n`.

timeout: (integer) Run the command with a time limit. Upon timeout the process is sent the TERM signal (15) and the exit code is set to 124.

detach: (boolean) If true, spawn the child process in a detached state - this will make it a process group leader, and will effectively enable the child to keep running after the parent exits. Note that the child process will still keep the parent's event loop alive unless the parent process calls uv.unref()) on the child's process handle.

`{on_exit}` (`fun(out: vim.SystemCompleted)?`) Called when subprocess exits. When provided, the command runs asynchronously. Receives SystemCompleted object, see return of SystemObj:wait().

Return:

(`vim.SystemObj`) Object with the fields:

cmd (string\[\]) Command name and args

pid (integer) Process ID

wait (fun(timeout: integer|nil): SystemCompleted) Wait for the process to complete. Upon timeout the process is sent the KILL signal (9) and the exit code is set to 124. Cannot be called in api-fast.

SystemCompleted is an object with the fields:

code: (integer)

signal: (integer)

stdout: (string), nil if stdout argument is passed

stderr: (string), nil if stderr argument is passed

kill (fun(signal: integer|string))

write (fun(data: string|nil)) Requires `stdin=true`. Pass `nil` to close the stream.

is\_closing (fun(): boolean)

Lua module: vim.inspector vim.inspector
---------------------------------------------------------

vim.inspect\_pos(`{bufnr}`, `{row}`, `{col}`, `{filter}`) `vim.inspect_pos())` Get all the items at a given buffer position.

Can also be pretty-printed with `:Inspect!`. `:Inspect!`

Parameters:

`{bufnr}` (`integer?`) defaults to the current buffer

`{row}` (`integer?`) row to inspect, 0-based. Defaults to the row of the current cursor

`{col}` (`integer?`) col to inspect, 0-based. Defaults to the col of the current cursor

`{filter}` (`table?`) Table with key-value pairs to filter the items

`{syntax}` (`boolean`, default: `true`) Include syntax based highlight groups.

`{treesitter}` (`boolean`, default: `true`) Include treesitter based highlight groups.

`{extmarks}` (`boolean|"all"`, default: true) Include extmarks. When `all`, then extmarks without a `hl_group` will also be included.

`{semantic_tokens}` (`boolean`, default: true) Include semantic token highlights.

Return:

(`table`) a table with the following key-value pairs. Items are in "traversal order":

treesitter: a list of treesitter captures

syntax: a list of syntax groups

semantic\_tokens: a list of semantic tokens

extmarks: a list of extmarks

buffer: the buffer used to get the items

row: the row used to get the items

col: the col used to get the items

vim.show\_pos(`{bufnr}`, `{row}`, `{col}`, `{filter}`) `vim.show_pos())` Show all the items at a given buffer position.

Can also be shown with `:Inspect`. `:Inspect`

Parameters:

`{bufnr}` (`integer?`) defaults to the current buffer

`{row}` (`integer?`) row to inspect, 0-based. Defaults to the row of the current cursor

`{col}` (`integer?`) col to inspect, 0-based. Defaults to the col of the current cursor

`{filter}` (`table?`) A table with the following fields:

`{syntax}` (`boolean`, default: `true`) Include syntax based highlight groups.

`{treesitter}` (`boolean`, default: `true`) Include treesitter based highlight groups.

`{extmarks}` (`boolean|"all"`, default: true) Include extmarks. When `all`, then extmarks without a `hl_group` will also be included.

`{semantic_tokens}` (`boolean`, default: true) Include semantic token highlights.

Fields:

`{clear}` (`fun()`) Clear all items

`{push}` (`fun(item: T)`) Adds an item, overriding the oldest item if the buffer is full.

`{pop}` (`fun(): T?`) Removes and returns the first unread item

`{peek}` (`fun(): T?`) Returns the first unread item without removing it

Ringbuf:clear() `Ringbuf:clear())` Clear all items

Ringbuf:peek() `Ringbuf:peek())` Returns the first unread item without removing it

Ringbuf:pop() `Ringbuf:pop())` Removes and returns the first unread item

Ringbuf:push(`{item}`) `Ringbuf:push())` Adds an item, overriding the oldest item if the buffer is full.

vim.deep\_equal(`{a}`, `{b}`) `vim.deep_equal())` Deep compare values for equality

Tables are compared recursively unless they both provide the `eq` metamethod. All other types are compared using the equality `==` operator.

Parameters:

`{a}` (`any`) First value

`{b}` (`any`) Second value

Return:

(`boolean`) `true` if values are equals, else `false`

vim.deepcopy(`{orig}`, `{noref}`) `vim.deepcopy())` Returns a deep copy of the given object. Non-table objects are copied as in a typical Lua assignment, whereas table objects are copied recursively. Functions are naively copied, so functions in the copied table point to the same functions as those in the input table. Userdata and threads are not copied and will throw an error.

**Note:** `noref=true` is much more performant on tables with unique table fields, while `noref=false` is more performant on tables that reuse table fields.

Parameters:

`{orig}` (`table`) Table to copy

`{noref}` (`boolean?`) When `false` (default) a contained table is only copied once and all references point to this single copy. When `true` every occurrence of a table results in a new copy. This also means that a cyclic reference can cause `deepcopy()` to fail.

Return:

(`table`) Table of copied keys and (nested) values.

vim.defaulttable(`{createfn}`) `vim.defaulttable())` Creates a table whose missing keys are provided by `{createfn}` (like Python's "defaultdict").

If `{createfn}` is `nil` it defaults to defaulttable() itself, so accessing nested keys creates nested tables:

```
local a = vim.defaulttable()
a.b.c = 1
```

Parameters:

`{createfn}` (`fun(key:any):any?`) Provides the value for a missing `key`.

Return:

(`table`) Empty table with `__index` metamethod.

vim.endswith(`{s}`, `{suffix}`) `vim.endswith())` Tests if `s` ends with `suffix`.

Parameters:

`{s}` (`string`) String

`{suffix}` (`string`) Suffix to match

Return:

(`boolean`) `true` if `suffix` is a suffix of `s`

vim.gsplit(`{s}`, `{sep}`, `{opts}`) `vim.gsplit())` Gets an iterator that splits a string at each instance of a separator, in "lazy" fashion (as opposed to vim.split()) which is "eager").

Example:

```
for s in vim.gsplit(':aa::b:', ':', {plain=true}) do
  print(s)
end
```

If you want to also inspect the separator itself (instead of discarding it), use string.gmatch()). Example:

```
for word, num in ('foo111bar222'):gmatch('([^0-9]*)(%d*)') do
  print(('word: %s num: %s'):format(word, num))
end
```

Parameters:

`{s}` (`string`) String to split

`{sep}` (`string`) Separator or pattern

`{opts}` (`table?`) Keyword arguments kwargs:

`{plain}` (`boolean`) Use `sep` literally (as in string.find).

`{trimempty}` (`boolean`) Discard empty segments at start and end of the sequence.

Return:

(`fun():string?`) Iterator over the split components

vim.is\_callable(`{f}`) `vim.is_callable())` Returns true if object `f` can be called as a function.

Parameters:

`{f}` (`any`) Any object

Return:

(`boolean`) `true` if `f` is callable, else `false`

vim.isarray(`{t}`) `vim.isarray())` Tests if `t` is an "array": a table indexed only by integers (potentially non-contiguous).

If the indexes start from 1 and are contiguous then the array is also a list. vim.islist())

Empty table `{}` is an array, unless it was created by vim.empty\_dict()) or returned as a dict-like API or Vimscript result, for example from rpcrequest()) or vim.fn.

Return:

(`boolean`) `true` if array-like table, else `false`.

vim.islist(`{t}`) `vim.islist())` Tests if `t` is a "list": a table indexed only by contiguous integers starting from 1 (what lua-length calls a "regular array").

Empty table `{}` is a list, unless it was created by vim.empty\_dict()) or returned as a dict-like API or Vimscript result, for example from rpcrequest()) or vim.fn.

Return:

(`boolean`) `true` if list-like table, else `false`.

vim.list\_contains(`{t}`, `{value}`) `vim.list_contains())` Checks if a list-like table (integer keys without gaps) contains `value`.

Parameters:

`{t}` (`table`) Table to check (must be list-like, not validated)

`{value}` (`any`) Value to compare

Return:

(`boolean`) `true` if `t` contains `value`

vim.list\_extend(`{dst}`, `{src}`, `{start}`, `{finish}`) `vim.list_extend())` Extends a list-like table with the values of another list-like table.

**NOTE:** This mutates dst!

Parameters:

`{dst}` (`table`) List which will be modified and appended to

`{src}` (`table`) List from which values will be inserted

`{start}` (`integer?`) Start index on src. Defaults to 1

`{finish}` (`integer?`) Final index on src. Defaults to `#src`

vim.list\_slice(`{list}`, `{start}`, `{finish}`) `vim.list_slice())` Creates a copy of a table containing only elements from start to end (inclusive)

Parameters:

`{list}` (`any[]`) Table

`{start}` (`integer?`) Start range of slice

`{finish}` (`integer?`) End range of slice

Return:

(`any[]`) Copy of table sliced from start to finish (inclusive)

vim.pesc(`{s}`) `vim.pesc())` Escapes magic chars in lua-patterns.

Parameters:

`{s}` (`string`) String to escape

Return:

(`string`) %-escaped pattern string

vim.ringbuf(`{size}`) `vim.ringbuf())` Create a ring buffer limited to a maximal number of items. Once the buffer is full, adding a new entry overrides the oldest entry.

```
local ringbuf = vim.ringbuf(4)
ringbuf:push("a")
ringbuf:push("b")
ringbuf:push("c")
ringbuf:push("d")
ringbuf:push("e")    -- overrides "a"
print(ringbuf:pop()) -- returns "b"
print(ringbuf:pop()) -- returns "c"
-- Can be used as iterator. Pops remaining items:
for val in ringbuf do
  print(val)
end
```

Returns a Ringbuf instance with the following methods:

Parameters:

`{size}` (`integer`)

vim.spairs(`{t}`) `vim.spairs())` Enumerates key-value pairs of a table, ordered by key.

Parameters:

`{t}` (`table`) Dict-like table

Return (multiple):

(`fun(table: table<K, V>, index?: K):K, V`) for-in iterator over sorted keys and their values (`table`)

vim.split(`{s}`, `{sep}`, `{opts}`) `vim.split())` Splits a string at each instance of a separator and returns the result as a table (unlike vim.gsplit())).

Examples:

```
split(":aa::b:", ":")                   --> {'','aa','','b',''}
split("axaby", "ab?")                   --> {'','x','y'}
split("x*yz*o", "*", {plain=true})      --> {'x','yz','o'}
split("|x|y|z|", "|", {trimempty=true}) --> {'x', 'y', 'z'}
```

Parameters:

`{s}` (`string`) String to split

`{sep}` (`string`) Separator or pattern

`{opts}` (`table?`) Keyword arguments kwargs:

`{plain}` (`boolean`) Use `sep` literally (as in string.find).

`{trimempty}` (`boolean`) Discard empty segments at start and end of the sequence.

Return:

(`string[]`) List of split components

vim.startswith(`{s}`, `{prefix}`) `vim.startswith())` Tests if `s` starts with `prefix`.

Parameters:

`{s}` (`string`) String

`{prefix}` (`string`) Prefix to match

Return:

(`boolean`) `true` if `prefix` is a prefix of `s`

vim.tbl\_contains(`{t}`, `{value}`, `{opts}`) `vim.tbl_contains())` Checks if a table contains a given value, specified either directly or via a predicate that is checked for each value.

Example:

```
vim.tbl_contains({ 'a', { 'b', 'c' } }, function(v)
  return vim.deep_equal(v, { 'b', 'c' })
end, { predicate = true })
-- true
```

Parameters:

`{t}` (`table`) Table to check

`{value}` (`any`) Value to compare or predicate function reference

`{opts}` (`table?`) Keyword arguments kwargs:

`{predicate}` (`boolean`) `value` is a function reference to be checked (default false)

Return:

(`boolean`) `true` if `t` contains `value`

vim.tbl\_count(`{t}`) `vim.tbl_count())` Counts the number of non-nil values in table `t`.

```
vim.tbl_count({ a=1, b=2 })  --> 2
vim.tbl_count({ 1, 2 })      --> 2
```

Parameters:

`{t}` (`table`) Table

Return:

(`integer`) Number of non-nil values in table

vim.tbl\_deep\_extend(`{behavior}`, `{...}`) `vim.tbl_deep_extend())` Merges recursively two or more tables.

Only values that are empty tables or tables that are not lua-lists (indexed by consecutive integers starting from 1) are merged recursively. This is useful for merging nested tables like default and user configurations where lists should be treated as literals (i.e., are overwritten instead of merged).

Parameters:

`{behavior}` (`'error'|'keep'|'force'`) Decides what to do if a key is found in more than one map:

"error": raise an error

"keep": use value from the leftmost map

"force": use value from the rightmost map

`{...}` (`table`) Two or more tables

Return:

(`table`) Merged table

vim.tbl\_extend(`{behavior}`, `{...}`) `vim.tbl_extend())` Merges two or more tables.

Parameters:

`{behavior}` (`'error'|'keep'|'force'`) Decides what to do if a key is found in more than one map:

"error": raise an error

"keep": use value from the leftmost map

"force": use value from the rightmost map

`{...}` (`table`) Two or more tables

Return:

(`table`) Merged table

vim.tbl\_filter(`{func}`, `{t}`) `vim.tbl_filter())` Filter a table using a predicate function

Parameters:

`{func}` (`function`) Function

`{t}` (`table`) Table

Return:

(`any[]`) Table of filtered values

vim.tbl\_get(`{o}`, `{...}`) `vim.tbl_get())` Index into a table (first argument) via string keys passed as subsequent arguments. Return `nil` if the key does not exist.

Examples:

```
vim.tbl_get({ key = { nested_key = true }}, 'key', 'nested_key') == true
vim.tbl_get({ key = {}}, 'key', 'nested_key') == nil
```

Parameters:

`{o}` (`table`) Table to index

`{...}` (`any`) Optional keys (0 or more, variadic) via which to index the table

Return:

(`any`) Nested value indexed by key (if it exists), else nil

vim.tbl\_isempty(`{t}`) `vim.tbl_isempty())` Checks if a table is empty.

Parameters:

`{t}` (`table`) Table to check

Return:

(`boolean`) `true` if `t` is empty

vim.tbl\_keys(`{t}`) `vim.tbl_keys())` Return a list of all keys used in a table. However, the order of the return table of keys is not guaranteed.

Parameters:

`{t}` (`table`) Table

Return:

(`any[]`) List of keys

vim.tbl\_map(`{func}`, `{t}`) `vim.tbl_map())` Apply a function to all values of a table.

Parameters:

`{func}` (`fun(value: T): any`) Function

`{t}` (`table<any, T>`) Table

Return:

(`table`) Table of transformed values

vim.tbl\_values(`{t}`) `vim.tbl_values())` Return a list of all values used in a table. However, the order of the return table of values is not guaranteed.

Parameters:

`{t}` (`table`) Table

Return:

(`any[]`) List of values

vim.trim(`{s}`) `vim.trim())` Trim whitespace (Lua pattern "%s") from both sides of a string.

Parameters:

`{s}` (`string`) String to trim

Return:

(`string`) String with whitespace removed from its beginning and end

vim.validate(`{opt}`) `vim.validate())` Validate function arguments.

This function has two valid forms: 1. vim.validate(name: str, value: any, type: string, optional?: bool) 2. vim.validate(spec: table)

Form 1 validates that argument `{name}` with value `{value}` has the type `{type}`. `{type}` must be a value returned by lua-type()). If `{optional}` is true, then `{value}` may be null. This form is significantly faster and should be preferred for simple cases.

Example:

```
function vim.startswith(s, prefix)
  vim.validate('s', s, 'string')
  vim.validate('prefix', prefix, 'string')
  ...
end
```

Form 2 validates a parameter specification (types and values). Specs are evaluated in alphanumeric order, until the first failure.

Usage example:

```
function user.new(name, age, hobbies)
  vim.validate{
    name={name, 'string'},
    age={age, 'number'},
    hobbies={hobbies, 'table'},
  }
  ...
end
```

Examples with explicit argument values (can be run directly):

```
vim.validate{arg1={{'foo'}, 'table'}, arg2={'foo', 'string'}}
   --> NOP (success)
vim.validate{arg1={1, 'table'}}
   --> error('arg1: expected table, got number')
vim.validate{arg1={3, function(a) return (a % 2) == 0 end, 'even number'}}
   --> error('arg1: expected even number, got 3')
```

If multiple types are valid they can be given as a list.

```
vim.validate{arg1={{'foo'}, {'table', 'string'}}, arg2={'foo', {'table', 'string'}}}
-- NOP (success)
vim.validate{arg1={1, {'string', 'table'}}}
-- error('arg1: expected string|table, got number')
```

Parameters:

`{opt}` (`table`) Names of parameters to validate. Each key is a parameter name; each value is a tuple in one of these forms: 1. (arg\_value, type\_name, optional)

arg\_value: argument value

type\_name: string|table type name, one of: ("table", "t", "string", "s", "number", "n", "boolean", "b", "function", "f", "nil", "thread", "userdata") or list of them.

optional: (optional) boolean, if true, `nil` is valid 2. (arg\_value, fn, msg)

arg\_value: argument value

fn: any function accepting one argument, returns true if and only if the argument is valid. Can optionally return an additional informative error message as the second returned value.

msg: (optional) error string if validation fails

Lua module: vim.loader vim.loader
------------------------------------------------

vim.loader.disable() `vim.loader.disable())` Disables the experimental Lua module loader:

removes the loaders

adds the default Nvim loader

vim.loader.enable() `vim.loader.enable())` Enables the experimental Lua module loader:

overrides loadfile

adds the Lua loader using the byte-compilation cache

adds the libs loader

removes the default Nvim loader

vim.loader.find(`{modname}`, `{opts}`) `vim.loader.find())` Finds Lua modules for the given module name.

Parameters:

`{modname}` (`string`) Module name, or `"*"` to find the top-level modules instead

`{opts}` (`table?`) Options for finding a module:

`{rtp}` (`boolean`, default: `true`) Search for modname in the runtime path.

`{paths}` (`string[]`, default: `{}`) Extra paths to search for modname

`{patterns}` (`string[]`, default: `{"/init.lua", ".lua"}`) List of patterns to use when searching for modules. A pattern is a string added to the basename of the Lua module being searched.

`{all}` (`boolean`, default: `false`) Search for all matches.

Return:

(`table[]`) A list of objects with the following fields:

`{modpath}` (`string`) Path of the module

`{modname}` (`string`) Name of the module

`{stat}` (`uv.uv_fs_t`) The fs\_stat of the module path. Won't be returned for `modname="*"`

vim.loader.reset(`{path}`) `vim.loader.reset())` Resets the cache for the path, or all the paths if path is nil.

Parameters:

`{path}` (`string?`) path to reset

Lua module: vim.uri vim.uri
---------------------------------------

vim.uri\_decode(`{str}`) `vim.uri_decode())` URI-decodes a string containing percent escapes.

Parameters:

`{str}` (`string`) string to decode

Return:

(`string`) decoded string

vim.uri\_encode(`{str}`, `{rfc}`) `vim.uri_encode())` URI-encodes a string using percent escapes.

Parameters:

`{str}` (`string`) string to encode

`{rfc}` (`"rfc2396"|"rfc2732"|"rfc3986"?`)

Return:

(`string`) encoded string

vim.uri\_from\_bufnr(`{bufnr}`) `vim.uri_from_bufnr())` Gets a URI from a bufnr.

Parameters:

`{bufnr}` (`integer`)

vim.uri\_from\_fname(`{path}`) `vim.uri_from_fname())` Gets a URI from a file path.

Parameters:

`{path}` (`string`) Path to file

vim.uri\_to\_bufnr(`{uri}`) `vim.uri_to_bufnr())` Gets the buffer for a uri. Creates a new unloaded buffer if no buffer for the uri already exists.

Parameters:

`{uri}` (`string`)

vim.uri\_to\_fname(`{uri}`) `vim.uri_to_fname())` Gets a filename from a URI.

Parameters:

`{uri}` (`string`)

Return:

(`string`) filename or unchanged URI for non-file URIs

Lua module: vim.ui vim.ui
------------------------------------

vim.ui.input(`{opts}`, `{on_confirm}`) `vim.ui.input())` Prompts the user for input, allowing arbitrary (potentially asynchronous) work until `on_confirm`.

Example:

```
vim.ui.input({ prompt = 'Enter value for shiftwidth: ' }, function(input)
    vim.o.shiftwidth = tonumber(input)
end)
```

Parameters:

`{opts}` (`table?`) Additional options. See input())

prompt (string|nil) Text of the prompt

default (string|nil) Default reply to the input

completion (string|nil) Specifies type of completion supported for input. Supported types are the same that can be supplied to a user-defined command using the "-complete=" argument. See :command-completion

highlight (function) Function that will be used for highlighting user inputs.

`{on_confirm}` (`function`) ((input|nil) -> ()) Called once the user confirms or abort the input. `input` is what the user typed (it might be an empty string if nothing was entered), or `nil` if the user aborted the dialog.

vim.ui.open(`{path}`, `{opt}`) `vim.ui.open())` Opens `path` with the system default handler (macOS `open`, Windows `explorer.exe`, Linux `xdg-open`, …), or returns (but does not show) an error message on failure.

Expands "~/" and environment variables in filesystem paths.

Examples:

```
-- Asynchronous.
vim.ui.open("https://neovim.io/")
vim.ui.open("~/path/to/file")
-- Use the "osurl" command to handle the path or URL.
vim.ui.open("gh#neovim/neovim!29490", { cmd = { 'osurl' } })
-- Synchronous (wait until the process exits).
local cmd, err = vim.ui.open("$VIMRUNTIME")
if cmd then
  cmd:wait()
end
```

Parameters:

`{path}` (`string`) Path or URL to open

`{opt}` (`{ cmd?: string[] }?`) Options

cmd string\[\]|nil Command used to open the path or URL.

Return (multiple):

(`vim.SystemObj?`) Command object, or nil if not found. (`string?`) Error message on failure, or nil on success.

vim.ui.select(`{items}`, `{opts}`, `{on_choice}`) `vim.ui.select())` Prompts the user to pick from a list of items, allowing arbitrary (potentially asynchronous) work until `on_choice`.

Example:

```
vim.ui.select({ 'tabs', 'spaces' }, {
    prompt = 'Select tabs or spaces:',
    format_item = function(item)
        return "I'd like to choose " .. item
    end,
}, function(choice)
    if choice == 'spaces' then
        vim.o.expandtab = true
    else
        vim.o.expandtab = false
    end
end)
```

Parameters:

`{items}` (`any[]`) Arbitrary items

`{opts}` (`table`) Additional options

prompt (string|nil) Text of the prompt. Defaults to `Select one of:`

format\_item (function item -> text) Function to format an individual item from `items`. Defaults to `tostring`.

kind (string|nil) Arbitrary hint string indicating the item shape. Plugins reimplementing `vim.ui.select` may wish to use this to infer the structure or semantics of `items`, or the context in which select() was called.

`{on_choice}` (`fun(item: any?, idx: integer?)`) Called once the user made a choice. `idx` is the 1-based index of `item` within `items`. `nil` if the user aborted the dialog.

Lua module: vim.filetype vim.filetype
------------------------------------------------------

vim.filetype.add(`{filetypes}`) `vim.filetype.add())` Add new filetype mappings.

Filetype mappings can be added either by extension or by filename (either the "tail" or the full file path). The full file path is checked first, followed by the file name. If a match is not found using the filename, then the filename is matched against the list of lua-patterns (sorted by priority) until a match is found. Lastly, if pattern matching does not find a filetype, then the file extension is used.

The filetype can be either a string (in which case it is used as the filetype directly) or a function. If a function, it takes the full path and buffer number of the file as arguments (along with captures from the matched pattern, if any) and should return a string that will be used as the buffer's filetype. Optionally, the function can return a second function value which, when called, modifies the state of the buffer. This can be used to, for example, set filetype-specific buffer variables. This function will be called by Nvim before setting the buffer's filetype.

Filename patterns can specify an optional priority to resolve cases when a file path matches multiple patterns. Higher priorities are matched first. When omitted, the priority defaults to 0. A pattern can contain environment variables of the form "${SOME\_VAR}" that will be automatically expanded. If the environment variable is not set, the pattern won't be matched.

See $VIMRUNTIME/lua/vim/filetype.lua for more examples.

Example:

```
vim.filetype.add({
  extension = {
    foo = 'fooscript',
    bar = function(path, bufnr)
      if some_condition() then
        return 'barscript', function(bufnr)
          -- Set a buffer variable
          vim.b[bufnr].barscript_version = 2
        end
      end
      return 'bar'
    end,
  },
  filename = {
    ['.foorc'] = 'toml',
    ['/etc/foo/config'] = 'toml',
  },
  pattern = {
    ['.*/etc/foo/.*'] = 'fooscript',
    -- Using an optional priority
    ['.*/etc/foo/.*%.conf'] = { 'dosini', { priority = 10 } },
    -- A pattern containing an environment variable
    ['${XDG_CONFIG_HOME}/foo/git'] = 'git',
    ['.*README.(%a+)'] = function(path, bufnr, ext)
      if ext == 'md' then
        return 'markdown'
      elseif ext == 'rst' then
        return 'rst'
      end
    end,
  },
})
```

To add a fallback match on contents, use

```
vim.filetype.add {
  pattern = {
    ['.*'] = {
      function(path, bufnr)
        local content = vim.api.nvim_buf_get_lines(bufnr, 0, 1, false)[1] or ''
        if vim.regex([[^#!.*\\<mine\\>]]):match_str(content) ~= nil then
          return 'mine'
        elseif vim.regex([[\\<drawing\\>]]):match_str(content) ~= nil then
          return 'drawing'
        end
      end,
      { priority = -math.huge },
    },
  },
}
```

Parameters:

`{filetypes}` (`table`) A table containing new filetype maps (see example).

`{pattern}` (`vim.filetype.mapping`)

`{extension}` (`vim.filetype.mapping`)

`{filename}` (`vim.filetype.mapping`)

`vim.filetype.get_option())` vim.filetype.get\_option(`{filetype}`, `{option}`) Get the default option value for a `{filetype}`.

The returned value is what would be set in a new buffer after 'filetype' is set, meaning it should respect all FileType autocmds and ftplugin files.

Example:

```
vim.filetype.get_option('vim', 'commentstring')
```

**Note:** this uses nvim\_get\_option\_value()) but caches the result. This means ftplugin and FileType autocommands are only triggered once and may not reflect later changes.

Parameters:

`{filetype}` (`string`) Filetype

`{option}` (`string`) Option name

Return:

(`string|boolean|integer`) Option value

vim.filetype.match(`{args}`) `vim.filetype.match())` Perform filetype detection.

The filetype can be detected using one of three methods: 1. Using an existing buffer 2. Using only a file name 3. Using only file contents

Of these, option 1 provides the most accurate result as it uses both the buffer's filename and (optionally) the buffer contents. Options 2 and 3 can be used without an existing buffer, but may not always provide a match in cases where the filename (or contents) cannot unambiguously determine the filetype.

Each of the three options is specified using a key to the single argument of this function. Example:

```
-- Using a buffer number
vim.filetype.match({ buf = 42 })
-- Override the filename of the given buffer
vim.filetype.match({ buf = 42, filename = 'foo.c' })
-- Using a filename without a buffer
vim.filetype.match({ filename = 'main.lua' })
-- Using file contents
vim.filetype.match({ contents = {'#!/usr/bin/env bash'} })
```

Parameters:

`{args}` (`table`) Table specifying which matching strategy to use. Accepted keys are:

`{buf}` (`integer`) Buffer number to use for matching. Mutually exclusive with `{contents}`

`{filename}` (`string`) Filename to use for matching. When `{buf}` is given, defaults to the filename of the given buffer number. The file need not actually exist in the filesystem. When used without `{buf}` only the name of the file is used for filetype matching. This may result in failure to detect the filetype in cases where the filename alone is not enough to disambiguate the filetype.

`{contents}` (`string[]`) An array of lines representing file contents to use for matching. Can be used with `{filename}`. Mutually exclusive with `{buf}`.

Return (multiple):

(`string?`) If a match was found, the matched filetype. (`function?`) A function that modifies buffer state when called (for example, to set some filetype specific buffer variables). The function accepts a buffer number as its only argument.

Lua module: vim.keymap vim.keymap
------------------------------------------------

vim.keymap.del(`{modes}`, `{lhs}`, `{opts}`) `vim.keymap.del())` Remove an existing mapping. Examples:

```
vim.keymap.del('n', 'lhs')
vim.keymap.del({'n', 'i', 'v'}, '<leader>w', { buffer = 5 })
```

Parameters:

`{modes}` (`string|string[]`)

`{lhs}` (`string`)

`{opts}` (`table?`) A table with the following fields:

`{buffer}` (`integer|boolean`) Remove a mapping from the given buffer. When `0` or `true`, use the current buffer.

vim.keymap.set(`{mode}`, `{lhs}`, `{rhs}`, `{opts}`) `vim.keymap.set())` Defines a mapping of keycodes to a function or keycodes.

Examples:

```
-- Map "x" to a Lua function:
vim.keymap.set('n', 'x', function() print("real lua function") end)
-- Map "<leader>x" to multiple modes for the current buffer:
vim.keymap.set({'n', 'v'}, '<leader>x', vim.lsp.buf.references, { buffer = true })
-- Map <Tab> to an expression (|:map-<expr>|):
vim.keymap.set('i', '<Tab>', function()
  return vim.fn.pumvisible() == 1 and "<C-n>" or "<Tab>"
end, { expr = true })
-- Map "[%%" to a <Plug> mapping:
vim.keymap.set('n', '[%%', '<Plug>(MatchitNormalMultiBackward)')
```

Parameters:

`{mode}` (`string|string[]`) Mode "short-name" (see nvim\_set\_keymap())), or a list thereof.

`{lhs}` (`string`) Left-hand side {lhs} of the mapping.

`{rhs}` (`string|function`) Right-hand side {rhs} of the mapping, can be a Lua function.

`{replace_keycodes}` defaults to `true` if "expr" is `true`.

Also accepts:

`{buffer}` (`integer|boolean`) Creates buffer-local mapping, `0` or `true` for current buffer.

`{remap}` (`boolean`, default: `false`) Make the mapping recursive. Inverse of `{noremap}`.

Lua module: vim.fs vim.fs
------------------------------------

vim.fs.basename(`{file}`) `vim.fs.basename())` Return the basename of the given path

Parameters:

`{file}` (`string?`) Path

Return:

(`string?`) Basename of `{file}`

vim.fs.dir(`{path}`, `{opts}`) `vim.fs.dir())` Return an iterator over the items located in `{path}`

Parameters:

`{path}` (`string`) An absolute or relative path to the directory to iterate over. The path is first normalized vim.fs.normalize()).

`{opts}` (`table?`) Optional keyword arguments:

depth: integer|nil How deep the traverse (default 1)

skip: (fun(dir\_name: string): boolean)|nil Predicate to control traversal. Return false to stop searching the current directory. Only useful when depth > 1

Return:

(`Iterator`) over items in `{path}`. Each iteration yields two values: "name" and "type". "name" is the basename of the item relative to `{path}`. "type" is one of the following: "file", "directory", "link", "fifo", "socket", "char", "block", "unknown".

vim.fs.dirname(`{file}`) `vim.fs.dirname())` Return the parent directory of the given path

Parameters:

`{file}` (`string?`) Path

Return:

(`string?`) Parent directory of `{file}`

vim.fs.find(`{names}`, `{opts}`) `vim.fs.find())` Find files or directories (or other items as specified by `opts.type`) in the given path.

Finds items given in `{names}` starting from `{path}`. If `{upward}` is "true" then the search traverses upward through parent directories; otherwise, the search traverses downward. Note that downward searches are recursive and may search through many directories! If `{stop}` is non-nil, then the search stops when the directory given in `{stop}` is reached. The search terminates when `{limit}` (default 1) matches are found. You can set `{type}` to "file", "directory", "link", "socket", "char", "block", or "fifo" to narrow the search to find only that type.

Examples:

```
-- list all test directories under the runtime directory
local test_dirs = vim.fs.find(
  {'test', 'tst', 'testdir'},
  {limit = math.huge, type = 'directory', path = './runtime/'}
)
-- get all files ending with .cpp or .hpp inside lib/
local cpp_hpp = vim.fs.find(function(name, path)
  return name:match('.*%.[ch]pp

Parameters:

`{names}` (`string|string[]|fun(name: string, path: string): boolean`) Names of the items to find. Must be base names, paths and globs are not supported when `{names}` is a string or a table. If `{names}` is a function, it is called for each traversed item with args:

name: base name of the current item

path: full path of the current item The function should return `true` if the given item is considered a match.

`{opts}` (`table`) Optional keyword arguments:

`{path}` (`string`) Path to begin searching from. If omitted, the current-directory is used.

`{upward}` (`boolean`, default: `false`) Search upward through parent directories. Otherwise, search through child directories (recursively).

`{stop}` (`string`) Stop searching when this directory is reached. The directory itself is not searched.

`{type}` (`string`) Find only items of the given type. If omitted, all items that match `{names}` are included.

`{limit}` (`number`, default: `1`) Stop the search after finding this many matches. Use `math.huge` to place no limit on the number of matches.

vim.fs.joinpath(`{...}`) `vim.fs.joinpath())` Concatenate directories and/or file paths into a single path with normalization (e.g., `"foo/"` and `"bar"` get joined to `"foo/bar"`)

Parameters:

`{...}` (`string`)

vim.fs.normalize(`{path}`, `{opts}`) `vim.fs.normalize())` Normalize a path to a standard format. A tilde (~) character at the beginning of the path is expanded to the user's home directory and environment variables are also expanded. "." and ".." components are also resolved, except when the path is relative and trying to resolve it would result in an absolute path.

"." as the only part in a relative path:

"." => "."

"././" => "."

".." when it leads outside the current directory

"foo/../../bar" => "../bar"

"../../foo" => "../../foo"

".." in the root directory returns the root directory.

"/../../" => "/"

On Windows, backslash (\\) characters are converted to forward slashes (/).

Examples:

```

[[C:\Users\jdoe]]                         => "C:/Users/jdoe"
"~/src/neovim"                            => "/home/jdoe/src/neovim"
"$XDG_CONFIG_HOME/nvim/init.vim"          => "/Users/jdoe/.config/nvim/init.vim"
"~/src/nvim/api/../tui/./tui.c"           => "/home/jdoe/src/nvim/tui/tui.c"
"./foo/bar"                               => "foo/bar"
"foo/../../../bar"                        => "../../bar"
"/home/jdoe/../../../bar"                 => "/bar"
"C:foo/../../baz"                         => "C:../baz"
"C:/foo/../../baz"                        => "C:/baz"
[[\\?\UNC\server\share\foo\..\..\..\bar]] => "//?/UNC/server/share/bar"

```


Parameters:

`{path}` (`string`) Path to normalize

`{opts}` (`table?`) A table with the following fields:

`{expand_env}` (`boolean`, default: `true`) Expand environment variables.

`{win}` (`boolean`, default: `true` in Windows, `false` otherwise) Path is a Windows path.

Return:

(`string`) Normalized path

vim.fs.parents(`{start}`) `vim.fs.parents())` Iterate over all the parents of the given path.

Example:

```

local root_dir
for dir in vim.fs.parents(vim.api.nvim_buf_get_name(0)) do
  if vim.fn.isdirectory(dir .. "/.git") == 1 then
    root_dir = dir
    break
  end
end
if root_dir then
  print("Found git repository at", root_dir)
end

```


Parameters:

`{start}` (`string`) Initial path.

Return (multiple):

(`fun(_, dir: string): string?`) Iterator (`nil`) (`string?`)

vim.fs.rm(`{path}`, `{opts}`) `vim.fs.rm())` Remove files or directories

Parameters:

`{path}` (`string`) Path to remove

`{opts}` (`table?`) A table with the following fields:

`{recursive}` (`boolean`) Remove directories and their contents recursively

`{force}` (`boolean`) Ignore nonexistent files and arguments

vim.fs.root(`{source}`, `{marker}`) `vim.fs.root())` Find the first parent directory containing a specific "marker", relative to a file path or buffer.

If the buffer is unnamed (has no backing file) or has a non-empty 'buftype' then the search begins from Nvim's current-directory.

Example:

```

-- Find the root of a Python project, starting from file 'main.py'
vim.fs.root(vim.fs.joinpath(vim.env.PWD, 'main.py'), {'pyproject.toml', 'setup.py' })
-- Find the root of a git repository
vim.fs.root(0, '.git')
-- Find the parent directory containing any file with a .csproj extension
vim.fs.root(0, function(name, path)
  return name:match('%.csproj

Parameters:

`{source}` (`integer|string`) Buffer number (0 for current buffer) or file path (absolute or relative to the current-directory) to begin the search from.

`{marker}` (`string|string[]|fun(name: string, path: string): boolean`) A marker, or list of markers, to search for. If a function, the function is called for each evaluated item and should return true if `{name}` and `{path}` are a match.

Return:

(`string?`) Directory path containing one of the given markers, or nil if no directory was found.

Lua module: vim.glob vim.glob
------------------------------------------

vim.glob.to\_lpeg(`{pattern}`) `vim.glob.to_lpeg())` Parses a raw glob into an lua-lpeg pattern.

Glob patterns can have the following syntax:

`*` to match one or more characters in a path segment

`?` to match on one character in a path segment

`**` to match any number of path segments, including none

`{}` to group conditions (e.g. `*.{ts,js}` matches TypeScript and JavaScript files)

`[]` to declare a range of characters to match in a path segment (e.g., `example.[0-9]` to match on `example.0`, `example.1`, …)

`[!...]` to negate a range of characters to match in a path segment (e.g., `example.[!0-9]` to match on `example.a`, `example.b`, but not `example.0`)

Parameters:

`{pattern}` (`string`) The raw glob pattern

Return:

(`vim.lpeg.Pattern`) pattern An lua-lpeg representation of the pattern

VIM.LPEG vim.lpeg
------------------------------

LPeg is a pattern-matching library for Lua, based on Parsing Expression Grammars (PEGs). <https://bford.info/packrat/>

Pattern:match(`{subject}`, `{init}`, `{...}`) `Pattern:match())` Matches the given `pattern` against the `subject` string. If the match succeeds, returns the index in the subject of the first character after the match, or the captured values (if the pattern captured any value). An optional numeric argument `init` makes the match start at that position in the subject string. As usual in Lua libraries, a negative value counts from the end. Unlike typical pattern-matching functions, `match` works only in anchored mode; that is, it tries to match the pattern with a prefix of the given subject string (at position `init`), not with an arbitrary substring of the subject. So, if we want to find a pattern anywhere in a string, we must either write a loop in Lua or write a pattern that matches anywhere.

Example:

```
local pattern = lpeg.R('az') ^ 1 * -1
assert(pattern:match('hello') == 6)
assert(lpeg.match(pattern, 'hello') == 6)
assert(pattern:match('1 hello') == nil)
```

Parameters:

`{subject}` (`string`)

`{init}` (`integer?`)

`{...}` (`any`)

vim.lpeg.B(`{pattern}`) `vim.lpeg.B())` Returns a pattern that matches only if the input string at the current position is preceded by `patt`. Pattern `patt` must match only strings with some fixed length, and it cannot contain captures. Like the `and` predicate, this pattern never consumes any input, independently of success or failure.

Parameters:

`{pattern}` (`vim.lpeg.Pattern|string|integer|boolean|table`)

Return:

(`vim.lpeg.Pattern`)

vim.lpeg.C(`{patt}`) `vim.lpeg.C())` Creates a simple capture, which captures the substring of the subject that matches `patt`. The captured value is a string. If `patt` has other captures, their values are returned after this one.

Example:

```
local function split (s, sep)
  sep = lpeg.P(sep)
  local elem = lpeg.C((1 - sep) ^ 0)
  local p = elem * (sep * elem) ^ 0
  return lpeg.match(p, s)
end
local a, b, c = split('a,b,c', ',')
assert(a == 'a')
assert(b == 'b')
assert(c == 'c')
```

Parameters:

`{patt}` (`vim.lpeg.Pattern|string|integer|boolean|table|function`)

Return:

(`vim.lpeg.Capture`)

vim.lpeg.Carg(`{n}`) `vim.lpeg.Carg())` Creates an argument capture. This pattern matches the empty string and produces the value given as the nth extra argument given in the call to `lpeg.match`.

Parameters:

`{n}` (`integer`)

Return:

(`vim.lpeg.Capture`)

vim.lpeg.Cb(`{name}`) `vim.lpeg.Cb())` Creates a back capture. This pattern matches the empty string and produces the values produced by the most recent group capture named `name` (where `name` can be any Lua value). Most recent means the last complete outermost group capture with the given name. A Complete capture means that the entire pattern corresponding to the capture has matched. An Outermost capture means that the capture is not inside another complete capture. In the same way that LPeg does not specify when it evaluates captures, it does not specify whether it reuses values previously produced by the group or re-evaluates them.

Return:

(`vim.lpeg.Capture`)

vim.lpeg.Cc(`{...}`) `vim.lpeg.Cc())` Creates a constant capture. This pattern matches the empty string and produces all given values as its captured values.

Return:

(`vim.lpeg.Capture`)

vim.lpeg.Cf(`{patt}`, `{func}`) `vim.lpeg.Cf())` Creates a fold capture. If `patt` produces a list of captures C1 C2 ... Cn, this capture will produce the value `func(...func(func(C1, C2), C3)...,Cn)`, that is, it will fold (or accumulate, or reduce) the captures from `patt` using function `func`. This capture assumes that `patt` should produce at least one capture with at least one value (of any type), which becomes the initial value of an accumulator. (If you need a specific initial value, you may prefix a constant capture to `patt`.) For each subsequent capture, LPeg calls `func` with this accumulator as the first argument and all values produced by the capture as extra arguments; the first result from this call becomes the new value for the accumulator. The final value of the accumulator becomes the captured value.

Example:

```
local number = lpeg.R('09') ^ 1 / tonumber
local list = number * (',' * number) ^ 0
local function add(acc, newvalue) return acc + newvalue end
local sum = lpeg.Cf(list, add)
assert(sum:match('10,30,43') == 83)
```

Parameters:

`{patt}` (`vim.lpeg.Pattern|string|integer|boolean|table|function`)

`{func}` (`fun(acc, newvalue)`)

Return:

(`vim.lpeg.Capture`)

vim.lpeg.Cg(`{patt}`, `{name}`) `vim.lpeg.Cg())` Creates a group capture. It groups all values returned by `patt` into a single capture. The group may be anonymous (if no name is given) or named with the given name (which can be any non-nil Lua value).

Parameters:

`{patt}` (`vim.lpeg.Pattern|string|integer|boolean|table|function`)

`{name}` (`string?`)

Return:

(`vim.lpeg.Capture`)

vim.lpeg.Cmt(`{patt}`, `{fn}`) `vim.lpeg.Cmt())` Creates a match-time capture. Unlike all other captures, this one is evaluated immediately when a match occurs (even if it is part of a larger pattern that fails later). It forces the immediate evaluation of all its nested captures and then calls `function`. The given function gets as arguments the entire subject, the current position (after the match of `patt`), plus any capture values produced by `patt`. The first value returned by `function` defines how the match happens. If the call returns a number, the match succeeds and the returned number becomes the new current position. (Assuming a subject sand current position `i`, the returned number must be in the range `[i, len(s) + 1]`.) If the call returns `true`, the match succeeds without consuming any input (so, to return true is equivalent to return `i`). If the call returns `false`, `nil`, or no value, the match fails. Any extra values returned by the function become the values produced by the capture.

Parameters:

`{patt}` (`vim.lpeg.Pattern|string|integer|boolean|table|function`)

`{fn}` (`fun(s: string, i: integer, ...: any)`) (position: boolean|integer, ...: any)

Return:

(`vim.lpeg.Capture`)

vim.lpeg.Cp() `vim.lpeg.Cp())` Creates a position capture. It matches the empty string and captures the position in the subject where the match occurs. The captured value is a number.

Example:

```
local I = lpeg.Cp()
local function anywhere(p) return lpeg.P({I * p * I + 1 * lpeg.V(1)}) end
local match_start, match_end = anywhere('world'):match('hello world!')
assert(match_start == 7)
assert(match_end == 12)
```

Return:

(`vim.lpeg.Capture`)

vim.lpeg.Cs(`{patt}`) `vim.lpeg.Cs())` Creates a substitution capture. This function creates a substitution capture, which captures the substring of the subject that matches `patt`, with substitutions. For any capture inside `patt` with a value, the substring that matched the capture is replaced by the capture value (which should be a string). The final captured value is the string resulting from all replacements.

Example:

```
local function gsub (s, patt, repl)
  patt = lpeg.P(patt)
  patt = lpeg.Cs((patt / repl + 1) ^ 0)
  return lpeg.match(patt, s)
end
assert(gsub('Hello, xxx!', 'xxx', 'World') == 'Hello, World!')
```

Parameters:

`{patt}` (`vim.lpeg.Pattern|string|integer|boolean|table|function`)

Return:

(`vim.lpeg.Capture`)

vim.lpeg.Ct(`{patt}`) `vim.lpeg.Ct())` Creates a table capture. This capture returns a table with all values from all anonymous captures made by `patt` inside this table in successive integer keys, starting at 1. Moreover, for each named capture group created by `patt`, the first value of the group is put into the table with the group name as its key. The captured value is only the table.

Parameters:

`{patt}` (`vim.lpeg.Pattern|string|integer|boolean|table|function`)

Return:

(`vim.lpeg.Capture`)

vim.lpeg.locale(`{tab}`) `vim.lpeg.locale())` Returns a table with patterns for matching some character classes according to the current locale. The table has fields named `alnum`, `alpha`, `cntrl`, `digit`, `graph`, `lower`, `print`, `punct`, `space`, `upper`, and `xdigit`, each one containing a correspondent pattern. Each pattern matches any single character that belongs to its class. If called with an argument `table`, then it creates those fields inside the given table and returns that table.

Example:

```
lpeg.locale(lpeg)
local space = lpeg.space ^ 0
local name = lpeg.C(lpeg.alpha ^ 1) * space
local sep = lpeg.S(',;') * space
local pair = lpeg.Cg(name * '=' * space * name) * sep ^ -1
local list = lpeg.Cf(lpeg.Ct('') * pair ^ 0, rawset)
local t = list:match('a=b, c = hi; next = pi')
assert(t.a == 'b')
assert(t.c == 'hi')
assert(t.next == 'pi')
local locale = lpeg.locale()
assert(type(locale.digit) == 'userdata')
```

Parameters:

`{tab}` (`table?`)

Return:

(`vim.lpeg.Locale`)

vim.lpeg.match(`{pattern}`, `{subject}`, `{init}`, `{...}`) `vim.lpeg.match())` Matches the given `pattern` against the `subject` string. If the match succeeds, returns the index in the subject of the first character after the match, or the captured values (if the pattern captured any value). An optional numeric argument `init` makes the match start at that position in the subject string. As usual in Lua libraries, a negative value counts from the end. Unlike typical pattern-matching functions, `match` works only in anchored mode; that is, it tries to match the pattern with a prefix of the given subject string (at position `init`), not with an arbitrary substring of the subject. So, if we want to find a pattern anywhere in a string, we must either write a loop in Lua or write a pattern that matches anywhere.

Example:

```
local pattern = lpeg.R('az') ^ 1 * -1
assert(pattern:match('hello') == 6)
assert(lpeg.match(pattern, 'hello') == 6)
assert(pattern:match('1 hello') == nil)
```

Parameters:

`{pattern}` (`vim.lpeg.Pattern|string|integer|boolean|table|function`)

`{subject}` (`string`)

`{init}` (`integer?`)

`{...}` (`any`)

vim.lpeg.P(`{value}`) `vim.lpeg.P())` Converts the given value into a proper pattern. The following rules are applied:

If the argument is a pattern, it is returned unmodified.

If the argument is a string, it is translated to a pattern that matches the string literally.

If the argument is a non-negative number `n`, the result is a pattern that matches exactly `n` characters.

If the argument is a negative number `-n`, the result is a pattern that succeeds only if the input string has less than `n` characters left: `lpeg.P(-n)` is equivalent to `-lpeg.P(n)` (see the unary minus operation).

If the argument is a boolean, the result is a pattern that always succeeds or always fails (according to the boolean value), without consuming any input.

If the argument is a table, it is interpreted as a grammar (see Grammars).

If the argument is a function, returns a pattern equivalent to a match-time capture over the empty string.

Parameters:

`{value}` (`vim.lpeg.Pattern|string|integer|boolean|table|function`)

Return:

(`vim.lpeg.Pattern`)

vim.lpeg.R(`{...}`) `vim.lpeg.R())` Returns a pattern that matches any single character belonging to one of the given ranges. Each `range` is a string `xy` of length 2, representing all characters with code between the codes of `x` and `y` (both inclusive). As an example, the pattern `lpeg.R('09')` matches any digit, and `lpeg.R('az', 'AZ')` matches any ASCII letter.

Example:

```
local pattern = lpeg.R('az') ^ 1 * -1
assert(pattern:match('hello') == 6)
```

Parameters:

`{...}` (`string`)

Return:

(`vim.lpeg.Pattern`)

vim.lpeg.S(`{string}`) `vim.lpeg.S())` Returns a pattern that matches any single character that appears in the given string (the `S` stands for Set). As an example, the pattern `lpeg.S('+-*/')` matches any arithmetic operator. Note that, if `s` is a character (that is, a string of length 1), then `lpeg.P(s)` is equivalent to `lpeg.S(s)` which is equivalent to `lpeg.R(s..s)`. Note also that both `lpeg.S('')` and `lpeg.R()` are patterns that always fail.

Parameters:

`{string}` (`string`)

Return:

(`vim.lpeg.Pattern`)

vim.lpeg.setmaxstack(`{max}`) `vim.lpeg.setmaxstack())` Sets a limit for the size of the backtrack stack used by LPeg to track calls and choices. The default limit is `400`. Most well-written patterns need little backtrack levels and therefore you seldom need to change this limit; before changing it you should try to rewrite your pattern to avoid the need for extra space. Nevertheless, a few useful patterns may overflow. Also, with recursive grammars, subjects with deep recursion may also need larger limits.

Parameters:

`{max}` (`integer`)

vim.lpeg.type(`{value}`) `vim.lpeg.type())` Returns the string `"pattern"` if the given value is a pattern, otherwise `nil`.

Parameters:

`{value}` (`vim.lpeg.Pattern|string|integer|boolean|table|function`)

vim.lpeg.V(`{v}`) `vim.lpeg.V())` Creates a non-terminal (a variable) for a grammar. This operation creates a non-terminal (a variable) for a grammar. The created non-terminal refers to the rule indexed by `v` in the enclosing grammar.

Example:

```
local b = lpeg.P({'(' * ((1 - lpeg.S '()') + lpeg.V(1)) ^ 0 * ')'})
assert(b:match('((string))') == 11)
assert(b:match('(') == nil)
```

Parameters:

`{v}` (`boolean|string|number|function|table|thread|userdata|lightuserdata`)

Return:

(`vim.lpeg.Pattern`)

vim.lpeg.version() `vim.lpeg.version())` Returns a string with the running version of LPeg.

VIM.RE vim.re
------------------------

The `vim.re` module provides a conventional regex-like syntax for pattern usage within LPeg vim.lpeg. (Unrelated to vim.regex which provides Vim regexp from Lua.)

vim.re.compile(`{string}`, `{defs}`) `vim.re.compile())` Compiles the given `{string}` and returns an equivalent LPeg pattern. The given string may define either an expression or a grammar. The optional `{defs}` table provides extra Lua values to be used by the pattern.

Parameters:

`{string}` (`string`)

`{defs}` (`table?`)

Return:

(`vim.lpeg.Pattern`)

vim.re.find(`{subject}`, `{pattern}`, `{init}`) `vim.re.find())` Searches the given `{pattern}` in the given `{subject}`. If it finds a match, returns the index where this occurrence starts and the index where it ends. Otherwise, returns nil.

An optional numeric argument `{init}` makes the search starts at that position in the subject string. As usual in Lua libraries, a negative value counts from the end.

Parameters:

`{subject}` (`string`)

`{pattern}` (`vim.lpeg.Pattern|string`)

`{init}` (`integer?`)

Return (multiple):

(`integer?`) the index where the occurrence starts, nil if no match (`integer?`) the index where the occurrence ends, nil if no match

vim.re.gsub(`{subject}`, `{pattern}`, `{replacement}`) `vim.re.gsub())` Does a global substitution, replacing all occurrences of `{pattern}` in the given `{subject}` by `{replacement}`.

Parameters:

`{subject}` (`string`)

`{pattern}` (`vim.lpeg.Pattern|string`)

`{replacement}` (`string`)

vim.re.match(`{subject}`, `{pattern}`, `{init}`) `vim.re.match())` Matches the given `{pattern}` against the given `{subject}`, returning all captures.

Parameters:

`{subject}` (`string`)

`{pattern}` (`vim.lpeg.Pattern|string`)

`{init}` (`integer?`)

Return:

(`integer|vim.lpeg.Capture?`)

See also:

vim.lpeg.match()

vim.re.updatelocale() `vim.re.updatelocale())` Updates the pre-defined character classes to the current locale.

VIM.REGEX vim.regex
---------------------------------

Vim regexes can be used directly from Lua. Currently they only allow matching within a single line.

`regex:match_line())` regex:match\_line(`{bufnr}`, `{line_idx}`, `{start}`, `{end_}`) Match line `{line_idx}` (zero-based) in buffer `{bufnr}`. If `{start}` and `{end}` are supplied, match only this byte index range. Otherwise see regex:match\_str()). If `{start}` is used, then the returned byte indices will be relative `{start}`.

Parameters:

`{bufnr}` (`integer`)

`{line_idx}` (`integer`)

`{start}` (`integer?`)

`{end_}` (`integer?`)

regex:match\_str(`{str}`) `regex:match_str())` Match the string against the regex. If the string should match the regex precisely, surround the regex with `^` and `$`. If there was a match, the byte indices for the beginning and end of the match are returned. When there is no match, `nil` is returned. Because any integer is "truthy", `regex:match_str()` can be directly used as a condition in an if-statement.

Parameters:

`{str}` (`string`)

vim.regex(`{re}`) `vim.regex())` Parse the Vim regex `{re}` and return a regex object. Regexes are "magic" and case-sensitive by default, regardless of 'magic' and 'ignorecase'. They can be controlled with flags, see /magic and /ignorecase.

Parameters:

`{re}` (`string`)

Lua module: vim.secure vim.secure
------------------------------------------------

vim.secure.read(`{path}`) `vim.secure.read())` Attempt to read the file at `{path}` prompting the user if the file should be trusted. The user's choice is persisted in a trust database at $XDG\_STATE\_HOME/nvim/trust.

Parameters:

`{path}` (`string`) Path to a file to read.

Return:

(`string?`) The contents of the given file if it exists and is trusted, or nil otherwise.

vim.secure.trust(`{opts}`) `vim.secure.trust())` Manage the trust database.

Parameters:

`{opts}` (`table`) A table with the following fields:

`{action}` (`'allow'|'deny'|'remove'`) - `'allow'` to add a file to the trust database and trust it,

`'deny'` to add a file to the trust database and deny it,

`'remove'` to remove file from the trust database

`{path}` (`string`) Path to a file to update. Mutually exclusive with `{bufnr}`. Cannot be used when `{action}` is "allow".

`{bufnr}` (`integer`) Buffer number to update. Mutually exclusive with `{path}`.

Return (multiple):

(`boolean`) success true if operation was successful (`string`) msg full path if operation was successful, else error message

Lua module: vim.version vim.version
---------------------------------------------------

The `vim.version` module provides functions for comparing versions and ranges conforming to the <https://semver.org> spec. Plugins, and plugin managers, can use this to check available tools and dependencies on the current system.

Example:

```
local v = vim.version.parse(vim.fn.system({'tmux', '-V'}), {strict=false})
if vim.version.gt(v, {3, 2, 0}) then
  -- ...
end
```

`vim.version())` returns the version of the current Nvim process.

### VERSION RANGE SPEC version-range

A version "range spec" defines a semantic version range which can be tested against a version, using vim.version.range()).

Supported range specs are shown in the following table. **Note:** suffixed versions (1.2.3-rc1) are not matched.

```
1.2.3             is 1.2.3
=1.2.3            is 1.2.3
>1.2.3            greater than 1.2.3
<1.2.3            before 1.2.3
>=1.2.3           at least 1.2.3
~1.2.3            is >=1.2.3 <1.3.0       "reasonably close to 1.2.3"
^1.2.3            is >=1.2.3 <2.0.0       "compatible with 1.2.3"
^0.2.3            is >=0.2.3 <0.3.0       (0.x.x is special)
^0.0.1            is =0.0.1               (0.0.x is special)
^1.2              is >=1.2.0 <2.0.0       (like ^1.2.0)
~1.2              is >=1.2.0 <1.3.0       (like ~1.2.0)
^1                is >=1.0.0 <2.0.0       "compatible with 1"
~1                same                    "reasonably close to 1"
1.x               same
1.*               same
1                 same
*                 any version
x                 same
1.2.3 - 2.3.4     is >=1.2.3 <=2.3.4
Partial right: missing pieces treated as x (2.3 => 2.3.x).
1.2.3 - 2.3       is >=1.2.3 <2.4.0
1.2.3 - 2         is >=1.2.3 <3.0.0
Partial left: missing pieces treated as 0 (1.2 => 1.2.0).
1.2 - 2.3.0       is 1.2.0 - 2.3.0
```

vim.version.cmp(`{v1}`, `{v2}`) `vim.version.cmp())` Parses and compares two version objects (the result of vim.version.parse()), or specified literally as a `{major, minor, patch}` tuple, e.g. `{1, 0, 3}`).

Example:

```
if vim.version.cmp({1,0,3}, {0,2,1}) == 0 then
  -- ...
end
local v1 = vim.version.parse('1.0.3-pre')
local v2 = vim.version.parse('0.2.1')
if vim.version.cmp(v1, v2) == 0 then
  -- ...
end
```

**Note:**

Per semver, build metadata is ignored when comparing two otherwise-equivalent versions.

Parameters:

`{v1}` (`vim.Version|number[]|string`) Version object.

`{v2}` (`vim.Version|number[]|string`) Version to compare with `v1`.

Return:

(`integer`) -1 if `v1 < v2`, 0 if `v1 == v2`, 1 if `v1 > v2`.

vim.version.eq(`{v1}`, `{v2}`) `vim.version.eq())` Returns `true` if the given versions are equal. See vim.version.cmp()) for usage.

Parameters:

`{v1}` (`vim.Version|number[]|string`)

`{v2}` (`vim.Version|number[]|string`)

vim.version.ge(`{v1}`, `{v2}`) `vim.version.ge())` Returns `true` if `v1 >= v2`. See vim.version.cmp()) for usage.

Parameters:

`{v1}` (`vim.Version|number[]|string`)

`{v2}` (`vim.Version|number[]|string`)

vim.version.gt(`{v1}`, `{v2}`) `vim.version.gt())` Returns `true` if `v1 > v2`. See vim.version.cmp()) for usage.

Parameters:

`{v1}` (`vim.Version|number[]|string`)

`{v2}` (`vim.Version|number[]|string`)

vim.version.last(`{versions}`) `vim.version.last())` TODO: generalize this, move to func.lua

Parameters:

`{versions}` (`vim.Version[]`)

vim.version.le(`{v1}`, `{v2}`) `vim.version.le())` Returns `true` if `v1 <= v2`. See vim.version.cmp()) for usage.

Parameters:

`{v1}` (`vim.Version|number[]|string`)

`{v2}` (`vim.Version|number[]|string`)

vim.version.lt(`{v1}`, `{v2}`) `vim.version.lt())` Returns `true` if `v1 < v2`. See vim.version.cmp()) for usage.

Parameters:

`{v1}` (`vim.Version|number[]|string`)

`{v2}` (`vim.Version|number[]|string`)

vim.version.parse(`{version}`, `{opts}`) `vim.version.parse())` Parses a semantic version string and returns a version object which can be used with other `vim.version` functions. For example "1.0.1-rc1+build.2" returns:

```
{ major = 1, minor = 0, patch = 1, prerelease = "rc1", build = "build.2" }
```

Parameters:

`{version}` (`string`) Version string to parse.

`{opts}` (`table?`) Optional keyword arguments:

strict (boolean): Default false. If `true`, no coercion is attempted on input not conforming to semver v2.0.0. If `false`, `parse()` attempts to coerce input such as "1.0", "0-x", "tmux 3.2a" into valid versions.

Return:

(`vim.Version?`) parsed\_version Version object or `nil` if input is invalid.

vim.version.range(`{spec}`) `vim.version.range())` Parses a semver version-range "spec" and returns a range object:

```
{
  from: Version
  to: Version
  has(v: string|Version)
}
```

`:has()` checks if a version is in the range (inclusive `from`, exclusive `to`).

Example:

```
local r = vim.version.range('1.0.0 - 2.0.0')
print(r:has('1.9.9'))       -- true
print(r:has('2.0.0'))       -- false
print(r:has(vim.version())) -- check against current Nvim version
```

Or use cmp(), le(), lt(), ge(), gt(), and/or eq() to compare a version against `.to` and `.from` directly:

```
local r = vim.version.range('1.0.0 - 2.0.0') -- >=1.0, <2.0
print(vim.version.ge({1,0,3}, r.from) and vim.version.lt({1,0,3}, r.to))
```

Parameters:

`{spec}` (`string`) Version range "spec"

Return:

(`table?`) A table with the following fields:

`{from}` (`vim.Version`)

`{to}` (`vim.Version`)

Lua module: vim.iter vim.iter
------------------------------------------

`vim.iter())` is an interface for iterables: it wraps a table or function argument into an `Iter` object with methods (such as Iter:filter()) and Iter:map())) that transform the underlying source data. These methods can be chained to create iterator "pipelines": the output of each pipeline stage is input to the next stage. The first stage depends on the type passed to `vim.iter()`:

Lists or arrays (lua-list) yield only the value of each element.

Holes (nil values) are allowed (but discarded).

Use pairs() to treat array/list tables as dicts (preserve holes and non-contiguous integer keys): `vim.iter(pairs(…))`.

Or initialize with ipairs(): `vim.iter(ipairs(…))`.

Non-list tables (lua-dict) yield both the key and value of each element.

Function iterators yield all values returned by the underlying function.

Tables with a \_\_call()) metamethod are treated as function iterators.

The iterator pipeline terminates when the underlying iterable is exhausted (for function iterators this means it returned nil).

**Note:** `vim.iter()` scans table input to decide if it is a list or a dict; to avoid this cost you can wrap the table with an iterator e.g. `vim.iter(ipairs({…}))`, but that precludes the use of list-iterator operations such as Iter:rev())).

Examples:

```
local it = vim.iter({ 1, 2, 3, 4, 5 })
it:map(function(v)
  return v * 3
end)
it:rev()
it:skip(2)
it:totable()
-- { 9, 6, 3 }
-- ipairs() is a function iterator which returns both the index (i) and the value (v)
vim.iter(ipairs({ 1, 2, 3, 4, 5 })):map(function(i, v)
  if i > 2 then return v end
end):totable()
-- { 3, 4, 5 }
local it = vim.iter(vim.gsplit('1,2,3,4,5', ','))
it:map(function(s) return tonumber(s) end)
for i, d in it:enumerate() do
  print(string.format("Column %d is %d", i, d))
end
-- Column 1 is 1
-- Column 2 is 2
-- Column 3 is 3
-- Column 4 is 4
-- Column 5 is 5
vim.iter({ a = 1, b = 2, c = 3, z = 26 }):any(function(k, v)
  return k == 'z'
end)
-- true
local rb = vim.ringbuf(3)
rb:push("a")
rb:push("b")
vim.iter(rb):totable()
-- { "a", "b" }
```

Iter:all(`{pred}`) `Iter:all())` Returns true if all items in the iterator match the given predicate.

Parameters:

`{pred}` (`fun(...):boolean`) Predicate function. Takes all values returned from the previous stage in the pipeline as arguments and returns true if the predicate matches.

Iter:any(`{pred}`) `Iter:any())` Returns true if any of the items in the iterator match the given predicate.

Parameters:

`{pred}` (`fun(...):boolean`) Predicate function. Takes all values returned from the previous stage in the pipeline as arguments and returns true if the predicate matches.

Iter:each(`{f}`) `Iter:each())` Calls a function once for each item in the pipeline, draining the iterator.

For functions with side effects. To modify the values in the iterator, use Iter:map()).

Parameters:

`{f}` (`fun(...)`) Function to execute for each item in the pipeline. Takes all of the values returned by the previous stage in the pipeline as arguments.

Iter:enumerate() `Iter:enumerate())` Yields the item index (count) and value for each item of an iterator pipeline.

For list tables, this is more efficient:

```
vim.iter(ipairs(t))
```

instead of:

```
vim.iter(t):enumerate()
```

Example:

```
local it = vim.iter(vim.gsplit('abc', '')):enumerate()
it:next()
-- 1        'a'
it:next()
-- 2        'b'
it:next()
-- 3        'c'
```

Iter:filter(`{f}`) `Iter:filter())` Filters an iterator pipeline.

Example:

```
local bufs = vim.iter(vim.api.nvim_list_bufs()):filter(vim.api.nvim_buf_is_loaded)
```

Parameters:

`{f}` (`fun(...):boolean`) Takes all values returned from the previous stage in the pipeline and returns false or nil if the current iterator element should be removed.

Iter:find(`{f}`) `Iter:find())` Find the first value in the iterator that satisfies the given predicate.

Advances the iterator. Returns nil and drains the iterator if no value is found.

Examples:

```
local it = vim.iter({ 3, 6, 9, 12 })
it:find(12)
-- 12
local it = vim.iter({ 3, 6, 9, 12 })
it:find(20)
-- nil
local it = vim.iter({ 3, 6, 9, 12 })
it:find(function(v) return v % 4 == 0 end)
-- 12
```

Iter:flatten(`{depth}`) `Iter:flatten())` Flattens a list-iterator, un-nesting nested values up to the given `{depth}`. Errors if it attempts to flatten a dict-like value.

Examples:

```
vim.iter({ 1, { 2 }, { { 3 } } }):flatten():totable()
-- { 1, 2, { 3 } }
vim.iter({1, { { a = 2 } }, { 3 } }):flatten():totable()
-- { 1, { a = 2 }, 3 }
vim.iter({ 1, { { a = 2 } }, { 3 } }):flatten(math.huge):totable()
-- error: attempt to flatten a dict-like table
```

Parameters:

`{depth}` (`number?`) Depth to which list-iterator should be flattened (defaults to 1)

Iter:fold(`{init}`, `{f}`) `Iter:fold())` Folds ("reduces") an iterator into a single value. `Iter:reduce())`

Examples:

```
-- Create a new table with only even values
vim.iter({ a = 1, b = 2, c = 3, d = 4 })
  :filter(function(k, v) return v % 2 == 0 end)
  :fold({}, function(acc, k, v)
    acc[k] = v
    return acc
  end) --> { b = 2, d = 4 }
-- Get the "maximum" item of an iterable.
vim.iter({ -99, -4, 3, 42, 0, 0, 7 })
  :fold({}, function(acc, v)
    acc.max = math.max(v, acc.max or v)
    return acc
  end) --> { max = 42 }
```

Parameters:

`{init}` (`any`) Initial value of the accumulator.

`{f}` (`fun(acc:A, ...):A`) Accumulation function.

Iter:join(`{delim}`) `Iter:join())` Collect the iterator into a delimited string.

Each element in the iterator is joined into a string separated by `{delim}`.

Consumes the iterator.

Parameters:

`{delim}` (`string`) Delimiter

Iter:last() `Iter:last())` Drains the iterator and returns the last item.

Example:

```
local it = vim.iter(vim.gsplit('abcdefg', ''))
it:last()
-- 'g'
local it = vim.iter({ 3, 6, 9, 12, 15 })
it:last()
-- 15
```

Iter:map(`{f}`) `Iter:map())` Maps the items of an iterator pipeline to the values returned by `f`.

If the map function returns nil, the value is filtered from the iterator.

Example:

```
local it = vim.iter({ 1, 2, 3, 4 }):map(function(v)
  if v % 2 == 0 then
    return v * 3
  end
end)
it:totable()
-- { 6, 12 }
```

Parameters:

`{f}` (`fun(...):...:any`) Mapping function. Takes all values returned from the previous stage in the pipeline as arguments and returns one or more new values, which are used in the next pipeline stage. Nil return values are filtered from the output.

Iter:next() `Iter:next())` Gets the next value from the iterator.

Example:

```
local it = vim.iter(string.gmatch('1 2 3', '%d+')):map(tonumber)
it:next()
-- 1
it:next()
-- 2
it:next()
-- 3
```

Iter:nth(`{n}`) `Iter:nth())` Gets the nth value of an iterator (and advances to it).

If `n` is negative, offsets from the end of a list-iterator.

Example:

```
local it = vim.iter({ 3, 6, 9, 12 })
it:nth(2)
-- 6
it:nth(2)
-- 12
local it2 = vim.iter({ 3, 6, 9, 12 })
it2:nth(-2)
-- 9
it2:nth(-2)
-- 3
```

Parameters:

`{n}` (`number`) Index of the value to return. May be negative if the source is a list-iterator.

Iter:peek() `Iter:peek())` Gets the next value in a list-iterator without consuming it.

Example:

```
local it = vim.iter({ 3, 6, 9, 12 })
it:peek()
-- 3
it:peek()
-- 3
it:next()
-- 3
```

Iter:pop() `Iter:pop())` "Pops" a value from a list-iterator (gets the last value and decrements the tail).

Example:

```
local it = vim.iter({1, 2, 3, 4})
it:pop()
-- 4
it:pop()
-- 3
```

Example:

```
local it = vim.iter({ 3, 6, 9, 12 }):rev()
it:totable()
-- { 12, 9, 6, 3 }
```

Iter:rfind(`{f}`) `Iter:rfind())` Gets the first value satisfying a predicate, from the end of a list-iterator.

Advances the iterator. Returns nil and drains the iterator if no value is found.

Examples:

```
local it = vim.iter({ 1, 2, 3, 2, 1 }):enumerate()
it:rfind(1)
-- 5        1
it:rfind(1)
-- 1        1
```

Iter:rpeek() `Iter:rpeek())` Gets the last value of a list-iterator without consuming it.

Example:

```
local it = vim.iter({1, 2, 3, 4})
it:rpeek()
-- 4
it:rpeek()
-- 4
it:pop()
-- 4
```

Iter:rskip(`{n}`) `Iter:rskip())` Discards `n` values from the end of a list-iterator pipeline.

Example:

```
local it = vim.iter({ 1, 2, 3, 4, 5 }):rskip(2)
it:next()
-- 1
it:pop()
-- 3
```

Parameters:

`{n}` (`number`) Number of values to skip.

Iter:skip(`{n}`) `Iter:skip())` Skips `n` values of an iterator pipeline.

Example:

```
local it = vim.iter({ 3, 6, 9, 12 }):skip(2)
it:next()
-- 9
```

Parameters:

`{n}` (`number`) Number of values to skip.

Iter:slice(`{first}`, `{last}`) `Iter:slice())` Sets the start and end of a list-iterator pipeline.

Equivalent to `:skip(first - 1):rskip(len - last + 1)`.

Parameters:

`{first}` (`number`)

`{last}` (`number`)

Iter:take(`{n}`) `Iter:take())` Transforms an iterator to yield only the first n values.

Example:

```
local it = vim.iter({ 1, 2, 3, 4 }):take(2)
it:next()
-- 1
it:next()
-- 2
it:next()
-- nil
```

Parameters:

`{n}` (`integer`)

Iter:totable() `Iter:totable())` Collect the iterator into a table.

The resulting table depends on the initial source in the iterator pipeline. Array-like tables and function iterators will be collected into an array-like table. If multiple values are returned from the final stage in the iterator pipeline, each value will be included in a table.

Examples:

```
vim.iter(string.gmatch('100 20 50', '%d+')):map(tonumber):totable()
-- { 100, 20, 50 }
vim.iter({ 1, 2, 3 }):map(function(v) return v, 2 * v end):totable()
-- { { 1, 2 }, { 2, 4 }, { 3, 6 } }
vim.iter({ a = 1, b = 2, c = 3 }):filter(function(k, v) return v % 2 ~= 0 end):totable()
-- { { 'a', 1 }, { 'c', 3 } }
```

The generated table is an array-like table with consecutive, numeric indices. To create a map-like table with arbitrary keys, use Iter:fold()).

Lua module: vim.snippet vim.snippet
---------------------------------------------------

Fields:

`{direction}` (`vim.snippet.Direction`) Navigation direction. -1 for previous, 1 for next.

vim.snippet.active(`{filter}`) `vim.snippet.active())` Returns `true` if there's an active snippet in the current buffer, applying the given filter if provided.

You can use this function to navigate a snippet as follows:

```
vim.keymap.set({ 'i', 's' }, '<Tab>', function()
   if vim.snippet.active({ direction = 1 }) then
     return '<Cmd>lua vim.snippet.jump(1)<CR>'
   else
     return '<Tab>'
   end
 end, { expr = true })
```

Parameters:

`{filter}` (`vim.snippet.ActiveFilter?`) Filter to constrain the search with:

`direction` (vim.snippet.Direction): Navigation direction. Will return `true` if the snippet can be jumped in the given direction. See vim.snippet.ActiveFilter.

Parameters:

`{input}` (`string`)

vim.snippet.jump(`{direction}`) `vim.snippet.jump())` Jumps to the next (or previous) placeholder in the current snippet, if possible.

For example, map `<Tab>` to jump while a snippet is active:

```
vim.keymap.set({ 'i', 's' }, '<Tab>', function()
   if vim.snippet.active({ direction = 1 }) then
     return '<Cmd>lua vim.snippet.jump(1)<CR>'
   else
     return '<Tab>'
   end
 end, { expr = true })
```

Parameters:

`{direction}` (`vim.snippet.Direction`) Navigation direction. -1 for previous, 1 for next.

vim.snippet.stop() `vim.snippet.stop())` Exits the current snippet.

Lua module: vim.text vim.text
------------------------------------------

vim.text.hexdecode(`{enc}`) `vim.text.hexdecode())` Hex decode a string.

Parameters:

`{enc}` (`string`) String to decode

Return (multiple):

(`string?`) Decoded string (`string?`) Error message, if any

vim.text.hexencode(`{str}`) `vim.text.hexencode())` Hex encode a string.

Parameters:

`{str}` (`string`) String to encode

Return:

(`string`) Hex encoded string

Lua module: tohtml vim.tohtml
--------------------------------------------

:\[range\]TOhtml `{file}` `:TOhtml` Converts the buffer shown in the current window to HTML, opens the generated HTML in a new split window, and saves its contents to `{file}`. If `{file}` is not given, a temporary file (created by tempname())) is used.

tohtml.tohtml(`{winid}`, `{opt}`) `tohtml.tohtml.tohtml())` Converts the buffer shown in the window `{winid}` to HTML and returns the output as a list of string.

Parameters:

`{winid}` (`integer?`) Window to convert (defaults to current window)

`{opt}` (`table?`) Optional parameters.

`{title}` (`string|false`, default: buffer name) Title tag to set in the generated HTML code.

`{number_lines}` (`boolean`, default: `false`) Show line numbers.

`{font}` (`string[]|string`, default: `guifont`) Fonts to use.

`{width}` (`integer`, default: 'textwidth' if non-zero or window width otherwise) Width used for items which are either right aligned or repeat a character infinitely.

`{range}` (`integer[]`, default: entire buffer) Range of rows to use.) and path:match('[/\\\\]lib

Parameters:

`{names}` (`string|string[]|fun(name: string, path: string): boolean`) Names of the items to find. Must be base names, paths and globs are not supported when `{names}` is a string or a table. If `{names}` is a function, it is called for each traversed item with args:

name: base name of the current item

path: full path of the current item The function should return `true` if the given item is considered a match.

`{opts}` (`table`) Optional keyword arguments:

`{path}` (`string`) Path to begin searching from. If omitted, the current-directory is used.

`{upward}` (`boolean`, default: `false`) Search upward through parent directories. Otherwise, search through child directories (recursively).

`{stop}` (`string`) Stop searching when this directory is reached. The directory itself is not searched.

`{type}` (`string`) Find only items of the given type. If omitted, all items that match `{names}` are included.

`{limit}` (`number`, default: `1`) Stop the search after finding this many matches. Use `math.huge` to place no limit on the number of matches.

vim.fs.joinpath(`{...}`) `vim.fs.joinpath())` Concatenate directories and/or file paths into a single path with normalization (e.g., `"foo/"` and `"bar"` get joined to `"foo/bar"`)

Parameters:

`{...}` (`string`)

vim.fs.normalize(`{path}`, `{opts}`) `vim.fs.normalize())` Normalize a path to a standard format. A tilde (~) character at the beginning of the path is expanded to the user's home directory and environment variables are also expanded. "." and ".." components are also resolved, except when the path is relative and trying to resolve it would result in an absolute path.

"." as the only part in a relative path:

"." => "."

"././" => "."

".." when it leads outside the current directory

"foo/../../bar" => "../bar"

"../../foo" => "../../foo"

".." in the root directory returns the root directory.

"/../../" => "/"

On Windows, backslash (\\) characters are converted to forward slashes (/).

Examples:

urltomarkdowncodeblockplaceholder1070.8183295151917569

Parameters:

`{path}` (`string`) Path to normalize

`{opts}` (`table?`) A table with the following fields:

`{expand_env}` (`boolean`, default: `true`) Expand environment variables.

`{win}` (`boolean`, default: `true` in Windows, `false` otherwise) Path is a Windows path.

Return:

(`string`) Normalized path

vim.fs.parents(`{start}`) `vim.fs.parents())` Iterate over all the parents of the given path.

Example:

urltomarkdowncodeblockplaceholder1080.2287698239165843

Parameters:

`{start}` (`string`) Initial path.

Return (multiple):

(`fun(_, dir: string): string?`) Iterator (`nil`) (`string?`)

vim.fs.rm(`{path}`, `{opts}`) `vim.fs.rm())` Remove files or directories

Parameters:

`{path}` (`string`) Path to remove

`{opts}` (`table?`) A table with the following fields:

`{recursive}` (`boolean`) Remove directories and their contents recursively

`{force}` (`boolean`) Ignore nonexistent files and arguments

vim.fs.root(`{source}`, `{marker}`) `vim.fs.root())` Find the first parent directory containing a specific "marker", relative to a file path or buffer.

If the buffer is unnamed (has no backing file) or has a non-empty 'buftype' then the search begins from Nvim's current-directory.

Example:

urltomarkdowncodeblockplaceholder1090.711686654889139

Parameters:

`{source}` (`integer|string`) Buffer number (0 for current buffer) or file path (absolute or relative to the current-directory) to begin the search from.

`{marker}` (`string|string[]|fun(name: string, path: string): boolean`) A marker, or list of markers, to search for. If a function, the function is called for each evaluated item and should return true if `{name}` and `{path}` are a match.

Return:

(`string?`) Directory path containing one of the given markers, or nil if no directory was found.

Lua module: vim.glob vim.glob
------------------------------------------

vim.glob.to\_lpeg(`{pattern}`) `vim.glob.to_lpeg())` Parses a raw glob into an lua-lpeg pattern.

Glob patterns can have the following syntax:

`*` to match one or more characters in a path segment

`?` to match on one character in a path segment

`**` to match any number of path segments, including none

`{}` to group conditions (e.g. `*.{ts,js}` matches TypeScript and JavaScript files)

`[]` to declare a range of characters to match in a path segment (e.g., `example.[0-9]` to match on `example.0`, `example.1`, …)

`[!...]` to negate a range of characters to match in a path segment (e.g., `example.[!0-9]` to match on `example.a`, `example.b`, but not `example.0`)

Parameters:

`{pattern}` (`string`) The raw glob pattern

Return:

(`vim.lpeg.Pattern`) pattern An lua-lpeg representation of the pattern

VIM.LPEG vim.lpeg
------------------------------

LPeg is a pattern-matching library for Lua, based on Parsing Expression Grammars (PEGs). <https://bford.info/packrat/>

Pattern:match(`{subject}`, `{init}`, `{...}`) `Pattern:match())` Matches the given `pattern` against the `subject` string. If the match succeeds, returns the index in the subject of the first character after the match, or the captured values (if the pattern captured any value). An optional numeric argument `init` makes the match start at that position in the subject string. As usual in Lua libraries, a negative value counts from the end. Unlike typical pattern-matching functions, `match` works only in anchored mode; that is, it tries to match the pattern with a prefix of the given subject string (at position `init`), not with an arbitrary substring of the subject. So, if we want to find a pattern anywhere in a string, we must either write a loop in Lua or write a pattern that matches anywhere.

Example:

urltomarkdowncodeblockplaceholder1100.7752549996783569

Parameters:

`{subject}` (`string`)

`{init}` (`integer?`)

`{...}` (`any`)

vim.lpeg.B(`{pattern}`) `vim.lpeg.B())` Returns a pattern that matches only if the input string at the current position is preceded by `patt`. Pattern `patt` must match only strings with some fixed length, and it cannot contain captures. Like the `and` predicate, this pattern never consumes any input, independently of success or failure.

Parameters:

`{pattern}` (`vim.lpeg.Pattern|string|integer|boolean|table`)

Return:

(`vim.lpeg.Pattern`)

vim.lpeg.C(`{patt}`) `vim.lpeg.C())` Creates a simple capture, which captures the substring of the subject that matches `patt`. The captured value is a string. If `patt` has other captures, their values are returned after this one.

Example:

urltomarkdowncodeblockplaceholder1110.2241242272539854

Parameters:

`{patt}` (`vim.lpeg.Pattern|string|integer|boolean|table|function`)

Return:

(`vim.lpeg.Capture`)

vim.lpeg.Carg(`{n}`) `vim.lpeg.Carg())` Creates an argument capture. This pattern matches the empty string and produces the value given as the nth extra argument given in the call to `lpeg.match`.

Parameters:

`{n}` (`integer`)

Return:

(`vim.lpeg.Capture`)

vim.lpeg.Cb(`{name}`) `vim.lpeg.Cb())` Creates a back capture. This pattern matches the empty string and produces the values produced by the most recent group capture named `name` (where `name` can be any Lua value). Most recent means the last complete outermost group capture with the given name. A Complete capture means that the entire pattern corresponding to the capture has matched. An Outermost capture means that the capture is not inside another complete capture. In the same way that LPeg does not specify when it evaluates captures, it does not specify whether it reuses values previously produced by the group or re-evaluates them.

Return:

(`vim.lpeg.Capture`)

vim.lpeg.Cc(`{...}`) `vim.lpeg.Cc())` Creates a constant capture. This pattern matches the empty string and produces all given values as its captured values.

Return:

(`vim.lpeg.Capture`)

vim.lpeg.Cf(`{patt}`, `{func}`) `vim.lpeg.Cf())` Creates a fold capture. If `patt` produces a list of captures C1 C2 ... Cn, this capture will produce the value `func(...func(func(C1, C2), C3)...,Cn)`, that is, it will fold (or accumulate, or reduce) the captures from `patt` using function `func`. This capture assumes that `patt` should produce at least one capture with at least one value (of any type), which becomes the initial value of an accumulator. (If you need a specific initial value, you may prefix a constant capture to `patt`.) For each subsequent capture, LPeg calls `func` with this accumulator as the first argument and all values produced by the capture as extra arguments; the first result from this call becomes the new value for the accumulator. The final value of the accumulator becomes the captured value.

Example:

urltomarkdowncodeblockplaceholder1120.17046473394432948

Parameters:

`{patt}` (`vim.lpeg.Pattern|string|integer|boolean|table|function`)

`{func}` (`fun(acc, newvalue)`)

Return:

(`vim.lpeg.Capture`)

vim.lpeg.Cg(`{patt}`, `{name}`) `vim.lpeg.Cg())` Creates a group capture. It groups all values returned by `patt` into a single capture. The group may be anonymous (if no name is given) or named with the given name (which can be any non-nil Lua value).

Parameters:

`{patt}` (`vim.lpeg.Pattern|string|integer|boolean|table|function`)

`{name}` (`string?`)

Return:

(`vim.lpeg.Capture`)

vim.lpeg.Cmt(`{patt}`, `{fn}`) `vim.lpeg.Cmt())` Creates a match-time capture. Unlike all other captures, this one is evaluated immediately when a match occurs (even if it is part of a larger pattern that fails later). It forces the immediate evaluation of all its nested captures and then calls `function`. The given function gets as arguments the entire subject, the current position (after the match of `patt`), plus any capture values produced by `patt`. The first value returned by `function` defines how the match happens. If the call returns a number, the match succeeds and the returned number becomes the new current position. (Assuming a subject sand current position `i`, the returned number must be in the range `[i, len(s) + 1]`.) If the call returns `true`, the match succeeds without consuming any input (so, to return true is equivalent to return `i`). If the call returns `false`, `nil`, or no value, the match fails. Any extra values returned by the function become the values produced by the capture.

Parameters:

`{patt}` (`vim.lpeg.Pattern|string|integer|boolean|table|function`)

`{fn}` (`fun(s: string, i: integer, ...: any)`) (position: boolean|integer, ...: any)

Return:

(`vim.lpeg.Capture`)

vim.lpeg.Cp() `vim.lpeg.Cp())` Creates a position capture. It matches the empty string and captures the position in the subject where the match occurs. The captured value is a number.

Example:

urltomarkdowncodeblockplaceholder1130.25685910275600277

Return:

(`vim.lpeg.Capture`)

vim.lpeg.Cs(`{patt}`) `vim.lpeg.Cs())` Creates a substitution capture. This function creates a substitution capture, which captures the substring of the subject that matches `patt`, with substitutions. For any capture inside `patt` with a value, the substring that matched the capture is replaced by the capture value (which should be a string). The final captured value is the string resulting from all replacements.

Example:

urltomarkdowncodeblockplaceholder1140.5942950184718667

Parameters:

`{patt}` (`vim.lpeg.Pattern|string|integer|boolean|table|function`)

Return:

(`vim.lpeg.Capture`)

vim.lpeg.Ct(`{patt}`) `vim.lpeg.Ct())` Creates a table capture. This capture returns a table with all values from all anonymous captures made by `patt` inside this table in successive integer keys, starting at 1. Moreover, for each named capture group created by `patt`, the first value of the group is put into the table with the group name as its key. The captured value is only the table.

Parameters:

`{patt}` (`vim.lpeg.Pattern|string|integer|boolean|table|function`)

Return:

(`vim.lpeg.Capture`)

vim.lpeg.locale(`{tab}`) `vim.lpeg.locale())` Returns a table with patterns for matching some character classes according to the current locale. The table has fields named `alnum`, `alpha`, `cntrl`, `digit`, `graph`, `lower`, `print`, `punct`, `space`, `upper`, and `xdigit`, each one containing a correspondent pattern. Each pattern matches any single character that belongs to its class. If called with an argument `table`, then it creates those fields inside the given table and returns that table.

Example:

urltomarkdowncodeblockplaceholder1150.27822418457785614

Parameters:

`{tab}` (`table?`)

Return:

(`vim.lpeg.Locale`)

vim.lpeg.match(`{pattern}`, `{subject}`, `{init}`, `{...}`) `vim.lpeg.match())` Matches the given `pattern` against the `subject` string. If the match succeeds, returns the index in the subject of the first character after the match, or the captured values (if the pattern captured any value). An optional numeric argument `init` makes the match start at that position in the subject string. As usual in Lua libraries, a negative value counts from the end. Unlike typical pattern-matching functions, `match` works only in anchored mode; that is, it tries to match the pattern with a prefix of the given subject string (at position `init`), not with an arbitrary substring of the subject. So, if we want to find a pattern anywhere in a string, we must either write a loop in Lua or write a pattern that matches anywhere.

Example:

urltomarkdowncodeblockplaceholder1160.2755921602208562

Parameters:

`{pattern}` (`vim.lpeg.Pattern|string|integer|boolean|table|function`)

`{subject}` (`string`)

`{init}` (`integer?`)

`{...}` (`any`)

vim.lpeg.P(`{value}`) `vim.lpeg.P())` Converts the given value into a proper pattern. The following rules are applied:

If the argument is a pattern, it is returned unmodified.

If the argument is a string, it is translated to a pattern that matches the string literally.

If the argument is a non-negative number `n`, the result is a pattern that matches exactly `n` characters.

If the argument is a negative number `-n`, the result is a pattern that succeeds only if the input string has less than `n` characters left: `lpeg.P(-n)` is equivalent to `-lpeg.P(n)` (see the unary minus operation).

If the argument is a boolean, the result is a pattern that always succeeds or always fails (according to the boolean value), without consuming any input.

If the argument is a table, it is interpreted as a grammar (see Grammars).

If the argument is a function, returns a pattern equivalent to a match-time capture over the empty string.

Parameters:

`{value}` (`vim.lpeg.Pattern|string|integer|boolean|table|function`)

Return:

(`vim.lpeg.Pattern`)

vim.lpeg.R(`{...}`) `vim.lpeg.R())` Returns a pattern that matches any single character belonging to one of the given ranges. Each `range` is a string `xy` of length 2, representing all characters with code between the codes of `x` and `y` (both inclusive). As an example, the pattern `lpeg.R('09')` matches any digit, and `lpeg.R('az', 'AZ')` matches any ASCII letter.

Example:

urltomarkdowncodeblockplaceholder1170.9390966826397653

Parameters:

`{...}` (`string`)

Return:

(`vim.lpeg.Pattern`)

vim.lpeg.S(`{string}`) `vim.lpeg.S())` Returns a pattern that matches any single character that appears in the given string (the `S` stands for Set). As an example, the pattern `lpeg.S('+-*/')` matches any arithmetic operator. Note that, if `s` is a character (that is, a string of length 1), then `lpeg.P(s)` is equivalent to `lpeg.S(s)` which is equivalent to `lpeg.R(s..s)`. Note also that both `lpeg.S('')` and `lpeg.R()` are patterns that always fail.

Parameters:

`{string}` (`string`)

Return:

(`vim.lpeg.Pattern`)

vim.lpeg.setmaxstack(`{max}`) `vim.lpeg.setmaxstack())` Sets a limit for the size of the backtrack stack used by LPeg to track calls and choices. The default limit is `400`. Most well-written patterns need little backtrack levels and therefore you seldom need to change this limit; before changing it you should try to rewrite your pattern to avoid the need for extra space. Nevertheless, a few useful patterns may overflow. Also, with recursive grammars, subjects with deep recursion may also need larger limits.

Parameters:

`{max}` (`integer`)

vim.lpeg.type(`{value}`) `vim.lpeg.type())` Returns the string `"pattern"` if the given value is a pattern, otherwise `nil`.

Parameters:

`{value}` (`vim.lpeg.Pattern|string|integer|boolean|table|function`)

vim.lpeg.V(`{v}`) `vim.lpeg.V())` Creates a non-terminal (a variable) for a grammar. This operation creates a non-terminal (a variable) for a grammar. The created non-terminal refers to the rule indexed by `v` in the enclosing grammar.

Example:

urltomarkdowncodeblockplaceholder1180.13563568348178512

Parameters:

`{v}` (`boolean|string|number|function|table|thread|userdata|lightuserdata`)

Return:

(`vim.lpeg.Pattern`)

vim.lpeg.version() `vim.lpeg.version())` Returns a string with the running version of LPeg.

VIM.RE vim.re
------------------------

The `vim.re` module provides a conventional regex-like syntax for pattern usage within LPeg vim.lpeg. (Unrelated to vim.regex which provides Vim regexp from Lua.)

vim.re.compile(`{string}`, `{defs}`) `vim.re.compile())` Compiles the given `{string}` and returns an equivalent LPeg pattern. The given string may define either an expression or a grammar. The optional `{defs}` table provides extra Lua values to be used by the pattern.

Parameters:

`{string}` (`string`)

`{defs}` (`table?`)

Return:

(`vim.lpeg.Pattern`)

vim.re.find(`{subject}`, `{pattern}`, `{init}`) `vim.re.find())` Searches the given `{pattern}` in the given `{subject}`. If it finds a match, returns the index where this occurrence starts and the index where it ends. Otherwise, returns nil.

An optional numeric argument `{init}` makes the search starts at that position in the subject string. As usual in Lua libraries, a negative value counts from the end.

Parameters:

`{subject}` (`string`)

`{pattern}` (`vim.lpeg.Pattern|string`)

`{init}` (`integer?`)

Return (multiple):

(`integer?`) the index where the occurrence starts, nil if no match (`integer?`) the index where the occurrence ends, nil if no match

vim.re.gsub(`{subject}`, `{pattern}`, `{replacement}`) `vim.re.gsub())` Does a global substitution, replacing all occurrences of `{pattern}` in the given `{subject}` by `{replacement}`.

Parameters:

`{subject}` (`string`)

`{pattern}` (`vim.lpeg.Pattern|string`)

`{replacement}` (`string`)

vim.re.match(`{subject}`, `{pattern}`, `{init}`) `vim.re.match())` Matches the given `{pattern}` against the given `{subject}`, returning all captures.

Parameters:

`{subject}` (`string`)

`{pattern}` (`vim.lpeg.Pattern|string`)

`{init}` (`integer?`)

Return:

(`integer|vim.lpeg.Capture?`)

See also:

vim.lpeg.match()

vim.re.updatelocale() `vim.re.updatelocale())` Updates the pre-defined character classes to the current locale.

VIM.REGEX vim.regex
---------------------------------

Vim regexes can be used directly from Lua. Currently they only allow matching within a single line.

`regex:match_line())` regex:match\_line(`{bufnr}`, `{line_idx}`, `{start}`, `{end_}`) Match line `{line_idx}` (zero-based) in buffer `{bufnr}`. If `{start}` and `{end}` are supplied, match only this byte index range. Otherwise see regex:match\_str()). If `{start}` is used, then the returned byte indices will be relative `{start}`.

Parameters:

`{bufnr}` (`integer`)

`{line_idx}` (`integer`)

`{start}` (`integer?`)

`{end_}` (`integer?`)

regex:match\_str(`{str}`) `regex:match_str())` Match the string against the regex. If the string should match the regex precisely, surround the regex with `^` and `$`. If there was a match, the byte indices for the beginning and end of the match are returned. When there is no match, `nil` is returned. Because any integer is "truthy", `regex:match_str()` can be directly used as a condition in an if-statement.

Parameters:

`{str}` (`string`)

vim.regex(`{re}`) `vim.regex())` Parse the Vim regex `{re}` and return a regex object. Regexes are "magic" and case-sensitive by default, regardless of 'magic' and 'ignorecase'. They can be controlled with flags, see /magic and /ignorecase.

Parameters:

`{re}` (`string`)

Lua module: vim.secure vim.secure
------------------------------------------------

vim.secure.read(`{path}`) `vim.secure.read())` Attempt to read the file at `{path}` prompting the user if the file should be trusted. The user's choice is persisted in a trust database at $XDG\_STATE\_HOME/nvim/trust.

Parameters:

`{path}` (`string`) Path to a file to read.

Return:

(`string?`) The contents of the given file if it exists and is trusted, or nil otherwise.

vim.secure.trust(`{opts}`) `vim.secure.trust())` Manage the trust database.

Parameters:

`{opts}` (`table`) A table with the following fields:

`{action}` (`'allow'|'deny'|'remove'`) - `'allow'` to add a file to the trust database and trust it,

`'deny'` to add a file to the trust database and deny it,

`'remove'` to remove file from the trust database

`{path}` (`string`) Path to a file to update. Mutually exclusive with `{bufnr}`. Cannot be used when `{action}` is "allow".

`{bufnr}` (`integer`) Buffer number to update. Mutually exclusive with `{path}`.

Return (multiple):

(`boolean`) success true if operation was successful (`string`) msg full path if operation was successful, else error message

Lua module: vim.version vim.version
---------------------------------------------------

The `vim.version` module provides functions for comparing versions and ranges conforming to the <https://semver.org> spec. Plugins, and plugin managers, can use this to check available tools and dependencies on the current system.

Example:

urltomarkdowncodeblockplaceholder1190.5142593430246558

`vim.version())` returns the version of the current Nvim process.

### VERSION RANGE SPEC version-range

A version "range spec" defines a semantic version range which can be tested against a version, using vim.version.range()).

Supported range specs are shown in the following table. **Note:** suffixed versions (1.2.3-rc1) are not matched.

urltomarkdowncodeblockplaceholder1200.7223213142199674

vim.version.cmp(`{v1}`, `{v2}`) `vim.version.cmp())` Parses and compares two version objects (the result of vim.version.parse()), or specified literally as a `{major, minor, patch}` tuple, e.g. `{1, 0, 3}`).

Example:

urltomarkdowncodeblockplaceholder1210.8117634004505074

**Note:**

Per semver, build metadata is ignored when comparing two otherwise-equivalent versions.

Parameters:

`{v1}` (`vim.Version|number[]|string`) Version object.

`{v2}` (`vim.Version|number[]|string`) Version to compare with `v1`.

Return:

(`integer`) -1 if `v1 < v2`, 0 if `v1 == v2`, 1 if `v1 > v2`.

vim.version.eq(`{v1}`, `{v2}`) `vim.version.eq())` Returns `true` if the given versions are equal. See vim.version.cmp()) for usage.

Parameters:

`{v1}` (`vim.Version|number[]|string`)

`{v2}` (`vim.Version|number[]|string`)

vim.version.ge(`{v1}`, `{v2}`) `vim.version.ge())` Returns `true` if `v1 >= v2`. See vim.version.cmp()) for usage.

Parameters:

`{v1}` (`vim.Version|number[]|string`)

`{v2}` (`vim.Version|number[]|string`)

vim.version.gt(`{v1}`, `{v2}`) `vim.version.gt())` Returns `true` if `v1 > v2`. See vim.version.cmp()) for usage.

Parameters:

`{v1}` (`vim.Version|number[]|string`)

`{v2}` (`vim.Version|number[]|string`)

vim.version.last(`{versions}`) `vim.version.last())` TODO: generalize this, move to func.lua

Parameters:

`{versions}` (`vim.Version[]`)

vim.version.le(`{v1}`, `{v2}`) `vim.version.le())` Returns `true` if `v1 <= v2`. See vim.version.cmp()) for usage.

Parameters:

`{v1}` (`vim.Version|number[]|string`)

`{v2}` (`vim.Version|number[]|string`)

vim.version.lt(`{v1}`, `{v2}`) `vim.version.lt())` Returns `true` if `v1 < v2`. See vim.version.cmp()) for usage.

Parameters:

`{v1}` (`vim.Version|number[]|string`)

`{v2}` (`vim.Version|number[]|string`)

vim.version.parse(`{version}`, `{opts}`) `vim.version.parse())` Parses a semantic version string and returns a version object which can be used with other `vim.version` functions. For example "1.0.1-rc1+build.2" returns:

urltomarkdowncodeblockplaceholder1220.7310950514156884

Parameters:

`{version}` (`string`) Version string to parse.

`{opts}` (`table?`) Optional keyword arguments:

strict (boolean): Default false. If `true`, no coercion is attempted on input not conforming to semver v2.0.0. If `false`, `parse()` attempts to coerce input such as "1.0", "0-x", "tmux 3.2a" into valid versions.

Return:

(`vim.Version?`) parsed\_version Version object or `nil` if input is invalid.

vim.version.range(`{spec}`) `vim.version.range())` Parses a semver version-range "spec" and returns a range object:

urltomarkdowncodeblockplaceholder1230.5951471239041548

`:has()` checks if a version is in the range (inclusive `from`, exclusive `to`).

Example:

urltomarkdowncodeblockplaceholder1240.7425585526121159

Or use cmp(), le(), lt(), ge(), gt(), and/or eq() to compare a version against `.to` and `.from` directly:

urltomarkdowncodeblockplaceholder1250.9468612466711352

Parameters:

`{spec}` (`string`) Version range "spec"

Return:

(`table?`) A table with the following fields:

`{from}` (`vim.Version`)

`{to}` (`vim.Version`)

Lua module: vim.iter vim.iter
------------------------------------------

`vim.iter())` is an interface for iterables: it wraps a table or function argument into an `Iter` object with methods (such as Iter:filter()) and Iter:map())) that transform the underlying source data. These methods can be chained to create iterator "pipelines": the output of each pipeline stage is input to the next stage. The first stage depends on the type passed to `vim.iter()`:

Lists or arrays (lua-list) yield only the value of each element.

Holes (nil values) are allowed (but discarded).

Use pairs() to treat array/list tables as dicts (preserve holes and non-contiguous integer keys): `vim.iter(pairs(…))`.

Or initialize with ipairs(): `vim.iter(ipairs(…))`.

Non-list tables (lua-dict) yield both the key and value of each element.

Function iterators yield all values returned by the underlying function.

Tables with a \_\_call()) metamethod are treated as function iterators.

The iterator pipeline terminates when the underlying iterable is exhausted (for function iterators this means it returned nil).

**Note:** `vim.iter()` scans table input to decide if it is a list or a dict; to avoid this cost you can wrap the table with an iterator e.g. `vim.iter(ipairs({…}))`, but that precludes the use of list-iterator operations such as Iter:rev())).

Examples:

urltomarkdowncodeblockplaceholder1260.7448762593798892

Iter:all(`{pred}`) `Iter:all())` Returns true if all items in the iterator match the given predicate.

Parameters:

`{pred}` (`fun(...):boolean`) Predicate function. Takes all values returned from the previous stage in the pipeline as arguments and returns true if the predicate matches.

Iter:any(`{pred}`) `Iter:any())` Returns true if any of the items in the iterator match the given predicate.

Parameters:

`{pred}` (`fun(...):boolean`) Predicate function. Takes all values returned from the previous stage in the pipeline as arguments and returns true if the predicate matches.

Iter:each(`{f}`) `Iter:each())` Calls a function once for each item in the pipeline, draining the iterator.

For functions with side effects. To modify the values in the iterator, use Iter:map()).

Parameters:

`{f}` (`fun(...)`) Function to execute for each item in the pipeline. Takes all of the values returned by the previous stage in the pipeline as arguments.

Iter:enumerate() `Iter:enumerate())` Yields the item index (count) and value for each item of an iterator pipeline.

For list tables, this is more efficient:

urltomarkdowncodeblockplaceholder1270.589941484771854

instead of:

urltomarkdowncodeblockplaceholder1280.9777426514684822

Example:

urltomarkdowncodeblockplaceholder1290.377702004265434

Iter:filter(`{f}`) `Iter:filter())` Filters an iterator pipeline.

Example:

urltomarkdowncodeblockplaceholder1300.24506147403797884

Parameters:

`{f}` (`fun(...):boolean`) Takes all values returned from the previous stage in the pipeline and returns false or nil if the current iterator element should be removed.

Iter:find(`{f}`) `Iter:find())` Find the first value in the iterator that satisfies the given predicate.

Advances the iterator. Returns nil and drains the iterator if no value is found.

Examples:

urltomarkdowncodeblockplaceholder1310.17152374512369795

Iter:flatten(`{depth}`) `Iter:flatten())` Flattens a list-iterator, un-nesting nested values up to the given `{depth}`. Errors if it attempts to flatten a dict-like value.

Examples:

urltomarkdowncodeblockplaceholder1320.8407398175587595

Parameters:

`{depth}` (`number?`) Depth to which list-iterator should be flattened (defaults to 1)

Iter:fold(`{init}`, `{f}`) `Iter:fold())` Folds ("reduces") an iterator into a single value. `Iter:reduce())`

Examples:

urltomarkdowncodeblockplaceholder1330.6204365948339325

Parameters:

`{init}` (`any`) Initial value of the accumulator.

`{f}` (`fun(acc:A, ...):A`) Accumulation function.

Iter:join(`{delim}`) `Iter:join())` Collect the iterator into a delimited string.

Each element in the iterator is joined into a string separated by `{delim}`.

Consumes the iterator.

Parameters:

`{delim}` (`string`) Delimiter

Iter:last() `Iter:last())` Drains the iterator and returns the last item.

Example:

urltomarkdowncodeblockplaceholder1340.868519376834646

Iter:map(`{f}`) `Iter:map())` Maps the items of an iterator pipeline to the values returned by `f`.

If the map function returns nil, the value is filtered from the iterator.

Example:

urltomarkdowncodeblockplaceholder1350.11589626835648748

Parameters:

`{f}` (`fun(...):...:any`) Mapping function. Takes all values returned from the previous stage in the pipeline as arguments and returns one or more new values, which are used in the next pipeline stage. Nil return values are filtered from the output.

Iter:next() `Iter:next())` Gets the next value from the iterator.

Example:

urltomarkdowncodeblockplaceholder1360.7497388702225476

Iter:nth(`{n}`) `Iter:nth())` Gets the nth value of an iterator (and advances to it).

If `n` is negative, offsets from the end of a list-iterator.

Example:

urltomarkdowncodeblockplaceholder1370.12201413394633809

Parameters:

`{n}` (`number`) Index of the value to return. May be negative if the source is a list-iterator.

Iter:peek() `Iter:peek())` Gets the next value in a list-iterator without consuming it.

Example:

urltomarkdowncodeblockplaceholder1380.6120792908547625

Iter:pop() `Iter:pop())` "Pops" a value from a list-iterator (gets the last value and decrements the tail).

Example:

urltomarkdowncodeblockplaceholder1390.956725056935767

Example:

urltomarkdowncodeblockplaceholder1400.7556401086826683

Iter:rfind(`{f}`) `Iter:rfind())` Gets the first value satisfying a predicate, from the end of a list-iterator.

Advances the iterator. Returns nil and drains the iterator if no value is found.

Examples:

urltomarkdowncodeblockplaceholder1410.31779031676866176

Iter:rpeek() `Iter:rpeek())` Gets the last value of a list-iterator without consuming it.

Example:

urltomarkdowncodeblockplaceholder1420.4784821171025462

Iter:rskip(`{n}`) `Iter:rskip())` Discards `n` values from the end of a list-iterator pipeline.

Example:

urltomarkdowncodeblockplaceholder1430.3657723025029076

Parameters:

`{n}` (`number`) Number of values to skip.

Iter:skip(`{n}`) `Iter:skip())` Skips `n` values of an iterator pipeline.

Example:

urltomarkdowncodeblockplaceholder1440.3762470817003154

Parameters:

`{n}` (`number`) Number of values to skip.

Iter:slice(`{first}`, `{last}`) `Iter:slice())` Sets the start and end of a list-iterator pipeline.

Equivalent to `:skip(first - 1):rskip(len - last + 1)`.

Parameters:

`{first}` (`number`)

`{last}` (`number`)

Iter:take(`{n}`) `Iter:take())` Transforms an iterator to yield only the first n values.

Example:

urltomarkdowncodeblockplaceholder1450.6384961151172754

Parameters:

`{n}` (`integer`)

Iter:totable() `Iter:totable())` Collect the iterator into a table.

The resulting table depends on the initial source in the iterator pipeline. Array-like tables and function iterators will be collected into an array-like table. If multiple values are returned from the final stage in the iterator pipeline, each value will be included in a table.

Examples:

urltomarkdowncodeblockplaceholder1460.5596784708954385

The generated table is an array-like table with consecutive, numeric indices. To create a map-like table with arbitrary keys, use Iter:fold()).

Lua module: vim.snippet vim.snippet
---------------------------------------------------

Fields:

`{direction}` (`vim.snippet.Direction`) Navigation direction. -1 for previous, 1 for next.

vim.snippet.active(`{filter}`) `vim.snippet.active())` Returns `true` if there's an active snippet in the current buffer, applying the given filter if provided.

You can use this function to navigate a snippet as follows:

urltomarkdowncodeblockplaceholder1470.9129194941022836

Parameters:

`{filter}` (`vim.snippet.ActiveFilter?`) Filter to constrain the search with:

`direction` (vim.snippet.Direction): Navigation direction. Will return `true` if the snippet can be jumped in the given direction. See vim.snippet.ActiveFilter.

Parameters:

`{input}` (`string`)

vim.snippet.jump(`{direction}`) `vim.snippet.jump())` Jumps to the next (or previous) placeholder in the current snippet, if possible.

For example, map `<Tab>` to jump while a snippet is active:

urltomarkdowncodeblockplaceholder1480.38914287342945175

Parameters:

`{direction}` (`vim.snippet.Direction`) Navigation direction. -1 for previous, 1 for next.

vim.snippet.stop() `vim.snippet.stop())` Exits the current snippet.

Lua module: vim.text vim.text
------------------------------------------

vim.text.hexdecode(`{enc}`) `vim.text.hexdecode())` Hex decode a string.

Parameters:

`{enc}` (`string`) String to decode

Return (multiple):

(`string?`) Decoded string (`string?`) Error message, if any

vim.text.hexencode(`{str}`) `vim.text.hexencode())` Hex encode a string.

Parameters:

`{str}` (`string`) String to encode

Return:

(`string`) Hex encoded string

Lua module: tohtml vim.tohtml
--------------------------------------------

:\[range\]TOhtml `{file}` `:TOhtml` Converts the buffer shown in the current window to HTML, opens the generated HTML in a new split window, and saves its contents to `{file}`. If `{file}` is not given, a temporary file (created by tempname())) is used.

tohtml.tohtml(`{winid}`, `{opt}`) `tohtml.tohtml.tohtml())` Converts the buffer shown in the window `{winid}` to HTML and returns the output as a list of string.

Parameters:

`{winid}` (`integer?`) Window to convert (defaults to current window)

`{opt}` (`table?`) Optional parameters.

`{title}` (`string|false`, default: buffer name) Title tag to set in the generated HTML code.

`{number_lines}` (`boolean`, default: `false`) Show line numbers.

`{font}` (`string[]|string`, default: `guifont`) Fonts to use.

`{width}` (`integer`, default: 'textwidth' if non-zero or window width otherwise) Width used for items which are either right aligned or repeat a character infinitely.

`{range}` (`integer[]`, default: entire buffer) Range of rows to use.)
end, {limit = math.huge, type = 'file'})

```


Parameters:

`{names}` (`string|string[]|fun(name: string, path: string): boolean`) Names of the items to find. Must be base names, paths and globs are not supported when `{names}` is a string or a table. If `{names}` is a function, it is called for each traversed item with args:

name: base name of the current item

path: full path of the current item The function should return `true` if the given item is considered a match.

`{opts}` (`table`) Optional keyword arguments:

`{path}` (`string`) Path to begin searching from. If omitted, the current-directory is used.

`{upward}` (`boolean`, default: `false`) Search upward through parent directories. Otherwise, search through child directories (recursively).

`{stop}` (`string`) Stop searching when this directory is reached. The directory itself is not searched.

`{type}` (`string`) Find only items of the given type. If omitted, all items that match `{names}` are included.

`{limit}` (`number`, default: `1`) Stop the search after finding this many matches. Use `math.huge` to place no limit on the number of matches.

vim.fs.joinpath(`{...}`) `vim.fs.joinpath())` Concatenate directories and/or file paths into a single path with normalization (e.g., `"foo/"` and `"bar"` get joined to `"foo/bar"`)

Parameters:

`{...}` (`string`)

vim.fs.normalize(`{path}`, `{opts}`) `vim.fs.normalize())` Normalize a path to a standard format. A tilde (~) character at the beginning of the path is expanded to the user's home directory and environment variables are also expanded. "." and ".." components are also resolved, except when the path is relative and trying to resolve it would result in an absolute path.

"." as the only part in a relative path:

"." => "."

"././" => "."

".." when it leads outside the current directory

"foo/../../bar" => "../bar"

"../../foo" => "../../foo"

".." in the root directory returns the root directory.

"/../../" => "/"

On Windows, backslash (\\) characters are converted to forward slashes (/).

Examples:

urltomarkdowncodeblockplaceholder1070.8183295151917569

Parameters:

`{path}` (`string`) Path to normalize

`{opts}` (`table?`) A table with the following fields:

`{expand_env}` (`boolean`, default: `true`) Expand environment variables.

`{win}` (`boolean`, default: `true` in Windows, `false` otherwise) Path is a Windows path.

Return:

(`string`) Normalized path

vim.fs.parents(`{start}`) `vim.fs.parents())` Iterate over all the parents of the given path.

Example:

urltomarkdowncodeblockplaceholder1080.2287698239165843

Parameters:

`{start}` (`string`) Initial path.

Return (multiple):

(`fun(_, dir: string): string?`) Iterator (`nil`) (`string?`)

vim.fs.rm(`{path}`, `{opts}`) `vim.fs.rm())` Remove files or directories

Parameters:

`{path}` (`string`) Path to remove

`{opts}` (`table?`) A table with the following fields:

`{recursive}` (`boolean`) Remove directories and their contents recursively

`{force}` (`boolean`) Ignore nonexistent files and arguments

vim.fs.root(`{source}`, `{marker}`) `vim.fs.root())` Find the first parent directory containing a specific "marker", relative to a file path or buffer.

If the buffer is unnamed (has no backing file) or has a non-empty 'buftype' then the search begins from Nvim's current-directory.

Example:

urltomarkdowncodeblockplaceholder1090.711686654889139

Parameters:

`{source}` (`integer|string`) Buffer number (0 for current buffer) or file path (absolute or relative to the current-directory) to begin the search from.

`{marker}` (`string|string[]|fun(name: string, path: string): boolean`) A marker, or list of markers, to search for. If a function, the function is called for each evaluated item and should return true if `{name}` and `{path}` are a match.

Return:

(`string?`) Directory path containing one of the given markers, or nil if no directory was found.

Lua module: vim.glob vim.glob
------------------------------------------

vim.glob.to\_lpeg(`{pattern}`) `vim.glob.to_lpeg())` Parses a raw glob into an lua-lpeg pattern.

Glob patterns can have the following syntax:

`*` to match one or more characters in a path segment

`?` to match on one character in a path segment

`**` to match any number of path segments, including none

`{}` to group conditions (e.g. `*.{ts,js}` matches TypeScript and JavaScript files)

`[]` to declare a range of characters to match in a path segment (e.g., `example.[0-9]` to match on `example.0`, `example.1`, …)

`[!...]` to negate a range of characters to match in a path segment (e.g., `example.[!0-9]` to match on `example.a`, `example.b`, but not `example.0`)

Parameters:

`{pattern}` (`string`) The raw glob pattern

Return:

(`vim.lpeg.Pattern`) pattern An lua-lpeg representation of the pattern

VIM.LPEG vim.lpeg
------------------------------

LPeg is a pattern-matching library for Lua, based on Parsing Expression Grammars (PEGs). https://bford.info/packrat/

Pattern:match(`{subject}`, `{init}`, `{...}`) `Pattern:match())` Matches the given `pattern` against the `subject` string. If the match succeeds, returns the index in the subject of the first character after the match, or the captured values (if the pattern captured any value). An optional numeric argument `init` makes the match start at that position in the subject string. As usual in Lua libraries, a negative value counts from the end. Unlike typical pattern-matching functions, `match` works only in anchored mode; that is, it tries to match the pattern with a prefix of the given subject string (at position `init`), not with an arbitrary substring of the subject. So, if we want to find a pattern anywhere in a string, we must either write a loop in Lua or write a pattern that matches anywhere.

Example:

urltomarkdowncodeblockplaceholder1100.7752549996783569

Parameters:

`{subject}` (`string`)

`{init}` (`integer?`)

`{...}` (`any`)

vim.lpeg.B(`{pattern}`) `vim.lpeg.B())` Returns a pattern that matches only if the input string at the current position is preceded by `patt`. Pattern `patt` must match only strings with some fixed length, and it cannot contain captures. Like the `and` predicate, this pattern never consumes any input, independently of success or failure.

Parameters:

`{pattern}` (`vim.lpeg.Pattern|string|integer|boolean|table`)

Return:

(`vim.lpeg.Pattern`)

vim.lpeg.C(`{patt}`) `vim.lpeg.C())` Creates a simple capture, which captures the substring of the subject that matches `patt`. The captured value is a string. If `patt` has other captures, their values are returned after this one.

Example:

urltomarkdowncodeblockplaceholder1110.2241242272539854

Parameters:

`{patt}` (`vim.lpeg.Pattern|string|integer|boolean|table|function`)

Return:

(`vim.lpeg.Capture`)

vim.lpeg.Carg(`{n}`) `vim.lpeg.Carg())` Creates an argument capture. This pattern matches the empty string and produces the value given as the nth extra argument given in the call to `lpeg.match`.

Parameters:

`{n}` (`integer`)

Return:

(`vim.lpeg.Capture`)

vim.lpeg.Cb(`{name}`) `vim.lpeg.Cb())` Creates a back capture. This pattern matches the empty string and produces the values produced by the most recent group capture named `name` (where `name` can be any Lua value). Most recent means the last complete outermost group capture with the given name. A Complete capture means that the entire pattern corresponding to the capture has matched. An Outermost capture means that the capture is not inside another complete capture. In the same way that LPeg does not specify when it evaluates captures, it does not specify whether it reuses values previously produced by the group or re-evaluates them.

Return:

(`vim.lpeg.Capture`)

vim.lpeg.Cc(`{...}`) `vim.lpeg.Cc())` Creates a constant capture. This pattern matches the empty string and produces all given values as its captured values.

Return:

(`vim.lpeg.Capture`)

vim.lpeg.Cf(`{patt}`, `{func}`) `vim.lpeg.Cf())` Creates a fold capture. If `patt` produces a list of captures C1 C2 ... Cn, this capture will produce the value `func(...func(func(C1, C2), C3)...,Cn)`, that is, it will fold (or accumulate, or reduce) the captures from `patt` using function `func`. This capture assumes that `patt` should produce at least one capture with at least one value (of any type), which becomes the initial value of an accumulator. (If you need a specific initial value, you may prefix a constant capture to `patt`.) For each subsequent capture, LPeg calls `func` with this accumulator as the first argument and all values produced by the capture as extra arguments; the first result from this call becomes the new value for the accumulator. The final value of the accumulator becomes the captured value.

Example:

urltomarkdowncodeblockplaceholder1120.17046473394432948

Parameters:

`{patt}` (`vim.lpeg.Pattern|string|integer|boolean|table|function`)

`{func}` (`fun(acc, newvalue)`)

Return:

(`vim.lpeg.Capture`)

vim.lpeg.Cg(`{patt}`, `{name}`) `vim.lpeg.Cg())` Creates a group capture. It groups all values returned by `patt` into a single capture. The group may be anonymous (if no name is given) or named with the given name (which can be any non-nil Lua value).

Parameters:

`{patt}` (`vim.lpeg.Pattern|string|integer|boolean|table|function`)

`{name}` (`string?`)

Return:

(`vim.lpeg.Capture`)

vim.lpeg.Cmt(`{patt}`, `{fn}`) `vim.lpeg.Cmt())` Creates a match-time capture. Unlike all other captures, this one is evaluated immediately when a match occurs (even if it is part of a larger pattern that fails later). It forces the immediate evaluation of all its nested captures and then calls `function`. The given function gets as arguments the entire subject, the current position (after the match of `patt`), plus any capture values produced by `patt`. The first value returned by `function` defines how the match happens. If the call returns a number, the match succeeds and the returned number becomes the new current position. (Assuming a subject sand current position `i`, the returned number must be in the range `[i, len(s) + 1]`.) If the call returns `true`, the match succeeds without consuming any input (so, to return true is equivalent to return `i`). If the call returns `false`, `nil`, or no value, the match fails. Any extra values returned by the function become the values produced by the capture.

Parameters:

`{patt}` (`vim.lpeg.Pattern|string|integer|boolean|table|function`)

`{fn}` (`fun(s: string, i: integer, ...: any)`) (position: boolean|integer, ...: any)

Return:

(`vim.lpeg.Capture`)

vim.lpeg.Cp() `vim.lpeg.Cp())` Creates a position capture. It matches the empty string and captures the position in the subject where the match occurs. The captured value is a number.

Example:

urltomarkdowncodeblockplaceholder1130.25685910275600277

Return:

(`vim.lpeg.Capture`)

vim.lpeg.Cs(`{patt}`) `vim.lpeg.Cs())` Creates a substitution capture. This function creates a substitution capture, which captures the substring of the subject that matches `patt`, with substitutions. For any capture inside `patt` with a value, the substring that matched the capture is replaced by the capture value (which should be a string). The final captured value is the string resulting from all replacements.

Example:

urltomarkdowncodeblockplaceholder1140.5942950184718667

Parameters:

`{patt}` (`vim.lpeg.Pattern|string|integer|boolean|table|function`)

Return:

(`vim.lpeg.Capture`)

vim.lpeg.Ct(`{patt}`) `vim.lpeg.Ct())` Creates a table capture. This capture returns a table with all values from all anonymous captures made by `patt` inside this table in successive integer keys, starting at 1. Moreover, for each named capture group created by `patt`, the first value of the group is put into the table with the group name as its key. The captured value is only the table.

Parameters:

`{patt}` (`vim.lpeg.Pattern|string|integer|boolean|table|function`)

Return:

(`vim.lpeg.Capture`)

vim.lpeg.locale(`{tab}`) `vim.lpeg.locale())` Returns a table with patterns for matching some character classes according to the current locale. The table has fields named `alnum`, `alpha`, `cntrl`, `digit`, `graph`, `lower`, `print`, `punct`, `space`, `upper`, and `xdigit`, each one containing a correspondent pattern. Each pattern matches any single character that belongs to its class. If called with an argument `table`, then it creates those fields inside the given table and returns that table.

Example:

urltomarkdowncodeblockplaceholder1150.27822418457785614

Parameters:

`{tab}` (`table?`)

Return:

(`vim.lpeg.Locale`)

vim.lpeg.match(`{pattern}`, `{subject}`, `{init}`, `{...}`) `vim.lpeg.match())` Matches the given `pattern` against the `subject` string. If the match succeeds, returns the index in the subject of the first character after the match, or the captured values (if the pattern captured any value). An optional numeric argument `init` makes the match start at that position in the subject string. As usual in Lua libraries, a negative value counts from the end. Unlike typical pattern-matching functions, `match` works only in anchored mode; that is, it tries to match the pattern with a prefix of the given subject string (at position `init`), not with an arbitrary substring of the subject. So, if we want to find a pattern anywhere in a string, we must either write a loop in Lua or write a pattern that matches anywhere.

Example:

urltomarkdowncodeblockplaceholder1160.2755921602208562

Parameters:

`{pattern}` (`vim.lpeg.Pattern|string|integer|boolean|table|function`)

`{subject}` (`string`)

`{init}` (`integer?`)

`{...}` (`any`)

vim.lpeg.P(`{value}`) `vim.lpeg.P())` Converts the given value into a proper pattern. The following rules are applied:

If the argument is a pattern, it is returned unmodified.

If the argument is a string, it is translated to a pattern that matches the string literally.

If the argument is a non-negative number `n`, the result is a pattern that matches exactly `n` characters.

If the argument is a negative number `-n`, the result is a pattern that succeeds only if the input string has less than `n` characters left: `lpeg.P(-n)` is equivalent to `-lpeg.P(n)` (see the unary minus operation).

If the argument is a boolean, the result is a pattern that always succeeds or always fails (according to the boolean value), without consuming any input.

If the argument is a table, it is interpreted as a grammar (see Grammars).

If the argument is a function, returns a pattern equivalent to a match-time capture over the empty string.

Parameters:

`{value}` (`vim.lpeg.Pattern|string|integer|boolean|table|function`)

Return:

(`vim.lpeg.Pattern`)

vim.lpeg.R(`{...}`) `vim.lpeg.R())` Returns a pattern that matches any single character belonging to one of the given ranges. Each `range` is a string `xy` of length 2, representing all characters with code between the codes of `x` and `y` (both inclusive). As an example, the pattern `lpeg.R('09')` matches any digit, and `lpeg.R('az', 'AZ')` matches any ASCII letter.

Example:

urltomarkdowncodeblockplaceholder1170.9390966826397653

Parameters:

`{...}` (`string`)

Return:

(`vim.lpeg.Pattern`)

vim.lpeg.S(`{string}`) `vim.lpeg.S())` Returns a pattern that matches any single character that appears in the given string (the `S` stands for Set). As an example, the pattern `lpeg.S('+-*/')` matches any arithmetic operator. Note that, if `s` is a character (that is, a string of length 1), then `lpeg.P(s)` is equivalent to `lpeg.S(s)` which is equivalent to `lpeg.R(s..s)`. Note also that both `lpeg.S('')` and `lpeg.R()` are patterns that always fail.

Parameters:

`{string}` (`string`)

Return:

(`vim.lpeg.Pattern`)

vim.lpeg.setmaxstack(`{max}`) `vim.lpeg.setmaxstack())` Sets a limit for the size of the backtrack stack used by LPeg to track calls and choices. The default limit is `400`. Most well-written patterns need little backtrack levels and therefore you seldom need to change this limit; before changing it you should try to rewrite your pattern to avoid the need for extra space. Nevertheless, a few useful patterns may overflow. Also, with recursive grammars, subjects with deep recursion may also need larger limits.

Parameters:

`{max}` (`integer`)

vim.lpeg.type(`{value}`) `vim.lpeg.type())` Returns the string `"pattern"` if the given value is a pattern, otherwise `nil`.

Parameters:

`{value}` (`vim.lpeg.Pattern|string|integer|boolean|table|function`)

vim.lpeg.V(`{v}`) `vim.lpeg.V())` Creates a non-terminal (a variable) for a grammar. This operation creates a non-terminal (a variable) for a grammar. The created non-terminal refers to the rule indexed by `v` in the enclosing grammar.

Example:

urltomarkdowncodeblockplaceholder1180.13563568348178512

Parameters:

`{v}` (`boolean|string|number|function|table|thread|userdata|lightuserdata`)

Return:

(`vim.lpeg.Pattern`)

vim.lpeg.version() `vim.lpeg.version())` Returns a string with the running version of LPeg.

VIM.RE vim.re
------------------------

The `vim.re` module provides a conventional regex-like syntax for pattern usage within LPeg vim.lpeg. (Unrelated to vim.regex which provides Vim regexp from Lua.)

vim.re.compile(`{string}`, `{defs}`) `vim.re.compile())` Compiles the given `{string}` and returns an equivalent LPeg pattern. The given string may define either an expression or a grammar. The optional `{defs}` table provides extra Lua values to be used by the pattern.

Parameters:

`{string}` (`string`)

`{defs}` (`table?`)

Return:

(`vim.lpeg.Pattern`)

vim.re.find(`{subject}`, `{pattern}`, `{init}`) `vim.re.find())` Searches the given `{pattern}` in the given `{subject}`. If it finds a match, returns the index where this occurrence starts and the index where it ends. Otherwise, returns nil.

An optional numeric argument `{init}` makes the search starts at that position in the subject string. As usual in Lua libraries, a negative value counts from the end.

Parameters:

`{subject}` (`string`)

`{pattern}` (`vim.lpeg.Pattern|string`)

`{init}` (`integer?`)

Return (multiple):

(`integer?`) the index where the occurrence starts, nil if no match (`integer?`) the index where the occurrence ends, nil if no match

vim.re.gsub(`{subject}`, `{pattern}`, `{replacement}`) `vim.re.gsub())` Does a global substitution, replacing all occurrences of `{pattern}` in the given `{subject}` by `{replacement}`.

Parameters:

`{subject}` (`string`)

`{pattern}` (`vim.lpeg.Pattern|string`)

`{replacement}` (`string`)

vim.re.match(`{subject}`, `{pattern}`, `{init}`) `vim.re.match())` Matches the given `{pattern}` against the given `{subject}`, returning all captures.

Parameters:

`{subject}` (`string`)

`{pattern}` (`vim.lpeg.Pattern|string`)

`{init}` (`integer?`)

Return:

(`integer|vim.lpeg.Capture?`)

See also:

vim.lpeg.match()

vim.re.updatelocale() `vim.re.updatelocale())` Updates the pre-defined character classes to the current locale.

VIM.REGEX vim.regex
---------------------------------

Vim regexes can be used directly from Lua. Currently they only allow matching within a single line.

`regex:match_line())` regex:match\_line(`{bufnr}`, `{line_idx}`, `{start}`, `{end_}`) Match line `{line_idx}` (zero-based) in buffer `{bufnr}`. If `{start}` and `{end}` are supplied, match only this byte index range. Otherwise see regex:match\_str()). If `{start}` is used, then the returned byte indices will be relative `{start}`.

Parameters:

`{bufnr}` (`integer`)

`{line_idx}` (`integer`)

`{start}` (`integer?`)

`{end_}` (`integer?`)

regex:match\_str(`{str}`) `regex:match_str())` Match the string against the regex. If the string should match the regex precisely, surround the regex with `^` and `$`. If there was a match, the byte indices for the beginning and end of the match are returned. When there is no match, `nil` is returned. Because any integer is "truthy", `regex:match_str()` can be directly used as a condition in an if-statement.

Parameters:

`{str}` (`string`)

vim.regex(`{re}`) `vim.regex())` Parse the Vim regex `{re}` and return a regex object. Regexes are "magic" and case-sensitive by default, regardless of 'magic' and 'ignorecase'. They can be controlled with flags, see /magic and /ignorecase.

Parameters:

`{re}` (`string`)

Lua module: vim.secure vim.secure
------------------------------------------------

vim.secure.read(`{path}`) `vim.secure.read())` Attempt to read the file at `{path}` prompting the user if the file should be trusted. The user's choice is persisted in a trust database at $XDG\_STATE\_HOME/nvim/trust.

Parameters:

`{path}` (`string`) Path to a file to read.

Return:

(`string?`) The contents of the given file if it exists and is trusted, or nil otherwise.

vim.secure.trust(`{opts}`) `vim.secure.trust())` Manage the trust database.

Parameters:

`{opts}` (`table`) A table with the following fields:

`{action}` (`'allow'|'deny'|'remove'`) - `'allow'` to add a file to the trust database and trust it,

`'deny'` to add a file to the trust database and deny it,

`'remove'` to remove file from the trust database

`{path}` (`string`) Path to a file to update. Mutually exclusive with `{bufnr}`. Cannot be used when `{action}` is "allow".

`{bufnr}` (`integer`) Buffer number to update. Mutually exclusive with `{path}`.

Return (multiple):

(`boolean`) success true if operation was successful (`string`) msg full path if operation was successful, else error message

Lua module: vim.version vim.version
---------------------------------------------------

The `vim.version` module provides functions for comparing versions and ranges conforming to the https://semver.org spec. Plugins, and plugin managers, can use this to check available tools and dependencies on the current system.

Example:

urltomarkdowncodeblockplaceholder1190.5142593430246558

`vim.version())` returns the version of the current Nvim process.

### VERSION RANGE SPEC version-range

A version "range spec" defines a semantic version range which can be tested against a version, using vim.version.range()).

Supported range specs are shown in the following table. **Note:** suffixed versions (1.2.3-rc1) are not matched.

urltomarkdowncodeblockplaceholder1200.7223213142199674

vim.version.cmp(`{v1}`, `{v2}`) `vim.version.cmp())` Parses and compares two version objects (the result of vim.version.parse()), or specified literally as a `{major, minor, patch}` tuple, e.g. `{1, 0, 3}`).

Example:

urltomarkdowncodeblockplaceholder1210.8117634004505074

**Note:**

Per semver, build metadata is ignored when comparing two otherwise-equivalent versions.

Parameters:

`{v1}` (`vim.Version|number[]|string`) Version object.

`{v2}` (`vim.Version|number[]|string`) Version to compare with `v1`.

Return:

(`integer`) -1 if `v1 < v2`, 0 if `v1 == v2`, 1 if `v1 > v2`.

vim.version.eq(`{v1}`, `{v2}`) `vim.version.eq())` Returns `true` if the given versions are equal. See vim.version.cmp()) for usage.

Parameters:

`{v1}` (`vim.Version|number[]|string`)

`{v2}` (`vim.Version|number[]|string`)

vim.version.ge(`{v1}`, `{v2}`) `vim.version.ge())` Returns `true` if `v1 >= v2`. See vim.version.cmp()) for usage.

Parameters:

`{v1}` (`vim.Version|number[]|string`)

`{v2}` (`vim.Version|number[]|string`)

vim.version.gt(`{v1}`, `{v2}`) `vim.version.gt())` Returns `true` if `v1 > v2`. See vim.version.cmp()) for usage.

Parameters:

`{v1}` (`vim.Version|number[]|string`)

`{v2}` (`vim.Version|number[]|string`)

vim.version.last(`{versions}`) `vim.version.last())` TODO: generalize this, move to func.lua

Parameters:

`{versions}` (`vim.Version[]`)

vim.version.le(`{v1}`, `{v2}`) `vim.version.le())` Returns `true` if `v1 <= v2`. See vim.version.cmp()) for usage.

Parameters:

`{v1}` (`vim.Version|number[]|string`)

`{v2}` (`vim.Version|number[]|string`)

vim.version.lt(`{v1}`, `{v2}`) `vim.version.lt())` Returns `true` if `v1 < v2`. See vim.version.cmp()) for usage.

Parameters:

`{v1}` (`vim.Version|number[]|string`)

`{v2}` (`vim.Version|number[]|string`)

vim.version.parse(`{version}`, `{opts}`) `vim.version.parse())` Parses a semantic version string and returns a version object which can be used with other `vim.version` functions. For example "1.0.1-rc1+build.2" returns:

urltomarkdowncodeblockplaceholder1220.7310950514156884

Parameters:

`{version}` (`string`) Version string to parse.

`{opts}` (`table?`) Optional keyword arguments:

strict (boolean): Default false. If `true`, no coercion is attempted on input not conforming to semver v2.0.0. If `false`, `parse()` attempts to coerce input such as "1.0", "0-x", "tmux 3.2a" into valid versions.

Return:

(`vim.Version?`) parsed\_version Version object or `nil` if input is invalid.

vim.version.range(`{spec}`) `vim.version.range())` Parses a semver version-range "spec" and returns a range object:

urltomarkdowncodeblockplaceholder1230.5951471239041548

`:has()` checks if a version is in the range (inclusive `from`, exclusive `to`).

Example:

urltomarkdowncodeblockplaceholder1240.7425585526121159

Or use cmp(), le(), lt(), ge(), gt(), and/or eq() to compare a version against `.to` and `.from` directly:

urltomarkdowncodeblockplaceholder1250.9468612466711352

Parameters:

`{spec}` (`string`) Version range "spec"

Return:

(`table?`) A table with the following fields:

`{from}` (`vim.Version`)

`{to}` (`vim.Version`)

Lua module: vim.iter vim.iter
------------------------------------------

`vim.iter())` is an interface for iterables: it wraps a table or function argument into an `Iter` object with methods (such as Iter:filter()) and Iter:map())) that transform the underlying source data. These methods can be chained to create iterator "pipelines": the output of each pipeline stage is input to the next stage. The first stage depends on the type passed to `vim.iter()`:

Lists or arrays (lua-list) yield only the value of each element.

Holes (nil values) are allowed (but discarded).

Use pairs() to treat array/list tables as dicts (preserve holes and non-contiguous integer keys): `vim.iter(pairs(…))`.

Or initialize with ipairs(): `vim.iter(ipairs(…))`.

Non-list tables (lua-dict) yield both the key and value of each element.

Function iterators yield all values returned by the underlying function.

Tables with a \_\_call()) metamethod are treated as function iterators.

The iterator pipeline terminates when the underlying iterable is exhausted (for function iterators this means it returned nil).

**Note:** `vim.iter()` scans table input to decide if it is a list or a dict; to avoid this cost you can wrap the table with an iterator e.g. `vim.iter(ipairs({…}))`, but that precludes the use of list-iterator operations such as Iter:rev())).

Examples:

urltomarkdowncodeblockplaceholder1260.7448762593798892

Iter:all(`{pred}`) `Iter:all())` Returns true if all items in the iterator match the given predicate.

Parameters:

`{pred}` (`fun(...):boolean`) Predicate function. Takes all values returned from the previous stage in the pipeline as arguments and returns true if the predicate matches.

Iter:any(`{pred}`) `Iter:any())` Returns true if any of the items in the iterator match the given predicate.

Parameters:

`{pred}` (`fun(...):boolean`) Predicate function. Takes all values returned from the previous stage in the pipeline as arguments and returns true if the predicate matches.

Iter:each(`{f}`) `Iter:each())` Calls a function once for each item in the pipeline, draining the iterator.

For functions with side effects. To modify the values in the iterator, use Iter:map()).

Parameters:

`{f}` (`fun(...)`) Function to execute for each item in the pipeline. Takes all of the values returned by the previous stage in the pipeline as arguments.

Iter:enumerate() `Iter:enumerate())` Yields the item index (count) and value for each item of an iterator pipeline.

For list tables, this is more efficient:

urltomarkdowncodeblockplaceholder1270.589941484771854

instead of:

urltomarkdowncodeblockplaceholder1280.9777426514684822

Example:

urltomarkdowncodeblockplaceholder1290.377702004265434

Iter:filter(`{f}`) `Iter:filter())` Filters an iterator pipeline.

Example:

urltomarkdowncodeblockplaceholder1300.24506147403797884

Parameters:

`{f}` (`fun(...):boolean`) Takes all values returned from the previous stage in the pipeline and returns false or nil if the current iterator element should be removed.

Iter:find(`{f}`) `Iter:find())` Find the first value in the iterator that satisfies the given predicate.

Advances the iterator. Returns nil and drains the iterator if no value is found.

Examples:

urltomarkdowncodeblockplaceholder1310.17152374512369795

Iter:flatten(`{depth}`) `Iter:flatten())` Flattens a list-iterator, un-nesting nested values up to the given `{depth}`. Errors if it attempts to flatten a dict-like value.

Examples:

urltomarkdowncodeblockplaceholder1320.8407398175587595

Parameters:

`{depth}` (`number?`) Depth to which list-iterator should be flattened (defaults to 1)

Iter:fold(`{init}`, `{f}`) `Iter:fold())` Folds ("reduces") an iterator into a single value. `Iter:reduce())`

Examples:

urltomarkdowncodeblockplaceholder1330.6204365948339325

Parameters:

`{init}` (`any`) Initial value of the accumulator.

`{f}` (`fun(acc:A, ...):A`) Accumulation function.

Iter:join(`{delim}`) `Iter:join())` Collect the iterator into a delimited string.

Each element in the iterator is joined into a string separated by `{delim}`.

Consumes the iterator.

Parameters:

`{delim}` (`string`) Delimiter

Iter:last() `Iter:last())` Drains the iterator and returns the last item.

Example:

urltomarkdowncodeblockplaceholder1340.868519376834646

Iter:map(`{f}`) `Iter:map())` Maps the items of an iterator pipeline to the values returned by `f`.

If the map function returns nil, the value is filtered from the iterator.

Example:

urltomarkdowncodeblockplaceholder1350.11589626835648748

Parameters:

`{f}` (`fun(...):...:any`) Mapping function. Takes all values returned from the previous stage in the pipeline as arguments and returns one or more new values, which are used in the next pipeline stage. Nil return values are filtered from the output.

Iter:next() `Iter:next())` Gets the next value from the iterator.

Example:

urltomarkdowncodeblockplaceholder1360.7497388702225476

Iter:nth(`{n}`) `Iter:nth())` Gets the nth value of an iterator (and advances to it).

If `n` is negative, offsets from the end of a list-iterator.

Example:

urltomarkdowncodeblockplaceholder1370.12201413394633809

Parameters:

`{n}` (`number`) Index of the value to return. May be negative if the source is a list-iterator.

Iter:peek() `Iter:peek())` Gets the next value in a list-iterator without consuming it.

Example:

urltomarkdowncodeblockplaceholder1380.6120792908547625

Iter:pop() `Iter:pop())` "Pops" a value from a list-iterator (gets the last value and decrements the tail).

Example:

urltomarkdowncodeblockplaceholder1390.956725056935767

Example:

urltomarkdowncodeblockplaceholder1400.7556401086826683

Iter:rfind(`{f}`) `Iter:rfind())` Gets the first value satisfying a predicate, from the end of a list-iterator.

Advances the iterator. Returns nil and drains the iterator if no value is found.

Examples:

urltomarkdowncodeblockplaceholder1410.31779031676866176

Iter:rpeek() `Iter:rpeek())` Gets the last value of a list-iterator without consuming it.

Example:

urltomarkdowncodeblockplaceholder1420.4784821171025462

Iter:rskip(`{n}`) `Iter:rskip())` Discards `n` values from the end of a list-iterator pipeline.

Example:

urltomarkdowncodeblockplaceholder1430.3657723025029076

Parameters:

`{n}` (`number`) Number of values to skip.

Iter:skip(`{n}`) `Iter:skip())` Skips `n` values of an iterator pipeline.

Example:

urltomarkdowncodeblockplaceholder1440.3762470817003154

Parameters:

`{n}` (`number`) Number of values to skip.

Iter:slice(`{first}`, `{last}`) `Iter:slice())` Sets the start and end of a list-iterator pipeline.

Equivalent to `:skip(first - 1):rskip(len - last + 1)`.

Parameters:

`{first}` (`number`)

`{last}` (`number`)

Iter:take(`{n}`) `Iter:take())` Transforms an iterator to yield only the first n values.

Example:

urltomarkdowncodeblockplaceholder1450.6384961151172754

Parameters:

`{n}` (`integer`)

Iter:totable() `Iter:totable())` Collect the iterator into a table.

The resulting table depends on the initial source in the iterator pipeline. Array-like tables and function iterators will be collected into an array-like table. If multiple values are returned from the final stage in the iterator pipeline, each value will be included in a table.

Examples:

urltomarkdowncodeblockplaceholder1460.5596784708954385

The generated table is an array-like table with consecutive, numeric indices. To create a map-like table with arbitrary keys, use Iter:fold()).

Lua module: vim.snippet vim.snippet
---------------------------------------------------

Fields:

`{direction}` (`vim.snippet.Direction`) Navigation direction. -1 for previous, 1 for next.

vim.snippet.active(`{filter}`) `vim.snippet.active())` Returns `true` if there's an active snippet in the current buffer, applying the given filter if provided.

You can use this function to navigate a snippet as follows:

urltomarkdowncodeblockplaceholder1470.9129194941022836

Parameters:

`{filter}` (`vim.snippet.ActiveFilter?`) Filter to constrain the search with:

`direction` (vim.snippet.Direction): Navigation direction. Will return `true` if the snippet can be jumped in the given direction. See vim.snippet.ActiveFilter.

Parameters:

`{input}` (`string`)

vim.snippet.jump(`{direction}`) `vim.snippet.jump())` Jumps to the next (or previous) placeholder in the current snippet, if possible.

For example, map `<Tab>` to jump while a snippet is active:

urltomarkdowncodeblockplaceholder1480.38914287342945175

Parameters:

`{direction}` (`vim.snippet.Direction`) Navigation direction. -1 for previous, 1 for next.

vim.snippet.stop() `vim.snippet.stop())` Exits the current snippet.

Lua module: vim.text vim.text
------------------------------------------

vim.text.hexdecode(`{enc}`) `vim.text.hexdecode())` Hex decode a string.

Parameters:

`{enc}` (`string`) String to decode

Return (multiple):

(`string?`) Decoded string (`string?`) Error message, if any

vim.text.hexencode(`{str}`) `vim.text.hexencode())` Hex encode a string.

Parameters:

`{str}` (`string`) String to encode

Return:

(`string`) Hex encoded string

Lua module: tohtml vim.tohtml
--------------------------------------------

:\[range\]TOhtml `{file}` `:TOhtml` Converts the buffer shown in the current window to HTML, opens the generated HTML in a new split window, and saves its contents to `{file}`. If `{file}` is not given, a temporary file (created by tempname())) is used.

tohtml.tohtml(`{winid}`, `{opt}`) `tohtml.tohtml.tohtml())` Converts the buffer shown in the window `{winid}` to HTML and returns the output as a list of string.

Parameters:

`{winid}` (`integer?`) Window to convert (defaults to current window)

`{opt}` (`table?`) Optional parameters.

`{title}` (`string|false`, default: buffer name) Title tag to set in the generated HTML code.

`{number_lines}` (`boolean`, default: `false`) Show line numbers.

`{font}` (`string[]|string`, default: `guifont`) Fonts to use.

`{width}` (`integer`, default: 'textwidth' if non-zero or window width otherwise) Width used for items which are either right aligned or repeat a character infinitely.

`{range}` (`integer[]`, default: entire buffer) Range of rows to use.) ~= nil
end)
```

Parameters:

`{source}` (`integer|string`) Buffer number (0 for current buffer) or file path (absolute or relative to the current-directory) to begin the search from.

`{marker}` (`string|string[]|fun(name: string, path: string): boolean`) A marker, or list of markers, to search for. If a function, the function is called for each evaluated item and should return true if `{name}` and `{path}` are a match.

Return:

(`string?`) Directory path containing one of the given markers, or nil if no directory was found.

Lua module: vim.glob vim.glob
------------------------------------------

vim.glob.to\_lpeg(`{pattern}`) `vim.glob.to_lpeg())` Parses a raw glob into an lua-lpeg pattern.

Glob patterns can have the following syntax:

`*` to match one or more characters in a path segment

`?` to match on one character in a path segment

`**` to match any number of path segments, including none

`{}` to group conditions (e.g. `*.{ts,js}` matches TypeScript and JavaScript files)

`[]` to declare a range of characters to match in a path segment (e.g., `example.[0-9]` to match on `example.0`, `example.1`, …)

`[!...]` to negate a range of characters to match in a path segment (e.g., `example.[!0-9]` to match on `example.a`, `example.b`, but not `example.0`)

Parameters:

`{pattern}` (`string`) The raw glob pattern

Return:

(`vim.lpeg.Pattern`) pattern An lua-lpeg representation of the pattern

VIM.LPEG vim.lpeg
------------------------------

LPeg is a pattern-matching library for Lua, based on Parsing Expression Grammars (PEGs). <https://bford.info/packrat/>

Pattern:match(`{subject}`, `{init}`, `{...}`) `Pattern:match())` Matches the given `pattern` against the `subject` string. If the match succeeds, returns the index in the subject of the first character after the match, or the captured values (if the pattern captured any value). An optional numeric argument `init` makes the match start at that position in the subject string. As usual in Lua libraries, a negative value counts from the end. Unlike typical pattern-matching functions, `match` works only in anchored mode; that is, it tries to match the pattern with a prefix of the given subject string (at position `init`), not with an arbitrary substring of the subject. So, if we want to find a pattern anywhere in a string, we must either write a loop in Lua or write a pattern that matches anywhere.

Example:

urltomarkdowncodeblockplaceholder1100.7752549996783569

Parameters:

`{subject}` (`string`)

`{init}` (`integer?`)

`{...}` (`any`)

vim.lpeg.B(`{pattern}`) `vim.lpeg.B())` Returns a pattern that matches only if the input string at the current position is preceded by `patt`. Pattern `patt` must match only strings with some fixed length, and it cannot contain captures. Like the `and` predicate, this pattern never consumes any input, independently of success or failure.

Parameters:

`{pattern}` (`vim.lpeg.Pattern|string|integer|boolean|table`)

Return:

(`vim.lpeg.Pattern`)

vim.lpeg.C(`{patt}`) `vim.lpeg.C())` Creates a simple capture, which captures the substring of the subject that matches `patt`. The captured value is a string. If `patt` has other captures, their values are returned after this one.

Example:

urltomarkdowncodeblockplaceholder1110.2241242272539854

Parameters:

`{patt}` (`vim.lpeg.Pattern|string|integer|boolean|table|function`)

Return:

(`vim.lpeg.Capture`)

vim.lpeg.Carg(`{n}`) `vim.lpeg.Carg())` Creates an argument capture. This pattern matches the empty string and produces the value given as the nth extra argument given in the call to `lpeg.match`.

Parameters:

`{n}` (`integer`)

Return:

(`vim.lpeg.Capture`)

vim.lpeg.Cb(`{name}`) `vim.lpeg.Cb())` Creates a back capture. This pattern matches the empty string and produces the values produced by the most recent group capture named `name` (where `name` can be any Lua value). Most recent means the last complete outermost group capture with the given name. A Complete capture means that the entire pattern corresponding to the capture has matched. An Outermost capture means that the capture is not inside another complete capture. In the same way that LPeg does not specify when it evaluates captures, it does not specify whether it reuses values previously produced by the group or re-evaluates them.

Return:

(`vim.lpeg.Capture`)

vim.lpeg.Cc(`{...}`) `vim.lpeg.Cc())` Creates a constant capture. This pattern matches the empty string and produces all given values as its captured values.

Return:

(`vim.lpeg.Capture`)

vim.lpeg.Cf(`{patt}`, `{func}`) `vim.lpeg.Cf())` Creates a fold capture. If `patt` produces a list of captures C1 C2 ... Cn, this capture will produce the value `func(...func(func(C1, C2), C3)...,Cn)`, that is, it will fold (or accumulate, or reduce) the captures from `patt` using function `func`. This capture assumes that `patt` should produce at least one capture with at least one value (of any type), which becomes the initial value of an accumulator. (If you need a specific initial value, you may prefix a constant capture to `patt`.) For each subsequent capture, LPeg calls `func` with this accumulator as the first argument and all values produced by the capture as extra arguments; the first result from this call becomes the new value for the accumulator. The final value of the accumulator becomes the captured value.

Example:

urltomarkdowncodeblockplaceholder1120.17046473394432948

Parameters:

`{patt}` (`vim.lpeg.Pattern|string|integer|boolean|table|function`)

`{func}` (`fun(acc, newvalue)`)

Return:

(`vim.lpeg.Capture`)

vim.lpeg.Cg(`{patt}`, `{name}`) `vim.lpeg.Cg())` Creates a group capture. It groups all values returned by `patt` into a single capture. The group may be anonymous (if no name is given) or named with the given name (which can be any non-nil Lua value).

Parameters:

`{patt}` (`vim.lpeg.Pattern|string|integer|boolean|table|function`)

`{name}` (`string?`)

Return:

(`vim.lpeg.Capture`)

vim.lpeg.Cmt(`{patt}`, `{fn}`) `vim.lpeg.Cmt())` Creates a match-time capture. Unlike all other captures, this one is evaluated immediately when a match occurs (even if it is part of a larger pattern that fails later). It forces the immediate evaluation of all its nested captures and then calls `function`. The given function gets as arguments the entire subject, the current position (after the match of `patt`), plus any capture values produced by `patt`. The first value returned by `function` defines how the match happens. If the call returns a number, the match succeeds and the returned number becomes the new current position. (Assuming a subject sand current position `i`, the returned number must be in the range `[i, len(s) + 1]`.) If the call returns `true`, the match succeeds without consuming any input (so, to return true is equivalent to return `i`). If the call returns `false`, `nil`, or no value, the match fails. Any extra values returned by the function become the values produced by the capture.

Parameters:

`{patt}` (`vim.lpeg.Pattern|string|integer|boolean|table|function`)

`{fn}` (`fun(s: string, i: integer, ...: any)`) (position: boolean|integer, ...: any)

Return:

(`vim.lpeg.Capture`)

vim.lpeg.Cp() `vim.lpeg.Cp())` Creates a position capture. It matches the empty string and captures the position in the subject where the match occurs. The captured value is a number.

Example:

urltomarkdowncodeblockplaceholder1130.25685910275600277

Return:

(`vim.lpeg.Capture`)

vim.lpeg.Cs(`{patt}`) `vim.lpeg.Cs())` Creates a substitution capture. This function creates a substitution capture, which captures the substring of the subject that matches `patt`, with substitutions. For any capture inside `patt` with a value, the substring that matched the capture is replaced by the capture value (which should be a string). The final captured value is the string resulting from all replacements.

Example:

urltomarkdowncodeblockplaceholder1140.5942950184718667

Parameters:

`{patt}` (`vim.lpeg.Pattern|string|integer|boolean|table|function`)

Return:

(`vim.lpeg.Capture`)

vim.lpeg.Ct(`{patt}`) `vim.lpeg.Ct())` Creates a table capture. This capture returns a table with all values from all anonymous captures made by `patt` inside this table in successive integer keys, starting at 1. Moreover, for each named capture group created by `patt`, the first value of the group is put into the table with the group name as its key. The captured value is only the table.

Parameters:

`{patt}` (`vim.lpeg.Pattern|string|integer|boolean|table|function`)

Return:

(`vim.lpeg.Capture`)

vim.lpeg.locale(`{tab}`) `vim.lpeg.locale())` Returns a table with patterns for matching some character classes according to the current locale. The table has fields named `alnum`, `alpha`, `cntrl`, `digit`, `graph`, `lower`, `print`, `punct`, `space`, `upper`, and `xdigit`, each one containing a correspondent pattern. Each pattern matches any single character that belongs to its class. If called with an argument `table`, then it creates those fields inside the given table and returns that table.

Example:

urltomarkdowncodeblockplaceholder1150.27822418457785614

Parameters:

`{tab}` (`table?`)

Return:

(`vim.lpeg.Locale`)

vim.lpeg.match(`{pattern}`, `{subject}`, `{init}`, `{...}`) `vim.lpeg.match())` Matches the given `pattern` against the `subject` string. If the match succeeds, returns the index in the subject of the first character after the match, or the captured values (if the pattern captured any value). An optional numeric argument `init` makes the match start at that position in the subject string. As usual in Lua libraries, a negative value counts from the end. Unlike typical pattern-matching functions, `match` works only in anchored mode; that is, it tries to match the pattern with a prefix of the given subject string (at position `init`), not with an arbitrary substring of the subject. So, if we want to find a pattern anywhere in a string, we must either write a loop in Lua or write a pattern that matches anywhere.

Example:

urltomarkdowncodeblockplaceholder1160.2755921602208562

Parameters:

`{pattern}` (`vim.lpeg.Pattern|string|integer|boolean|table|function`)

`{subject}` (`string`)

`{init}` (`integer?`)

`{...}` (`any`)

vim.lpeg.P(`{value}`) `vim.lpeg.P())` Converts the given value into a proper pattern. The following rules are applied:

If the argument is a pattern, it is returned unmodified.

If the argument is a string, it is translated to a pattern that matches the string literally.

If the argument is a non-negative number `n`, the result is a pattern that matches exactly `n` characters.

If the argument is a negative number `-n`, the result is a pattern that succeeds only if the input string has less than `n` characters left: `lpeg.P(-n)` is equivalent to `-lpeg.P(n)` (see the unary minus operation).

If the argument is a boolean, the result is a pattern that always succeeds or always fails (according to the boolean value), without consuming any input.

If the argument is a table, it is interpreted as a grammar (see Grammars).

If the argument is a function, returns a pattern equivalent to a match-time capture over the empty string.

Parameters:

`{value}` (`vim.lpeg.Pattern|string|integer|boolean|table|function`)

Return:

(`vim.lpeg.Pattern`)

vim.lpeg.R(`{...}`) `vim.lpeg.R())` Returns a pattern that matches any single character belonging to one of the given ranges. Each `range` is a string `xy` of length 2, representing all characters with code between the codes of `x` and `y` (both inclusive). As an example, the pattern `lpeg.R('09')` matches any digit, and `lpeg.R('az', 'AZ')` matches any ASCII letter.

Example:

urltomarkdowncodeblockplaceholder1170.9390966826397653

Parameters:

`{...}` (`string`)

Return:

(`vim.lpeg.Pattern`)

vim.lpeg.S(`{string}`) `vim.lpeg.S())` Returns a pattern that matches any single character that appears in the given string (the `S` stands for Set). As an example, the pattern `lpeg.S('+-*/')` matches any arithmetic operator. Note that, if `s` is a character (that is, a string of length 1), then `lpeg.P(s)` is equivalent to `lpeg.S(s)` which is equivalent to `lpeg.R(s..s)`. Note also that both `lpeg.S('')` and `lpeg.R()` are patterns that always fail.

Parameters:

`{string}` (`string`)

Return:

(`vim.lpeg.Pattern`)

vim.lpeg.setmaxstack(`{max}`) `vim.lpeg.setmaxstack())` Sets a limit for the size of the backtrack stack used by LPeg to track calls and choices. The default limit is `400`. Most well-written patterns need little backtrack levels and therefore you seldom need to change this limit; before changing it you should try to rewrite your pattern to avoid the need for extra space. Nevertheless, a few useful patterns may overflow. Also, with recursive grammars, subjects with deep recursion may also need larger limits.

Parameters:

`{max}` (`integer`)

vim.lpeg.type(`{value}`) `vim.lpeg.type())` Returns the string `"pattern"` if the given value is a pattern, otherwise `nil`.

Parameters:

`{value}` (`vim.lpeg.Pattern|string|integer|boolean|table|function`)

vim.lpeg.V(`{v}`) `vim.lpeg.V())` Creates a non-terminal (a variable) for a grammar. This operation creates a non-terminal (a variable) for a grammar. The created non-terminal refers to the rule indexed by `v` in the enclosing grammar.

Example:

urltomarkdowncodeblockplaceholder1180.13563568348178512

Parameters:

`{v}` (`boolean|string|number|function|table|thread|userdata|lightuserdata`)

Return:

(`vim.lpeg.Pattern`)

vim.lpeg.version() `vim.lpeg.version())` Returns a string with the running version of LPeg.

VIM.RE vim.re
------------------------

The `vim.re` module provides a conventional regex-like syntax for pattern usage within LPeg vim.lpeg. (Unrelated to vim.regex which provides Vim regexp from Lua.)

vim.re.compile(`{string}`, `{defs}`) `vim.re.compile())` Compiles the given `{string}` and returns an equivalent LPeg pattern. The given string may define either an expression or a grammar. The optional `{defs}` table provides extra Lua values to be used by the pattern.

Parameters:

`{string}` (`string`)

`{defs}` (`table?`)

Return:

(`vim.lpeg.Pattern`)

vim.re.find(`{subject}`, `{pattern}`, `{init}`) `vim.re.find())` Searches the given `{pattern}` in the given `{subject}`. If it finds a match, returns the index where this occurrence starts and the index where it ends. Otherwise, returns nil.

An optional numeric argument `{init}` makes the search starts at that position in the subject string. As usual in Lua libraries, a negative value counts from the end.

Parameters:

`{subject}` (`string`)

`{pattern}` (`vim.lpeg.Pattern|string`)

`{init}` (`integer?`)

Return (multiple):

(`integer?`) the index where the occurrence starts, nil if no match (`integer?`) the index where the occurrence ends, nil if no match

vim.re.gsub(`{subject}`, `{pattern}`, `{replacement}`) `vim.re.gsub())` Does a global substitution, replacing all occurrences of `{pattern}` in the given `{subject}` by `{replacement}`.

Parameters:

`{subject}` (`string`)

`{pattern}` (`vim.lpeg.Pattern|string`)

`{replacement}` (`string`)

vim.re.match(`{subject}`, `{pattern}`, `{init}`) `vim.re.match())` Matches the given `{pattern}` against the given `{subject}`, returning all captures.

Parameters:

`{subject}` (`string`)

`{pattern}` (`vim.lpeg.Pattern|string`)

`{init}` (`integer?`)

Return:

(`integer|vim.lpeg.Capture?`)

See also:

vim.lpeg.match()

vim.re.updatelocale() `vim.re.updatelocale())` Updates the pre-defined character classes to the current locale.

VIM.REGEX vim.regex
---------------------------------

Vim regexes can be used directly from Lua. Currently they only allow matching within a single line.

`regex:match_line())` regex:match\_line(`{bufnr}`, `{line_idx}`, `{start}`, `{end_}`) Match line `{line_idx}` (zero-based) in buffer `{bufnr}`. If `{start}` and `{end}` are supplied, match only this byte index range. Otherwise see regex:match\_str()). If `{start}` is used, then the returned byte indices will be relative `{start}`.

Parameters:

`{bufnr}` (`integer`)

`{line_idx}` (`integer`)

`{start}` (`integer?`)

`{end_}` (`integer?`)

regex:match\_str(`{str}`) `regex:match_str())` Match the string against the regex. If the string should match the regex precisely, surround the regex with `^` and `$`. If there was a match, the byte indices for the beginning and end of the match are returned. When there is no match, `nil` is returned. Because any integer is "truthy", `regex:match_str()` can be directly used as a condition in an if-statement.

Parameters:

`{str}` (`string`)

vim.regex(`{re}`) `vim.regex())` Parse the Vim regex `{re}` and return a regex object. Regexes are "magic" and case-sensitive by default, regardless of 'magic' and 'ignorecase'. They can be controlled with flags, see /magic and /ignorecase.

Parameters:

`{re}` (`string`)

Lua module: vim.secure vim.secure
------------------------------------------------

vim.secure.read(`{path}`) `vim.secure.read())` Attempt to read the file at `{path}` prompting the user if the file should be trusted. The user's choice is persisted in a trust database at $XDG\_STATE\_HOME/nvim/trust.

Parameters:

`{path}` (`string`) Path to a file to read.

Return:

(`string?`) The contents of the given file if it exists and is trusted, or nil otherwise.

vim.secure.trust(`{opts}`) `vim.secure.trust())` Manage the trust database.

Parameters:

`{opts}` (`table`) A table with the following fields:

`{action}` (`'allow'|'deny'|'remove'`) - `'allow'` to add a file to the trust database and trust it,

`'deny'` to add a file to the trust database and deny it,

`'remove'` to remove file from the trust database

`{path}` (`string`) Path to a file to update. Mutually exclusive with `{bufnr}`. Cannot be used when `{action}` is "allow".

`{bufnr}` (`integer`) Buffer number to update. Mutually exclusive with `{path}`.

Return (multiple):

(`boolean`) success true if operation was successful (`string`) msg full path if operation was successful, else error message

Lua module: vim.version vim.version
---------------------------------------------------

The `vim.version` module provides functions for comparing versions and ranges conforming to the <https://semver.org> spec. Plugins, and plugin managers, can use this to check available tools and dependencies on the current system.

Example:

urltomarkdowncodeblockplaceholder1190.5142593430246558

`vim.version())` returns the version of the current Nvim process.

### VERSION RANGE SPEC version-range

A version "range spec" defines a semantic version range which can be tested against a version, using vim.version.range()).

Supported range specs are shown in the following table. **Note:** suffixed versions (1.2.3-rc1) are not matched.

urltomarkdowncodeblockplaceholder1200.7223213142199674

vim.version.cmp(`{v1}`, `{v2}`) `vim.version.cmp())` Parses and compares two version objects (the result of vim.version.parse()), or specified literally as a `{major, minor, patch}` tuple, e.g. `{1, 0, 3}`).

Example:

urltomarkdowncodeblockplaceholder1210.8117634004505074

**Note:**

Per semver, build metadata is ignored when comparing two otherwise-equivalent versions.

Parameters:

`{v1}` (`vim.Version|number[]|string`) Version object.

`{v2}` (`vim.Version|number[]|string`) Version to compare with `v1`.

Return:

(`integer`) -1 if `v1 < v2`, 0 if `v1 == v2`, 1 if `v1 > v2`.

vim.version.eq(`{v1}`, `{v2}`) `vim.version.eq())` Returns `true` if the given versions are equal. See vim.version.cmp()) for usage.

Parameters:

`{v1}` (`vim.Version|number[]|string`)

`{v2}` (`vim.Version|number[]|string`)

vim.version.ge(`{v1}`, `{v2}`) `vim.version.ge())` Returns `true` if `v1 >= v2`. See vim.version.cmp()) for usage.

Parameters:

`{v1}` (`vim.Version|number[]|string`)

`{v2}` (`vim.Version|number[]|string`)

vim.version.gt(`{v1}`, `{v2}`) `vim.version.gt())` Returns `true` if `v1 > v2`. See vim.version.cmp()) for usage.

Parameters:

`{v1}` (`vim.Version|number[]|string`)

`{v2}` (`vim.Version|number[]|string`)

vim.version.last(`{versions}`) `vim.version.last())` TODO: generalize this, move to func.lua

Parameters:

`{versions}` (`vim.Version[]`)

vim.version.le(`{v1}`, `{v2}`) `vim.version.le())` Returns `true` if `v1 <= v2`. See vim.version.cmp()) for usage.

Parameters:

`{v1}` (`vim.Version|number[]|string`)

`{v2}` (`vim.Version|number[]|string`)

vim.version.lt(`{v1}`, `{v2}`) `vim.version.lt())` Returns `true` if `v1 < v2`. See vim.version.cmp()) for usage.

Parameters:

`{v1}` (`vim.Version|number[]|string`)

`{v2}` (`vim.Version|number[]|string`)

vim.version.parse(`{version}`, `{opts}`) `vim.version.parse())` Parses a semantic version string and returns a version object which can be used with other `vim.version` functions. For example "1.0.1-rc1+build.2" returns:

urltomarkdowncodeblockplaceholder1220.7310950514156884

Parameters:

`{version}` (`string`) Version string to parse.

`{opts}` (`table?`) Optional keyword arguments:

strict (boolean): Default false. If `true`, no coercion is attempted on input not conforming to semver v2.0.0. If `false`, `parse()` attempts to coerce input such as "1.0", "0-x", "tmux 3.2a" into valid versions.

Return:

(`vim.Version?`) parsed\_version Version object or `nil` if input is invalid.

vim.version.range(`{spec}`) `vim.version.range())` Parses a semver version-range "spec" and returns a range object:

urltomarkdowncodeblockplaceholder1230.5951471239041548

`:has()` checks if a version is in the range (inclusive `from`, exclusive `to`).

Example:

urltomarkdowncodeblockplaceholder1240.7425585526121159

Or use cmp(), le(), lt(), ge(), gt(), and/or eq() to compare a version against `.to` and `.from` directly:

urltomarkdowncodeblockplaceholder1250.9468612466711352

Parameters:

`{spec}` (`string`) Version range "spec"

Return:

(`table?`) A table with the following fields:

`{from}` (`vim.Version`)

`{to}` (`vim.Version`)

Lua module: vim.iter vim.iter
------------------------------------------

`vim.iter())` is an interface for iterables: it wraps a table or function argument into an `Iter` object with methods (such as Iter:filter()) and Iter:map())) that transform the underlying source data. These methods can be chained to create iterator "pipelines": the output of each pipeline stage is input to the next stage. The first stage depends on the type passed to `vim.iter()`:

Lists or arrays (lua-list) yield only the value of each element.

Holes (nil values) are allowed (but discarded).

Use pairs() to treat array/list tables as dicts (preserve holes and non-contiguous integer keys): `vim.iter(pairs(…))`.

Or initialize with ipairs(): `vim.iter(ipairs(…))`.

Non-list tables (lua-dict) yield both the key and value of each element.

Function iterators yield all values returned by the underlying function.

Tables with a \_\_call()) metamethod are treated as function iterators.

The iterator pipeline terminates when the underlying iterable is exhausted (for function iterators this means it returned nil).

**Note:** `vim.iter()` scans table input to decide if it is a list or a dict; to avoid this cost you can wrap the table with an iterator e.g. `vim.iter(ipairs({…}))`, but that precludes the use of list-iterator operations such as Iter:rev())).

Examples:

urltomarkdowncodeblockplaceholder1260.7448762593798892

Iter:all(`{pred}`) `Iter:all())` Returns true if all items in the iterator match the given predicate.

Parameters:

`{pred}` (`fun(...):boolean`) Predicate function. Takes all values returned from the previous stage in the pipeline as arguments and returns true if the predicate matches.

Iter:any(`{pred}`) `Iter:any())` Returns true if any of the items in the iterator match the given predicate.

Parameters:

`{pred}` (`fun(...):boolean`) Predicate function. Takes all values returned from the previous stage in the pipeline as arguments and returns true if the predicate matches.

Iter:each(`{f}`) `Iter:each())` Calls a function once for each item in the pipeline, draining the iterator.

For functions with side effects. To modify the values in the iterator, use Iter:map()).

Parameters:

`{f}` (`fun(...)`) Function to execute for each item in the pipeline. Takes all of the values returned by the previous stage in the pipeline as arguments.

Iter:enumerate() `Iter:enumerate())` Yields the item index (count) and value for each item of an iterator pipeline.

For list tables, this is more efficient:

urltomarkdowncodeblockplaceholder1270.589941484771854

instead of:

urltomarkdowncodeblockplaceholder1280.9777426514684822

Example:

urltomarkdowncodeblockplaceholder1290.377702004265434

Iter:filter(`{f}`) `Iter:filter())` Filters an iterator pipeline.

Example:

urltomarkdowncodeblockplaceholder1300.24506147403797884

Parameters:

`{f}` (`fun(...):boolean`) Takes all values returned from the previous stage in the pipeline and returns false or nil if the current iterator element should be removed.

Iter:find(`{f}`) `Iter:find())` Find the first value in the iterator that satisfies the given predicate.

Advances the iterator. Returns nil and drains the iterator if no value is found.

Examples:

urltomarkdowncodeblockplaceholder1310.17152374512369795

Iter:flatten(`{depth}`) `Iter:flatten())` Flattens a list-iterator, un-nesting nested values up to the given `{depth}`. Errors if it attempts to flatten a dict-like value.

Examples:

urltomarkdowncodeblockplaceholder1320.8407398175587595

Parameters:

`{depth}` (`number?`) Depth to which list-iterator should be flattened (defaults to 1)

Iter:fold(`{init}`, `{f}`) `Iter:fold())` Folds ("reduces") an iterator into a single value. `Iter:reduce())`

Examples:

urltomarkdowncodeblockplaceholder1330.6204365948339325

Parameters:

`{init}` (`any`) Initial value of the accumulator.

`{f}` (`fun(acc:A, ...):A`) Accumulation function.

Iter:join(`{delim}`) `Iter:join())` Collect the iterator into a delimited string.

Each element in the iterator is joined into a string separated by `{delim}`.

Consumes the iterator.

Parameters:

`{delim}` (`string`) Delimiter

Iter:last() `Iter:last())` Drains the iterator and returns the last item.

Example:

urltomarkdowncodeblockplaceholder1340.868519376834646

Iter:map(`{f}`) `Iter:map())` Maps the items of an iterator pipeline to the values returned by `f`.

If the map function returns nil, the value is filtered from the iterator.

Example:

urltomarkdowncodeblockplaceholder1350.11589626835648748

Parameters:

`{f}` (`fun(...):...:any`) Mapping function. Takes all values returned from the previous stage in the pipeline as arguments and returns one or more new values, which are used in the next pipeline stage. Nil return values are filtered from the output.

Iter:next() `Iter:next())` Gets the next value from the iterator.

Example:

urltomarkdowncodeblockplaceholder1360.7497388702225476

Iter:nth(`{n}`) `Iter:nth())` Gets the nth value of an iterator (and advances to it).

If `n` is negative, offsets from the end of a list-iterator.

Example:

urltomarkdowncodeblockplaceholder1370.12201413394633809

Parameters:

`{n}` (`number`) Index of the value to return. May be negative if the source is a list-iterator.

Iter:peek() `Iter:peek())` Gets the next value in a list-iterator without consuming it.

Example:

urltomarkdowncodeblockplaceholder1380.6120792908547625

Iter:pop() `Iter:pop())` "Pops" a value from a list-iterator (gets the last value and decrements the tail).

Example:

urltomarkdowncodeblockplaceholder1390.956725056935767

Example:

urltomarkdowncodeblockplaceholder1400.7556401086826683

Iter:rfind(`{f}`) `Iter:rfind())` Gets the first value satisfying a predicate, from the end of a list-iterator.

Advances the iterator. Returns nil and drains the iterator if no value is found.

Examples:

urltomarkdowncodeblockplaceholder1410.31779031676866176

Iter:rpeek() `Iter:rpeek())` Gets the last value of a list-iterator without consuming it.

Example:

urltomarkdowncodeblockplaceholder1420.4784821171025462

Iter:rskip(`{n}`) `Iter:rskip())` Discards `n` values from the end of a list-iterator pipeline.

Example:

urltomarkdowncodeblockplaceholder1430.3657723025029076

Parameters:

`{n}` (`number`) Number of values to skip.

Iter:skip(`{n}`) `Iter:skip())` Skips `n` values of an iterator pipeline.

Example:

urltomarkdowncodeblockplaceholder1440.3762470817003154

Parameters:

`{n}` (`number`) Number of values to skip.

Iter:slice(`{first}`, `{last}`) `Iter:slice())` Sets the start and end of a list-iterator pipeline.

Equivalent to `:skip(first - 1):rskip(len - last + 1)`.

Parameters:

`{first}` (`number`)

`{last}` (`number`)

Iter:take(`{n}`) `Iter:take())` Transforms an iterator to yield only the first n values.

Example:

urltomarkdowncodeblockplaceholder1450.6384961151172754

Parameters:

`{n}` (`integer`)

Iter:totable() `Iter:totable())` Collect the iterator into a table.

The resulting table depends on the initial source in the iterator pipeline. Array-like tables and function iterators will be collected into an array-like table. If multiple values are returned from the final stage in the iterator pipeline, each value will be included in a table.

Examples:

urltomarkdowncodeblockplaceholder1460.5596784708954385

The generated table is an array-like table with consecutive, numeric indices. To create a map-like table with arbitrary keys, use Iter:fold()).

Lua module: vim.snippet vim.snippet
---------------------------------------------------

Fields:

`{direction}` (`vim.snippet.Direction`) Navigation direction. -1 for previous, 1 for next.

vim.snippet.active(`{filter}`) `vim.snippet.active())` Returns `true` if there's an active snippet in the current buffer, applying the given filter if provided.

You can use this function to navigate a snippet as follows:

urltomarkdowncodeblockplaceholder1470.9129194941022836

Parameters:

`{filter}` (`vim.snippet.ActiveFilter?`) Filter to constrain the search with:

`direction` (vim.snippet.Direction): Navigation direction. Will return `true` if the snippet can be jumped in the given direction. See vim.snippet.ActiveFilter.

Parameters:

`{input}` (`string`)

vim.snippet.jump(`{direction}`) `vim.snippet.jump())` Jumps to the next (or previous) placeholder in the current snippet, if possible.

For example, map `<Tab>` to jump while a snippet is active:

urltomarkdowncodeblockplaceholder1480.38914287342945175

Parameters:

`{direction}` (`vim.snippet.Direction`) Navigation direction. -1 for previous, 1 for next.

vim.snippet.stop() `vim.snippet.stop())` Exits the current snippet.

Lua module: vim.text vim.text
------------------------------------------

vim.text.hexdecode(`{enc}`) `vim.text.hexdecode())` Hex decode a string.

Parameters:

`{enc}` (`string`) String to decode

Return (multiple):

(`string?`) Decoded string (`string?`) Error message, if any

vim.text.hexencode(`{str}`) `vim.text.hexencode())` Hex encode a string.

Parameters:

`{str}` (`string`) String to encode

Return:

(`string`) Hex encoded string

Lua module: tohtml vim.tohtml
--------------------------------------------

:\[range\]TOhtml `{file}` `:TOhtml` Converts the buffer shown in the current window to HTML, opens the generated HTML in a new split window, and saves its contents to `{file}`. If `{file}` is not given, a temporary file (created by tempname())) is used.

tohtml.tohtml(`{winid}`, `{opt}`) `tohtml.tohtml.tohtml())` Converts the buffer shown in the window `{winid}` to HTML and returns the output as a list of string.

Parameters:

`{winid}` (`integer?`) Window to convert (defaults to current window)

`{opt}` (`table?`) Optional parameters.

`{title}` (`string|false`, default: buffer name) Title tag to set in the generated HTML code.

`{number_lines}` (`boolean`, default: `false`) Show line numbers.

`{font}` (`string[]|string`, default: `guifont`) Fonts to use.

`{width}` (`integer`, default: 'textwidth' if non-zero or window width otherwise) Width used for items which are either right aligned or repeat a character infinitely.

`{range}` (`integer[]`, default: entire buffer) Range of rows to use.) and path:match('[/\\\\]lib

Parameters:

`{names}` (`string|string[]|fun(name: string, path: string): boolean`) Names of the items to find. Must be base names, paths and globs are not supported when `{names}` is a string or a table. If `{names}` is a function, it is called for each traversed item with args:

name: base name of the current item

path: full path of the current item The function should return `true` if the given item is considered a match.

`{opts}` (`table`) Optional keyword arguments:

`{path}` (`string`) Path to begin searching from. If omitted, the current-directory is used.

`{upward}` (`boolean`, default: `false`) Search upward through parent directories. Otherwise, search through child directories (recursively).

`{stop}` (`string`) Stop searching when this directory is reached. The directory itself is not searched.

`{type}` (`string`) Find only items of the given type. If omitted, all items that match `{names}` are included.

`{limit}` (`number`, default: `1`) Stop the search after finding this many matches. Use `math.huge` to place no limit on the number of matches.

vim.fs.joinpath(`{...}`) `vim.fs.joinpath())` Concatenate directories and/or file paths into a single path with normalization (e.g., `"foo/"` and `"bar"` get joined to `"foo/bar"`)

Parameters:

`{...}` (`string`)

vim.fs.normalize(`{path}`, `{opts}`) `vim.fs.normalize())` Normalize a path to a standard format. A tilde (~) character at the beginning of the path is expanded to the user's home directory and environment variables are also expanded. "." and ".." components are also resolved, except when the path is relative and trying to resolve it would result in an absolute path.

"." as the only part in a relative path:

"." => "."

"././" => "."

".." when it leads outside the current directory

"foo/../../bar" => "../bar"

"../../foo" => "../../foo"

".." in the root directory returns the root directory.

"/../../" => "/"

On Windows, backslash (\\) characters are converted to forward slashes (/).

Examples:

urltomarkdowncodeblockplaceholder1070.8183295151917569

Parameters:

`{path}` (`string`) Path to normalize

`{opts}` (`table?`) A table with the following fields:

`{expand_env}` (`boolean`, default: `true`) Expand environment variables.

`{win}` (`boolean`, default: `true` in Windows, `false` otherwise) Path is a Windows path.

Return:

(`string`) Normalized path

vim.fs.parents(`{start}`) `vim.fs.parents())` Iterate over all the parents of the given path.

Example:

urltomarkdowncodeblockplaceholder1080.2287698239165843

Parameters:

`{start}` (`string`) Initial path.

Return (multiple):

(`fun(_, dir: string): string?`) Iterator (`nil`) (`string?`)

vim.fs.rm(`{path}`, `{opts}`) `vim.fs.rm())` Remove files or directories

Parameters:

`{path}` (`string`) Path to remove

`{opts}` (`table?`) A table with the following fields:

`{recursive}` (`boolean`) Remove directories and their contents recursively

`{force}` (`boolean`) Ignore nonexistent files and arguments

vim.fs.root(`{source}`, `{marker}`) `vim.fs.root())` Find the first parent directory containing a specific "marker", relative to a file path or buffer.

If the buffer is unnamed (has no backing file) or has a non-empty 'buftype' then the search begins from Nvim's current-directory.

Example:

urltomarkdowncodeblockplaceholder1090.711686654889139

Parameters:

`{source}` (`integer|string`) Buffer number (0 for current buffer) or file path (absolute or relative to the current-directory) to begin the search from.

`{marker}` (`string|string[]|fun(name: string, path: string): boolean`) A marker, or list of markers, to search for. If a function, the function is called for each evaluated item and should return true if `{name}` and `{path}` are a match.

Return:

(`string?`) Directory path containing one of the given markers, or nil if no directory was found.

Lua module: vim.glob vim.glob
------------------------------------------

vim.glob.to\_lpeg(`{pattern}`) `vim.glob.to_lpeg())` Parses a raw glob into an lua-lpeg pattern.

Glob patterns can have the following syntax:

`*` to match one or more characters in a path segment

`?` to match on one character in a path segment

`**` to match any number of path segments, including none

`{}` to group conditions (e.g. `*.{ts,js}` matches TypeScript and JavaScript files)

`[]` to declare a range of characters to match in a path segment (e.g., `example.[0-9]` to match on `example.0`, `example.1`, …)

`[!...]` to negate a range of characters to match in a path segment (e.g., `example.[!0-9]` to match on `example.a`, `example.b`, but not `example.0`)

Parameters:

`{pattern}` (`string`) The raw glob pattern

Return:

(`vim.lpeg.Pattern`) pattern An lua-lpeg representation of the pattern

VIM.LPEG vim.lpeg
------------------------------

LPeg is a pattern-matching library for Lua, based on Parsing Expression Grammars (PEGs). <https://bford.info/packrat/>

Pattern:match(`{subject}`, `{init}`, `{...}`) `Pattern:match())` Matches the given `pattern` against the `subject` string. If the match succeeds, returns the index in the subject of the first character after the match, or the captured values (if the pattern captured any value). An optional numeric argument `init` makes the match start at that position in the subject string. As usual in Lua libraries, a negative value counts from the end. Unlike typical pattern-matching functions, `match` works only in anchored mode; that is, it tries to match the pattern with a prefix of the given subject string (at position `init`), not with an arbitrary substring of the subject. So, if we want to find a pattern anywhere in a string, we must either write a loop in Lua or write a pattern that matches anywhere.

Example:

urltomarkdowncodeblockplaceholder1100.7752549996783569

Parameters:

`{subject}` (`string`)

`{init}` (`integer?`)

`{...}` (`any`)

vim.lpeg.B(`{pattern}`) `vim.lpeg.B())` Returns a pattern that matches only if the input string at the current position is preceded by `patt`. Pattern `patt` must match only strings with some fixed length, and it cannot contain captures. Like the `and` predicate, this pattern never consumes any input, independently of success or failure.

Parameters:

`{pattern}` (`vim.lpeg.Pattern|string|integer|boolean|table`)

Return:

(`vim.lpeg.Pattern`)

vim.lpeg.C(`{patt}`) `vim.lpeg.C())` Creates a simple capture, which captures the substring of the subject that matches `patt`. The captured value is a string. If `patt` has other captures, their values are returned after this one.

Example:

urltomarkdowncodeblockplaceholder1110.2241242272539854

Parameters:

`{patt}` (`vim.lpeg.Pattern|string|integer|boolean|table|function`)

Return:

(`vim.lpeg.Capture`)

vim.lpeg.Carg(`{n}`) `vim.lpeg.Carg())` Creates an argument capture. This pattern matches the empty string and produces the value given as the nth extra argument given in the call to `lpeg.match`.

Parameters:

`{n}` (`integer`)

Return:

(`vim.lpeg.Capture`)

vim.lpeg.Cb(`{name}`) `vim.lpeg.Cb())` Creates a back capture. This pattern matches the empty string and produces the values produced by the most recent group capture named `name` (where `name` can be any Lua value). Most recent means the last complete outermost group capture with the given name. A Complete capture means that the entire pattern corresponding to the capture has matched. An Outermost capture means that the capture is not inside another complete capture. In the same way that LPeg does not specify when it evaluates captures, it does not specify whether it reuses values previously produced by the group or re-evaluates them.

Return:

(`vim.lpeg.Capture`)

vim.lpeg.Cc(`{...}`) `vim.lpeg.Cc())` Creates a constant capture. This pattern matches the empty string and produces all given values as its captured values.

Return:

(`vim.lpeg.Capture`)

vim.lpeg.Cf(`{patt}`, `{func}`) `vim.lpeg.Cf())` Creates a fold capture. If `patt` produces a list of captures C1 C2 ... Cn, this capture will produce the value `func(...func(func(C1, C2), C3)...,Cn)`, that is, it will fold (or accumulate, or reduce) the captures from `patt` using function `func`. This capture assumes that `patt` should produce at least one capture with at least one value (of any type), which becomes the initial value of an accumulator. (If you need a specific initial value, you may prefix a constant capture to `patt`.) For each subsequent capture, LPeg calls `func` with this accumulator as the first argument and all values produced by the capture as extra arguments; the first result from this call becomes the new value for the accumulator. The final value of the accumulator becomes the captured value.

Example:

urltomarkdowncodeblockplaceholder1120.17046473394432948

Parameters:

`{patt}` (`vim.lpeg.Pattern|string|integer|boolean|table|function`)

`{func}` (`fun(acc, newvalue)`)

Return:

(`vim.lpeg.Capture`)

vim.lpeg.Cg(`{patt}`, `{name}`) `vim.lpeg.Cg())` Creates a group capture. It groups all values returned by `patt` into a single capture. The group may be anonymous (if no name is given) or named with the given name (which can be any non-nil Lua value).

Parameters:

`{patt}` (`vim.lpeg.Pattern|string|integer|boolean|table|function`)

`{name}` (`string?`)

Return:

(`vim.lpeg.Capture`)

vim.lpeg.Cmt(`{patt}`, `{fn}`) `vim.lpeg.Cmt())` Creates a match-time capture. Unlike all other captures, this one is evaluated immediately when a match occurs (even if it is part of a larger pattern that fails later). It forces the immediate evaluation of all its nested captures and then calls `function`. The given function gets as arguments the entire subject, the current position (after the match of `patt`), plus any capture values produced by `patt`. The first value returned by `function` defines how the match happens. If the call returns a number, the match succeeds and the returned number becomes the new current position. (Assuming a subject sand current position `i`, the returned number must be in the range `[i, len(s) + 1]`.) If the call returns `true`, the match succeeds without consuming any input (so, to return true is equivalent to return `i`). If the call returns `false`, `nil`, or no value, the match fails. Any extra values returned by the function become the values produced by the capture.

Parameters:

`{patt}` (`vim.lpeg.Pattern|string|integer|boolean|table|function`)

`{fn}` (`fun(s: string, i: integer, ...: any)`) (position: boolean|integer, ...: any)

Return:

(`vim.lpeg.Capture`)

vim.lpeg.Cp() `vim.lpeg.Cp())` Creates a position capture. It matches the empty string and captures the position in the subject where the match occurs. The captured value is a number.

Example:

urltomarkdowncodeblockplaceholder1130.25685910275600277

Return:

(`vim.lpeg.Capture`)

vim.lpeg.Cs(`{patt}`) `vim.lpeg.Cs())` Creates a substitution capture. This function creates a substitution capture, which captures the substring of the subject that matches `patt`, with substitutions. For any capture inside `patt` with a value, the substring that matched the capture is replaced by the capture value (which should be a string). The final captured value is the string resulting from all replacements.

Example:

urltomarkdowncodeblockplaceholder1140.5942950184718667

Parameters:

`{patt}` (`vim.lpeg.Pattern|string|integer|boolean|table|function`)

Return:

(`vim.lpeg.Capture`)

vim.lpeg.Ct(`{patt}`) `vim.lpeg.Ct())` Creates a table capture. This capture returns a table with all values from all anonymous captures made by `patt` inside this table in successive integer keys, starting at 1. Moreover, for each named capture group created by `patt`, the first value of the group is put into the table with the group name as its key. The captured value is only the table.

Parameters:

`{patt}` (`vim.lpeg.Pattern|string|integer|boolean|table|function`)

Return:

(`vim.lpeg.Capture`)

vim.lpeg.locale(`{tab}`) `vim.lpeg.locale())` Returns a table with patterns for matching some character classes according to the current locale. The table has fields named `alnum`, `alpha`, `cntrl`, `digit`, `graph`, `lower`, `print`, `punct`, `space`, `upper`, and `xdigit`, each one containing a correspondent pattern. Each pattern matches any single character that belongs to its class. If called with an argument `table`, then it creates those fields inside the given table and returns that table.

Example:

urltomarkdowncodeblockplaceholder1150.27822418457785614

Parameters:

`{tab}` (`table?`)

Return:

(`vim.lpeg.Locale`)

vim.lpeg.match(`{pattern}`, `{subject}`, `{init}`, `{...}`) `vim.lpeg.match())` Matches the given `pattern` against the `subject` string. If the match succeeds, returns the index in the subject of the first character after the match, or the captured values (if the pattern captured any value). An optional numeric argument `init` makes the match start at that position in the subject string. As usual in Lua libraries, a negative value counts from the end. Unlike typical pattern-matching functions, `match` works only in anchored mode; that is, it tries to match the pattern with a prefix of the given subject string (at position `init`), not with an arbitrary substring of the subject. So, if we want to find a pattern anywhere in a string, we must either write a loop in Lua or write a pattern that matches anywhere.

Example:

urltomarkdowncodeblockplaceholder1160.2755921602208562

Parameters:

`{pattern}` (`vim.lpeg.Pattern|string|integer|boolean|table|function`)

`{subject}` (`string`)

`{init}` (`integer?`)

`{...}` (`any`)

vim.lpeg.P(`{value}`) `vim.lpeg.P())` Converts the given value into a proper pattern. The following rules are applied:

If the argument is a pattern, it is returned unmodified.

If the argument is a string, it is translated to a pattern that matches the string literally.

If the argument is a non-negative number `n`, the result is a pattern that matches exactly `n` characters.

If the argument is a negative number `-n`, the result is a pattern that succeeds only if the input string has less than `n` characters left: `lpeg.P(-n)` is equivalent to `-lpeg.P(n)` (see the unary minus operation).

If the argument is a boolean, the result is a pattern that always succeeds or always fails (according to the boolean value), without consuming any input.

If the argument is a table, it is interpreted as a grammar (see Grammars).

If the argument is a function, returns a pattern equivalent to a match-time capture over the empty string.

Parameters:

`{value}` (`vim.lpeg.Pattern|string|integer|boolean|table|function`)

Return:

(`vim.lpeg.Pattern`)

vim.lpeg.R(`{...}`) `vim.lpeg.R())` Returns a pattern that matches any single character belonging to one of the given ranges. Each `range` is a string `xy` of length 2, representing all characters with code between the codes of `x` and `y` (both inclusive). As an example, the pattern `lpeg.R('09')` matches any digit, and `lpeg.R('az', 'AZ')` matches any ASCII letter.

Example:

urltomarkdowncodeblockplaceholder1170.9390966826397653

Parameters:

`{...}` (`string`)

Return:

(`vim.lpeg.Pattern`)

vim.lpeg.S(`{string}`) `vim.lpeg.S())` Returns a pattern that matches any single character that appears in the given string (the `S` stands for Set). As an example, the pattern `lpeg.S('+-*/')` matches any arithmetic operator. Note that, if `s` is a character (that is, a string of length 1), then `lpeg.P(s)` is equivalent to `lpeg.S(s)` which is equivalent to `lpeg.R(s..s)`. Note also that both `lpeg.S('')` and `lpeg.R()` are patterns that always fail.

Parameters:

`{string}` (`string`)

Return:

(`vim.lpeg.Pattern`)

vim.lpeg.setmaxstack(`{max}`) `vim.lpeg.setmaxstack())` Sets a limit for the size of the backtrack stack used by LPeg to track calls and choices. The default limit is `400`. Most well-written patterns need little backtrack levels and therefore you seldom need to change this limit; before changing it you should try to rewrite your pattern to avoid the need for extra space. Nevertheless, a few useful patterns may overflow. Also, with recursive grammars, subjects with deep recursion may also need larger limits.

Parameters:

`{max}` (`integer`)

vim.lpeg.type(`{value}`) `vim.lpeg.type())` Returns the string `"pattern"` if the given value is a pattern, otherwise `nil`.

Parameters:

`{value}` (`vim.lpeg.Pattern|string|integer|boolean|table|function`)

vim.lpeg.V(`{v}`) `vim.lpeg.V())` Creates a non-terminal (a variable) for a grammar. This operation creates a non-terminal (a variable) for a grammar. The created non-terminal refers to the rule indexed by `v` in the enclosing grammar.

Example:

urltomarkdowncodeblockplaceholder1180.13563568348178512

Parameters:

`{v}` (`boolean|string|number|function|table|thread|userdata|lightuserdata`)

Return:

(`vim.lpeg.Pattern`)

vim.lpeg.version() `vim.lpeg.version())` Returns a string with the running version of LPeg.

VIM.RE vim.re
------------------------

The `vim.re` module provides a conventional regex-like syntax for pattern usage within LPeg vim.lpeg. (Unrelated to vim.regex which provides Vim regexp from Lua.)

vim.re.compile(`{string}`, `{defs}`) `vim.re.compile())` Compiles the given `{string}` and returns an equivalent LPeg pattern. The given string may define either an expression or a grammar. The optional `{defs}` table provides extra Lua values to be used by the pattern.

Parameters:

`{string}` (`string`)

`{defs}` (`table?`)

Return:

(`vim.lpeg.Pattern`)

vim.re.find(`{subject}`, `{pattern}`, `{init}`) `vim.re.find())` Searches the given `{pattern}` in the given `{subject}`. If it finds a match, returns the index where this occurrence starts and the index where it ends. Otherwise, returns nil.

An optional numeric argument `{init}` makes the search starts at that position in the subject string. As usual in Lua libraries, a negative value counts from the end.

Parameters:

`{subject}` (`string`)

`{pattern}` (`vim.lpeg.Pattern|string`)

`{init}` (`integer?`)

Return (multiple):

(`integer?`) the index where the occurrence starts, nil if no match (`integer?`) the index where the occurrence ends, nil if no match

vim.re.gsub(`{subject}`, `{pattern}`, `{replacement}`) `vim.re.gsub())` Does a global substitution, replacing all occurrences of `{pattern}` in the given `{subject}` by `{replacement}`.

Parameters:

`{subject}` (`string`)

`{pattern}` (`vim.lpeg.Pattern|string`)

`{replacement}` (`string`)

vim.re.match(`{subject}`, `{pattern}`, `{init}`) `vim.re.match())` Matches the given `{pattern}` against the given `{subject}`, returning all captures.

Parameters:

`{subject}` (`string`)

`{pattern}` (`vim.lpeg.Pattern|string`)

`{init}` (`integer?`)

Return:

(`integer|vim.lpeg.Capture?`)

See also:

vim.lpeg.match()

vim.re.updatelocale() `vim.re.updatelocale())` Updates the pre-defined character classes to the current locale.

VIM.REGEX vim.regex
---------------------------------

Vim regexes can be used directly from Lua. Currently they only allow matching within a single line.

`regex:match_line())` regex:match\_line(`{bufnr}`, `{line_idx}`, `{start}`, `{end_}`) Match line `{line_idx}` (zero-based) in buffer `{bufnr}`. If `{start}` and `{end}` are supplied, match only this byte index range. Otherwise see regex:match\_str()). If `{start}` is used, then the returned byte indices will be relative `{start}`.

Parameters:

`{bufnr}` (`integer`)

`{line_idx}` (`integer`)

`{start}` (`integer?`)

`{end_}` (`integer?`)

regex:match\_str(`{str}`) `regex:match_str())` Match the string against the regex. If the string should match the regex precisely, surround the regex with `^` and `$`. If there was a match, the byte indices for the beginning and end of the match are returned. When there is no match, `nil` is returned. Because any integer is "truthy", `regex:match_str()` can be directly used as a condition in an if-statement.

Parameters:

`{str}` (`string`)

vim.regex(`{re}`) `vim.regex())` Parse the Vim regex `{re}` and return a regex object. Regexes are "magic" and case-sensitive by default, regardless of 'magic' and 'ignorecase'. They can be controlled with flags, see /magic and /ignorecase.

Parameters:

`{re}` (`string`)

Lua module: vim.secure vim.secure
------------------------------------------------

vim.secure.read(`{path}`) `vim.secure.read())` Attempt to read the file at `{path}` prompting the user if the file should be trusted. The user's choice is persisted in a trust database at $XDG\_STATE\_HOME/nvim/trust.

Parameters:

`{path}` (`string`) Path to a file to read.

Return:

(`string?`) The contents of the given file if it exists and is trusted, or nil otherwise.

vim.secure.trust(`{opts}`) `vim.secure.trust())` Manage the trust database.

Parameters:

`{opts}` (`table`) A table with the following fields:

`{action}` (`'allow'|'deny'|'remove'`) - `'allow'` to add a file to the trust database and trust it,

`'deny'` to add a file to the trust database and deny it,

`'remove'` to remove file from the trust database

`{path}` (`string`) Path to a file to update. Mutually exclusive with `{bufnr}`. Cannot be used when `{action}` is "allow".

`{bufnr}` (`integer`) Buffer number to update. Mutually exclusive with `{path}`.

Return (multiple):

(`boolean`) success true if operation was successful (`string`) msg full path if operation was successful, else error message

Lua module: vim.version vim.version
---------------------------------------------------

The `vim.version` module provides functions for comparing versions and ranges conforming to the <https://semver.org> spec. Plugins, and plugin managers, can use this to check available tools and dependencies on the current system.

Example:

urltomarkdowncodeblockplaceholder1190.5142593430246558

`vim.version())` returns the version of the current Nvim process.

### VERSION RANGE SPEC version-range

A version "range spec" defines a semantic version range which can be tested against a version, using vim.version.range()).

Supported range specs are shown in the following table. **Note:** suffixed versions (1.2.3-rc1) are not matched.

urltomarkdowncodeblockplaceholder1200.7223213142199674

vim.version.cmp(`{v1}`, `{v2}`) `vim.version.cmp())` Parses and compares two version objects (the result of vim.version.parse()), or specified literally as a `{major, minor, patch}` tuple, e.g. `{1, 0, 3}`).

Example:

urltomarkdowncodeblockplaceholder1210.8117634004505074

**Note:**

Per semver, build metadata is ignored when comparing two otherwise-equivalent versions.

Parameters:

`{v1}` (`vim.Version|number[]|string`) Version object.

`{v2}` (`vim.Version|number[]|string`) Version to compare with `v1`.

Return:

(`integer`) -1 if `v1 < v2`, 0 if `v1 == v2`, 1 if `v1 > v2`.

vim.version.eq(`{v1}`, `{v2}`) `vim.version.eq())` Returns `true` if the given versions are equal. See vim.version.cmp()) for usage.

Parameters:

`{v1}` (`vim.Version|number[]|string`)

`{v2}` (`vim.Version|number[]|string`)

vim.version.ge(`{v1}`, `{v2}`) `vim.version.ge())` Returns `true` if `v1 >= v2`. See vim.version.cmp()) for usage.

Parameters:

`{v1}` (`vim.Version|number[]|string`)

`{v2}` (`vim.Version|number[]|string`)

vim.version.gt(`{v1}`, `{v2}`) `vim.version.gt())` Returns `true` if `v1 > v2`. See vim.version.cmp()) for usage.

Parameters:

`{v1}` (`vim.Version|number[]|string`)

`{v2}` (`vim.Version|number[]|string`)

vim.version.last(`{versions}`) `vim.version.last())` TODO: generalize this, move to func.lua

Parameters:

`{versions}` (`vim.Version[]`)

vim.version.le(`{v1}`, `{v2}`) `vim.version.le())` Returns `true` if `v1 <= v2`. See vim.version.cmp()) for usage.

Parameters:

`{v1}` (`vim.Version|number[]|string`)

`{v2}` (`vim.Version|number[]|string`)

vim.version.lt(`{v1}`, `{v2}`) `vim.version.lt())` Returns `true` if `v1 < v2`. See vim.version.cmp()) for usage.

Parameters:

`{v1}` (`vim.Version|number[]|string`)

`{v2}` (`vim.Version|number[]|string`)

vim.version.parse(`{version}`, `{opts}`) `vim.version.parse())` Parses a semantic version string and returns a version object which can be used with other `vim.version` functions. For example "1.0.1-rc1+build.2" returns:

urltomarkdowncodeblockplaceholder1220.7310950514156884

Parameters:

`{version}` (`string`) Version string to parse.

`{opts}` (`table?`) Optional keyword arguments:

strict (boolean): Default false. If `true`, no coercion is attempted on input not conforming to semver v2.0.0. If `false`, `parse()` attempts to coerce input such as "1.0", "0-x", "tmux 3.2a" into valid versions.

Return:

(`vim.Version?`) parsed\_version Version object or `nil` if input is invalid.

vim.version.range(`{spec}`) `vim.version.range())` Parses a semver version-range "spec" and returns a range object:

urltomarkdowncodeblockplaceholder1230.5951471239041548

`:has()` checks if a version is in the range (inclusive `from`, exclusive `to`).

Example:

urltomarkdowncodeblockplaceholder1240.7425585526121159

Or use cmp(), le(), lt(), ge(), gt(), and/or eq() to compare a version against `.to` and `.from` directly:

urltomarkdowncodeblockplaceholder1250.9468612466711352

Parameters:

`{spec}` (`string`) Version range "spec"

Return:

(`table?`) A table with the following fields:

`{from}` (`vim.Version`)

`{to}` (`vim.Version`)

Lua module: vim.iter vim.iter
------------------------------------------

`vim.iter())` is an interface for iterables: it wraps a table or function argument into an `Iter` object with methods (such as Iter:filter()) and Iter:map())) that transform the underlying source data. These methods can be chained to create iterator "pipelines": the output of each pipeline stage is input to the next stage. The first stage depends on the type passed to `vim.iter()`:

Lists or arrays (lua-list) yield only the value of each element.

Holes (nil values) are allowed (but discarded).

Use pairs() to treat array/list tables as dicts (preserve holes and non-contiguous integer keys): `vim.iter(pairs(…))`.

Or initialize with ipairs(): `vim.iter(ipairs(…))`.

Non-list tables (lua-dict) yield both the key and value of each element.

Function iterators yield all values returned by the underlying function.

Tables with a \_\_call()) metamethod are treated as function iterators.

The iterator pipeline terminates when the underlying iterable is exhausted (for function iterators this means it returned nil).

**Note:** `vim.iter()` scans table input to decide if it is a list or a dict; to avoid this cost you can wrap the table with an iterator e.g. `vim.iter(ipairs({…}))`, but that precludes the use of list-iterator operations such as Iter:rev())).

Examples:

urltomarkdowncodeblockplaceholder1260.7448762593798892

Iter:all(`{pred}`) `Iter:all())` Returns true if all items in the iterator match the given predicate.

Parameters:

`{pred}` (`fun(...):boolean`) Predicate function. Takes all values returned from the previous stage in the pipeline as arguments and returns true if the predicate matches.

Iter:any(`{pred}`) `Iter:any())` Returns true if any of the items in the iterator match the given predicate.

Parameters:

`{pred}` (`fun(...):boolean`) Predicate function. Takes all values returned from the previous stage in the pipeline as arguments and returns true if the predicate matches.

Iter:each(`{f}`) `Iter:each())` Calls a function once for each item in the pipeline, draining the iterator.

For functions with side effects. To modify the values in the iterator, use Iter:map()).

Parameters:

`{f}` (`fun(...)`) Function to execute for each item in the pipeline. Takes all of the values returned by the previous stage in the pipeline as arguments.

Iter:enumerate() `Iter:enumerate())` Yields the item index (count) and value for each item of an iterator pipeline.

For list tables, this is more efficient:

urltomarkdowncodeblockplaceholder1270.589941484771854

instead of:

urltomarkdowncodeblockplaceholder1280.9777426514684822

Example:

urltomarkdowncodeblockplaceholder1290.377702004265434

Iter:filter(`{f}`) `Iter:filter())` Filters an iterator pipeline.

Example:

urltomarkdowncodeblockplaceholder1300.24506147403797884

Parameters:

`{f}` (`fun(...):boolean`) Takes all values returned from the previous stage in the pipeline and returns false or nil if the current iterator element should be removed.

Iter:find(`{f}`) `Iter:find())` Find the first value in the iterator that satisfies the given predicate.

Advances the iterator. Returns nil and drains the iterator if no value is found.

Examples:

urltomarkdowncodeblockplaceholder1310.17152374512369795

Iter:flatten(`{depth}`) `Iter:flatten())` Flattens a list-iterator, un-nesting nested values up to the given `{depth}`. Errors if it attempts to flatten a dict-like value.

Examples:

urltomarkdowncodeblockplaceholder1320.8407398175587595

Parameters:

`{depth}` (`number?`) Depth to which list-iterator should be flattened (defaults to 1)

Iter:fold(`{init}`, `{f}`) `Iter:fold())` Folds ("reduces") an iterator into a single value. `Iter:reduce())`

Examples:

urltomarkdowncodeblockplaceholder1330.6204365948339325

Parameters:

`{init}` (`any`) Initial value of the accumulator.

`{f}` (`fun(acc:A, ...):A`) Accumulation function.

Iter:join(`{delim}`) `Iter:join())` Collect the iterator into a delimited string.

Each element in the iterator is joined into a string separated by `{delim}`.

Consumes the iterator.

Parameters:

`{delim}` (`string`) Delimiter

Iter:last() `Iter:last())` Drains the iterator and returns the last item.

Example:

urltomarkdowncodeblockplaceholder1340.868519376834646

Iter:map(`{f}`) `Iter:map())` Maps the items of an iterator pipeline to the values returned by `f`.

If the map function returns nil, the value is filtered from the iterator.

Example:

urltomarkdowncodeblockplaceholder1350.11589626835648748

Parameters:

`{f}` (`fun(...):...:any`) Mapping function. Takes all values returned from the previous stage in the pipeline as arguments and returns one or more new values, which are used in the next pipeline stage. Nil return values are filtered from the output.

Iter:next() `Iter:next())` Gets the next value from the iterator.

Example:

urltomarkdowncodeblockplaceholder1360.7497388702225476

Iter:nth(`{n}`) `Iter:nth())` Gets the nth value of an iterator (and advances to it).

If `n` is negative, offsets from the end of a list-iterator.

Example:

urltomarkdowncodeblockplaceholder1370.12201413394633809

Parameters:

`{n}` (`number`) Index of the value to return. May be negative if the source is a list-iterator.

Iter:peek() `Iter:peek())` Gets the next value in a list-iterator without consuming it.

Example:

urltomarkdowncodeblockplaceholder1380.6120792908547625

Iter:pop() `Iter:pop())` "Pops" a value from a list-iterator (gets the last value and decrements the tail).

Example:

urltomarkdowncodeblockplaceholder1390.956725056935767

Example:

urltomarkdowncodeblockplaceholder1400.7556401086826683

Iter:rfind(`{f}`) `Iter:rfind())` Gets the first value satisfying a predicate, from the end of a list-iterator.

Advances the iterator. Returns nil and drains the iterator if no value is found.

Examples:

urltomarkdowncodeblockplaceholder1410.31779031676866176

Iter:rpeek() `Iter:rpeek())` Gets the last value of a list-iterator without consuming it.

Example:

urltomarkdowncodeblockplaceholder1420.4784821171025462

Iter:rskip(`{n}`) `Iter:rskip())` Discards `n` values from the end of a list-iterator pipeline.

Example:

urltomarkdowncodeblockplaceholder1430.3657723025029076

Parameters:

`{n}` (`number`) Number of values to skip.

Iter:skip(`{n}`) `Iter:skip())` Skips `n` values of an iterator pipeline.

Example:

urltomarkdowncodeblockplaceholder1440.3762470817003154

Parameters:

`{n}` (`number`) Number of values to skip.

Iter:slice(`{first}`, `{last}`) `Iter:slice())` Sets the start and end of a list-iterator pipeline.

Equivalent to `:skip(first - 1):rskip(len - last + 1)`.

Parameters:

`{first}` (`number`)

`{last}` (`number`)

Iter:take(`{n}`) `Iter:take())` Transforms an iterator to yield only the first n values.

Example:

urltomarkdowncodeblockplaceholder1450.6384961151172754

Parameters:

`{n}` (`integer`)

Iter:totable() `Iter:totable())` Collect the iterator into a table.

The resulting table depends on the initial source in the iterator pipeline. Array-like tables and function iterators will be collected into an array-like table. If multiple values are returned from the final stage in the iterator pipeline, each value will be included in a table.

Examples:

urltomarkdowncodeblockplaceholder1460.5596784708954385

The generated table is an array-like table with consecutive, numeric indices. To create a map-like table with arbitrary keys, use Iter:fold()).

Lua module: vim.snippet vim.snippet
---------------------------------------------------

Fields:

`{direction}` (`vim.snippet.Direction`) Navigation direction. -1 for previous, 1 for next.

vim.snippet.active(`{filter}`) `vim.snippet.active())` Returns `true` if there's an active snippet in the current buffer, applying the given filter if provided.

You can use this function to navigate a snippet as follows:

urltomarkdowncodeblockplaceholder1470.9129194941022836

Parameters:

`{filter}` (`vim.snippet.ActiveFilter?`) Filter to constrain the search with:

`direction` (vim.snippet.Direction): Navigation direction. Will return `true` if the snippet can be jumped in the given direction. See vim.snippet.ActiveFilter.

Parameters:

`{input}` (`string`)

vim.snippet.jump(`{direction}`) `vim.snippet.jump())` Jumps to the next (or previous) placeholder in the current snippet, if possible.

For example, map `<Tab>` to jump while a snippet is active:

urltomarkdowncodeblockplaceholder1480.38914287342945175

Parameters:

`{direction}` (`vim.snippet.Direction`) Navigation direction. -1 for previous, 1 for next.

vim.snippet.stop() `vim.snippet.stop())` Exits the current snippet.

Lua module: vim.text vim.text
------------------------------------------

vim.text.hexdecode(`{enc}`) `vim.text.hexdecode())` Hex decode a string.

Parameters:

`{enc}` (`string`) String to decode

Return (multiple):

(`string?`) Decoded string (`string?`) Error message, if any

vim.text.hexencode(`{str}`) `vim.text.hexencode())` Hex encode a string.

Parameters:

`{str}` (`string`) String to encode

Return:

(`string`) Hex encoded string

Lua module: tohtml vim.tohtml
--------------------------------------------

:\[range\]TOhtml `{file}` `:TOhtml` Converts the buffer shown in the current window to HTML, opens the generated HTML in a new split window, and saves its contents to `{file}`. If `{file}` is not given, a temporary file (created by tempname())) is used.

tohtml.tohtml(`{winid}`, `{opt}`) `tohtml.tohtml.tohtml())` Converts the buffer shown in the window `{winid}` to HTML and returns the output as a list of string.

Parameters:

`{winid}` (`integer?`) Window to convert (defaults to current window)

`{opt}` (`table?`) Optional parameters.

`{title}` (`string|false`, default: buffer name) Title tag to set in the generated HTML code.

`{number_lines}` (`boolean`, default: `false`) Show line numbers.

`{font}` (`string[]|string`, default: `guifont`) Fonts to use.

`{width}` (`integer`, default: 'textwidth' if non-zero or window width otherwise) Width used for items which are either right aligned or repeat a character infinitely.

`{range}` (`integer[]`, default: entire buffer) Range of rows to use.)
end, {limit = math.huge, type = 'file'})

```


Parameters:

`{names}` (`string|string[]|fun(name: string, path: string): boolean`) Names of the items to find. Must be base names, paths and globs are not supported when `{names}` is a string or a table. If `{names}` is a function, it is called for each traversed item with args:

name: base name of the current item

path: full path of the current item The function should return `true` if the given item is considered a match.

`{opts}` (`table`) Optional keyword arguments:

`{path}` (`string`) Path to begin searching from. If omitted, the current-directory is used.

`{upward}` (`boolean`, default: `false`) Search upward through parent directories. Otherwise, search through child directories (recursively).

`{stop}` (`string`) Stop searching when this directory is reached. The directory itself is not searched.

`{type}` (`string`) Find only items of the given type. If omitted, all items that match `{names}` are included.

`{limit}` (`number`, default: `1`) Stop the search after finding this many matches. Use `math.huge` to place no limit on the number of matches.

vim.fs.joinpath(`{...}`) `vim.fs.joinpath())` Concatenate directories and/or file paths into a single path with normalization (e.g., `"foo/"` and `"bar"` get joined to `"foo/bar"`)

Parameters:

`{...}` (`string`)

vim.fs.normalize(`{path}`, `{opts}`) `vim.fs.normalize())` Normalize a path to a standard format. A tilde (~) character at the beginning of the path is expanded to the user's home directory and environment variables are also expanded. "." and ".." components are also resolved, except when the path is relative and trying to resolve it would result in an absolute path.

"." as the only part in a relative path:

"." => "."

"././" => "."

".." when it leads outside the current directory

"foo/../../bar" => "../bar"

"../../foo" => "../../foo"

".." in the root directory returns the root directory.

"/../../" => "/"

On Windows, backslash (\\) characters are converted to forward slashes (/).

Examples:

urltomarkdowncodeblockplaceholder1070.8183295151917569

Parameters:

`{path}` (`string`) Path to normalize

`{opts}` (`table?`) A table with the following fields:

`{expand_env}` (`boolean`, default: `true`) Expand environment variables.

`{win}` (`boolean`, default: `true` in Windows, `false` otherwise) Path is a Windows path.

Return:

(`string`) Normalized path

vim.fs.parents(`{start}`) `vim.fs.parents())` Iterate over all the parents of the given path.

Example:

urltomarkdowncodeblockplaceholder1080.2287698239165843

Parameters:

`{start}` (`string`) Initial path.

Return (multiple):

(`fun(_, dir: string): string?`) Iterator (`nil`) (`string?`)

vim.fs.rm(`{path}`, `{opts}`) `vim.fs.rm())` Remove files or directories

Parameters:

`{path}` (`string`) Path to remove

`{opts}` (`table?`) A table with the following fields:

`{recursive}` (`boolean`) Remove directories and their contents recursively

`{force}` (`boolean`) Ignore nonexistent files and arguments

vim.fs.root(`{source}`, `{marker}`) `vim.fs.root())` Find the first parent directory containing a specific "marker", relative to a file path or buffer.

If the buffer is unnamed (has no backing file) or has a non-empty 'buftype' then the search begins from Nvim's current-directory.

Example:

urltomarkdowncodeblockplaceholder1090.711686654889139

Parameters:

`{source}` (`integer|string`) Buffer number (0 for current buffer) or file path (absolute or relative to the current-directory) to begin the search from.

`{marker}` (`string|string[]|fun(name: string, path: string): boolean`) A marker, or list of markers, to search for. If a function, the function is called for each evaluated item and should return true if `{name}` and `{path}` are a match.

Return:

(`string?`) Directory path containing one of the given markers, or nil if no directory was found.

Lua module: vim.glob vim.glob
------------------------------------------

vim.glob.to\_lpeg(`{pattern}`) `vim.glob.to_lpeg())` Parses a raw glob into an lua-lpeg pattern.

Glob patterns can have the following syntax:

`*` to match one or more characters in a path segment

`?` to match on one character in a path segment

`**` to match any number of path segments, including none

`{}` to group conditions (e.g. `*.{ts,js}` matches TypeScript and JavaScript files)

`[]` to declare a range of characters to match in a path segment (e.g., `example.[0-9]` to match on `example.0`, `example.1`, …)

`[!...]` to negate a range of characters to match in a path segment (e.g., `example.[!0-9]` to match on `example.a`, `example.b`, but not `example.0`)

Parameters:

`{pattern}` (`string`) The raw glob pattern

Return:

(`vim.lpeg.Pattern`) pattern An lua-lpeg representation of the pattern

VIM.LPEG vim.lpeg
------------------------------

LPeg is a pattern-matching library for Lua, based on Parsing Expression Grammars (PEGs). https://bford.info/packrat/

Pattern:match(`{subject}`, `{init}`, `{...}`) `Pattern:match())` Matches the given `pattern` against the `subject` string. If the match succeeds, returns the index in the subject of the first character after the match, or the captured values (if the pattern captured any value). An optional numeric argument `init` makes the match start at that position in the subject string. As usual in Lua libraries, a negative value counts from the end. Unlike typical pattern-matching functions, `match` works only in anchored mode; that is, it tries to match the pattern with a prefix of the given subject string (at position `init`), not with an arbitrary substring of the subject. So, if we want to find a pattern anywhere in a string, we must either write a loop in Lua or write a pattern that matches anywhere.

Example:

urltomarkdowncodeblockplaceholder1100.7752549996783569

Parameters:

`{subject}` (`string`)

`{init}` (`integer?`)

`{...}` (`any`)

vim.lpeg.B(`{pattern}`) `vim.lpeg.B())` Returns a pattern that matches only if the input string at the current position is preceded by `patt`. Pattern `patt` must match only strings with some fixed length, and it cannot contain captures. Like the `and` predicate, this pattern never consumes any input, independently of success or failure.

Parameters:

`{pattern}` (`vim.lpeg.Pattern|string|integer|boolean|table`)

Return:

(`vim.lpeg.Pattern`)

vim.lpeg.C(`{patt}`) `vim.lpeg.C())` Creates a simple capture, which captures the substring of the subject that matches `patt`. The captured value is a string. If `patt` has other captures, their values are returned after this one.

Example:

urltomarkdowncodeblockplaceholder1110.2241242272539854

Parameters:

`{patt}` (`vim.lpeg.Pattern|string|integer|boolean|table|function`)

Return:

(`vim.lpeg.Capture`)

vim.lpeg.Carg(`{n}`) `vim.lpeg.Carg())` Creates an argument capture. This pattern matches the empty string and produces the value given as the nth extra argument given in the call to `lpeg.match`.

Parameters:

`{n}` (`integer`)

Return:

(`vim.lpeg.Capture`)

vim.lpeg.Cb(`{name}`) `vim.lpeg.Cb())` Creates a back capture. This pattern matches the empty string and produces the values produced by the most recent group capture named `name` (where `name` can be any Lua value). Most recent means the last complete outermost group capture with the given name. A Complete capture means that the entire pattern corresponding to the capture has matched. An Outermost capture means that the capture is not inside another complete capture. In the same way that LPeg does not specify when it evaluates captures, it does not specify whether it reuses values previously produced by the group or re-evaluates them.

Return:

(`vim.lpeg.Capture`)

vim.lpeg.Cc(`{...}`) `vim.lpeg.Cc())` Creates a constant capture. This pattern matches the empty string and produces all given values as its captured values.

Return:

(`vim.lpeg.Capture`)

vim.lpeg.Cf(`{patt}`, `{func}`) `vim.lpeg.Cf())` Creates a fold capture. If `patt` produces a list of captures C1 C2 ... Cn, this capture will produce the value `func(...func(func(C1, C2), C3)...,Cn)`, that is, it will fold (or accumulate, or reduce) the captures from `patt` using function `func`. This capture assumes that `patt` should produce at least one capture with at least one value (of any type), which becomes the initial value of an accumulator. (If you need a specific initial value, you may prefix a constant capture to `patt`.) For each subsequent capture, LPeg calls `func` with this accumulator as the first argument and all values produced by the capture as extra arguments; the first result from this call becomes the new value for the accumulator. The final value of the accumulator becomes the captured value.

Example:

urltomarkdowncodeblockplaceholder1120.17046473394432948

Parameters:

`{patt}` (`vim.lpeg.Pattern|string|integer|boolean|table|function`)

`{func}` (`fun(acc, newvalue)`)

Return:

(`vim.lpeg.Capture`)

vim.lpeg.Cg(`{patt}`, `{name}`) `vim.lpeg.Cg())` Creates a group capture. It groups all values returned by `patt` into a single capture. The group may be anonymous (if no name is given) or named with the given name (which can be any non-nil Lua value).

Parameters:

`{patt}` (`vim.lpeg.Pattern|string|integer|boolean|table|function`)

`{name}` (`string?`)

Return:

(`vim.lpeg.Capture`)

vim.lpeg.Cmt(`{patt}`, `{fn}`) `vim.lpeg.Cmt())` Creates a match-time capture. Unlike all other captures, this one is evaluated immediately when a match occurs (even if it is part of a larger pattern that fails later). It forces the immediate evaluation of all its nested captures and then calls `function`. The given function gets as arguments the entire subject, the current position (after the match of `patt`), plus any capture values produced by `patt`. The first value returned by `function` defines how the match happens. If the call returns a number, the match succeeds and the returned number becomes the new current position. (Assuming a subject sand current position `i`, the returned number must be in the range `[i, len(s) + 1]`.) If the call returns `true`, the match succeeds without consuming any input (so, to return true is equivalent to return `i`). If the call returns `false`, `nil`, or no value, the match fails. Any extra values returned by the function become the values produced by the capture.

Parameters:

`{patt}` (`vim.lpeg.Pattern|string|integer|boolean|table|function`)

`{fn}` (`fun(s: string, i: integer, ...: any)`) (position: boolean|integer, ...: any)

Return:

(`vim.lpeg.Capture`)

vim.lpeg.Cp() `vim.lpeg.Cp())` Creates a position capture. It matches the empty string and captures the position in the subject where the match occurs. The captured value is a number.

Example:

urltomarkdowncodeblockplaceholder1130.25685910275600277

Return:

(`vim.lpeg.Capture`)

vim.lpeg.Cs(`{patt}`) `vim.lpeg.Cs())` Creates a substitution capture. This function creates a substitution capture, which captures the substring of the subject that matches `patt`, with substitutions. For any capture inside `patt` with a value, the substring that matched the capture is replaced by the capture value (which should be a string). The final captured value is the string resulting from all replacements.

Example:

urltomarkdowncodeblockplaceholder1140.5942950184718667

Parameters:

`{patt}` (`vim.lpeg.Pattern|string|integer|boolean|table|function`)

Return:

(`vim.lpeg.Capture`)

vim.lpeg.Ct(`{patt}`) `vim.lpeg.Ct())` Creates a table capture. This capture returns a table with all values from all anonymous captures made by `patt` inside this table in successive integer keys, starting at 1. Moreover, for each named capture group created by `patt`, the first value of the group is put into the table with the group name as its key. The captured value is only the table.

Parameters:

`{patt}` (`vim.lpeg.Pattern|string|integer|boolean|table|function`)

Return:

(`vim.lpeg.Capture`)

vim.lpeg.locale(`{tab}`) `vim.lpeg.locale())` Returns a table with patterns for matching some character classes according to the current locale. The table has fields named `alnum`, `alpha`, `cntrl`, `digit`, `graph`, `lower`, `print`, `punct`, `space`, `upper`, and `xdigit`, each one containing a correspondent pattern. Each pattern matches any single character that belongs to its class. If called with an argument `table`, then it creates those fields inside the given table and returns that table.

Example:

urltomarkdowncodeblockplaceholder1150.27822418457785614

Parameters:

`{tab}` (`table?`)

Return:

(`vim.lpeg.Locale`)

vim.lpeg.match(`{pattern}`, `{subject}`, `{init}`, `{...}`) `vim.lpeg.match())` Matches the given `pattern` against the `subject` string. If the match succeeds, returns the index in the subject of the first character after the match, or the captured values (if the pattern captured any value). An optional numeric argument `init` makes the match start at that position in the subject string. As usual in Lua libraries, a negative value counts from the end. Unlike typical pattern-matching functions, `match` works only in anchored mode; that is, it tries to match the pattern with a prefix of the given subject string (at position `init`), not with an arbitrary substring of the subject. So, if we want to find a pattern anywhere in a string, we must either write a loop in Lua or write a pattern that matches anywhere.

Example:

urltomarkdowncodeblockplaceholder1160.2755921602208562

Parameters:

`{pattern}` (`vim.lpeg.Pattern|string|integer|boolean|table|function`)

`{subject}` (`string`)

`{init}` (`integer?`)

`{...}` (`any`)

vim.lpeg.P(`{value}`) `vim.lpeg.P())` Converts the given value into a proper pattern. The following rules are applied:

If the argument is a pattern, it is returned unmodified.

If the argument is a string, it is translated to a pattern that matches the string literally.

If the argument is a non-negative number `n`, the result is a pattern that matches exactly `n` characters.

If the argument is a negative number `-n`, the result is a pattern that succeeds only if the input string has less than `n` characters left: `lpeg.P(-n)` is equivalent to `-lpeg.P(n)` (see the unary minus operation).

If the argument is a boolean, the result is a pattern that always succeeds or always fails (according to the boolean value), without consuming any input.

If the argument is a table, it is interpreted as a grammar (see Grammars).

If the argument is a function, returns a pattern equivalent to a match-time capture over the empty string.

Parameters:

`{value}` (`vim.lpeg.Pattern|string|integer|boolean|table|function`)

Return:

(`vim.lpeg.Pattern`)

vim.lpeg.R(`{...}`) `vim.lpeg.R())` Returns a pattern that matches any single character belonging to one of the given ranges. Each `range` is a string `xy` of length 2, representing all characters with code between the codes of `x` and `y` (both inclusive). As an example, the pattern `lpeg.R('09')` matches any digit, and `lpeg.R('az', 'AZ')` matches any ASCII letter.

Example:

urltomarkdowncodeblockplaceholder1170.9390966826397653

Parameters:

`{...}` (`string`)

Return:

(`vim.lpeg.Pattern`)

vim.lpeg.S(`{string}`) `vim.lpeg.S())` Returns a pattern that matches any single character that appears in the given string (the `S` stands for Set). As an example, the pattern `lpeg.S('+-*/')` matches any arithmetic operator. Note that, if `s` is a character (that is, a string of length 1), then `lpeg.P(s)` is equivalent to `lpeg.S(s)` which is equivalent to `lpeg.R(s..s)`. Note also that both `lpeg.S('')` and `lpeg.R()` are patterns that always fail.

Parameters:

`{string}` (`string`)

Return:

(`vim.lpeg.Pattern`)

vim.lpeg.setmaxstack(`{max}`) `vim.lpeg.setmaxstack())` Sets a limit for the size of the backtrack stack used by LPeg to track calls and choices. The default limit is `400`. Most well-written patterns need little backtrack levels and therefore you seldom need to change this limit; before changing it you should try to rewrite your pattern to avoid the need for extra space. Nevertheless, a few useful patterns may overflow. Also, with recursive grammars, subjects with deep recursion may also need larger limits.

Parameters:

`{max}` (`integer`)

vim.lpeg.type(`{value}`) `vim.lpeg.type())` Returns the string `"pattern"` if the given value is a pattern, otherwise `nil`.

Parameters:

`{value}` (`vim.lpeg.Pattern|string|integer|boolean|table|function`)

vim.lpeg.V(`{v}`) `vim.lpeg.V())` Creates a non-terminal (a variable) for a grammar. This operation creates a non-terminal (a variable) for a grammar. The created non-terminal refers to the rule indexed by `v` in the enclosing grammar.

Example:

urltomarkdowncodeblockplaceholder1180.13563568348178512

Parameters:

`{v}` (`boolean|string|number|function|table|thread|userdata|lightuserdata`)

Return:

(`vim.lpeg.Pattern`)

vim.lpeg.version() `vim.lpeg.version())` Returns a string with the running version of LPeg.

VIM.RE vim.re
------------------------

The `vim.re` module provides a conventional regex-like syntax for pattern usage within LPeg vim.lpeg. (Unrelated to vim.regex which provides Vim regexp from Lua.)

vim.re.compile(`{string}`, `{defs}`) `vim.re.compile())` Compiles the given `{string}` and returns an equivalent LPeg pattern. The given string may define either an expression or a grammar. The optional `{defs}` table provides extra Lua values to be used by the pattern.

Parameters:

`{string}` (`string`)

`{defs}` (`table?`)

Return:

(`vim.lpeg.Pattern`)

vim.re.find(`{subject}`, `{pattern}`, `{init}`) `vim.re.find())` Searches the given `{pattern}` in the given `{subject}`. If it finds a match, returns the index where this occurrence starts and the index where it ends. Otherwise, returns nil.

An optional numeric argument `{init}` makes the search starts at that position in the subject string. As usual in Lua libraries, a negative value counts from the end.

Parameters:

`{subject}` (`string`)

`{pattern}` (`vim.lpeg.Pattern|string`)

`{init}` (`integer?`)

Return (multiple):

(`integer?`) the index where the occurrence starts, nil if no match (`integer?`) the index where the occurrence ends, nil if no match

vim.re.gsub(`{subject}`, `{pattern}`, `{replacement}`) `vim.re.gsub())` Does a global substitution, replacing all occurrences of `{pattern}` in the given `{subject}` by `{replacement}`.

Parameters:

`{subject}` (`string`)

`{pattern}` (`vim.lpeg.Pattern|string`)

`{replacement}` (`string`)

vim.re.match(`{subject}`, `{pattern}`, `{init}`) `vim.re.match())` Matches the given `{pattern}` against the given `{subject}`, returning all captures.

Parameters:

`{subject}` (`string`)

`{pattern}` (`vim.lpeg.Pattern|string`)

`{init}` (`integer?`)

Return:

(`integer|vim.lpeg.Capture?`)

See also:

vim.lpeg.match()

vim.re.updatelocale() `vim.re.updatelocale())` Updates the pre-defined character classes to the current locale.

VIM.REGEX vim.regex
---------------------------------

Vim regexes can be used directly from Lua. Currently they only allow matching within a single line.

`regex:match_line())` regex:match\_line(`{bufnr}`, `{line_idx}`, `{start}`, `{end_}`) Match line `{line_idx}` (zero-based) in buffer `{bufnr}`. If `{start}` and `{end}` are supplied, match only this byte index range. Otherwise see regex:match\_str()). If `{start}` is used, then the returned byte indices will be relative `{start}`.

Parameters:

`{bufnr}` (`integer`)

`{line_idx}` (`integer`)

`{start}` (`integer?`)

`{end_}` (`integer?`)

regex:match\_str(`{str}`) `regex:match_str())` Match the string against the regex. If the string should match the regex precisely, surround the regex with `^` and `$`. If there was a match, the byte indices for the beginning and end of the match are returned. When there is no match, `nil` is returned. Because any integer is "truthy", `regex:match_str()` can be directly used as a condition in an if-statement.

Parameters:

`{str}` (`string`)

vim.regex(`{re}`) `vim.regex())` Parse the Vim regex `{re}` and return a regex object. Regexes are "magic" and case-sensitive by default, regardless of 'magic' and 'ignorecase'. They can be controlled with flags, see /magic and /ignorecase.

Parameters:

`{re}` (`string`)

Lua module: vim.secure vim.secure
------------------------------------------------

vim.secure.read(`{path}`) `vim.secure.read())` Attempt to read the file at `{path}` prompting the user if the file should be trusted. The user's choice is persisted in a trust database at $XDG\_STATE\_HOME/nvim/trust.

Parameters:

`{path}` (`string`) Path to a file to read.

Return:

(`string?`) The contents of the given file if it exists and is trusted, or nil otherwise.

vim.secure.trust(`{opts}`) `vim.secure.trust())` Manage the trust database.

Parameters:

`{opts}` (`table`) A table with the following fields:

`{action}` (`'allow'|'deny'|'remove'`) - `'allow'` to add a file to the trust database and trust it,

`'deny'` to add a file to the trust database and deny it,

`'remove'` to remove file from the trust database

`{path}` (`string`) Path to a file to update. Mutually exclusive with `{bufnr}`. Cannot be used when `{action}` is "allow".

`{bufnr}` (`integer`) Buffer number to update. Mutually exclusive with `{path}`.

Return (multiple):

(`boolean`) success true if operation was successful (`string`) msg full path if operation was successful, else error message

Lua module: vim.version vim.version
---------------------------------------------------

The `vim.version` module provides functions for comparing versions and ranges conforming to the https://semver.org spec. Plugins, and plugin managers, can use this to check available tools and dependencies on the current system.

Example:

urltomarkdowncodeblockplaceholder1190.5142593430246558

`vim.version())` returns the version of the current Nvim process.

### VERSION RANGE SPEC version-range

A version "range spec" defines a semantic version range which can be tested against a version, using vim.version.range()).

Supported range specs are shown in the following table. **Note:** suffixed versions (1.2.3-rc1) are not matched.

urltomarkdowncodeblockplaceholder1200.7223213142199674

vim.version.cmp(`{v1}`, `{v2}`) `vim.version.cmp())` Parses and compares two version objects (the result of vim.version.parse()), or specified literally as a `{major, minor, patch}` tuple, e.g. `{1, 0, 3}`).

Example:

urltomarkdowncodeblockplaceholder1210.8117634004505074

**Note:**

Per semver, build metadata is ignored when comparing two otherwise-equivalent versions.

Parameters:

`{v1}` (`vim.Version|number[]|string`) Version object.

`{v2}` (`vim.Version|number[]|string`) Version to compare with `v1`.

Return:

(`integer`) -1 if `v1 < v2`, 0 if `v1 == v2`, 1 if `v1 > v2`.

vim.version.eq(`{v1}`, `{v2}`) `vim.version.eq())` Returns `true` if the given versions are equal. See vim.version.cmp()) for usage.

Parameters:

`{v1}` (`vim.Version|number[]|string`)

`{v2}` (`vim.Version|number[]|string`)

vim.version.ge(`{v1}`, `{v2}`) `vim.version.ge())` Returns `true` if `v1 >= v2`. See vim.version.cmp()) for usage.

Parameters:

`{v1}` (`vim.Version|number[]|string`)

`{v2}` (`vim.Version|number[]|string`)

vim.version.gt(`{v1}`, `{v2}`) `vim.version.gt())` Returns `true` if `v1 > v2`. See vim.version.cmp()) for usage.

Parameters:

`{v1}` (`vim.Version|number[]|string`)

`{v2}` (`vim.Version|number[]|string`)

vim.version.last(`{versions}`) `vim.version.last())` TODO: generalize this, move to func.lua

Parameters:

`{versions}` (`vim.Version[]`)

vim.version.le(`{v1}`, `{v2}`) `vim.version.le())` Returns `true` if `v1 <= v2`. See vim.version.cmp()) for usage.

Parameters:

`{v1}` (`vim.Version|number[]|string`)

`{v2}` (`vim.Version|number[]|string`)

vim.version.lt(`{v1}`, `{v2}`) `vim.version.lt())` Returns `true` if `v1 < v2`. See vim.version.cmp()) for usage.

Parameters:

`{v1}` (`vim.Version|number[]|string`)

`{v2}` (`vim.Version|number[]|string`)

vim.version.parse(`{version}`, `{opts}`) `vim.version.parse())` Parses a semantic version string and returns a version object which can be used with other `vim.version` functions. For example "1.0.1-rc1+build.2" returns:

urltomarkdowncodeblockplaceholder1220.7310950514156884

Parameters:

`{version}` (`string`) Version string to parse.

`{opts}` (`table?`) Optional keyword arguments:

strict (boolean): Default false. If `true`, no coercion is attempted on input not conforming to semver v2.0.0. If `false`, `parse()` attempts to coerce input such as "1.0", "0-x", "tmux 3.2a" into valid versions.

Return:

(`vim.Version?`) parsed\_version Version object or `nil` if input is invalid.

vim.version.range(`{spec}`) `vim.version.range())` Parses a semver version-range "spec" and returns a range object:

urltomarkdowncodeblockplaceholder1230.5951471239041548

`:has()` checks if a version is in the range (inclusive `from`, exclusive `to`).

Example:

urltomarkdowncodeblockplaceholder1240.7425585526121159

Or use cmp(), le(), lt(), ge(), gt(), and/or eq() to compare a version against `.to` and `.from` directly:

urltomarkdowncodeblockplaceholder1250.9468612466711352

Parameters:

`{spec}` (`string`) Version range "spec"

Return:

(`table?`) A table with the following fields:

`{from}` (`vim.Version`)

`{to}` (`vim.Version`)

Lua module: vim.iter vim.iter
------------------------------------------

`vim.iter())` is an interface for iterables: it wraps a table or function argument into an `Iter` object with methods (such as Iter:filter()) and Iter:map())) that transform the underlying source data. These methods can be chained to create iterator "pipelines": the output of each pipeline stage is input to the next stage. The first stage depends on the type passed to `vim.iter()`:

Lists or arrays (lua-list) yield only the value of each element.

Holes (nil values) are allowed (but discarded).

Use pairs() to treat array/list tables as dicts (preserve holes and non-contiguous integer keys): `vim.iter(pairs(…))`.

Or initialize with ipairs(): `vim.iter(ipairs(…))`.

Non-list tables (lua-dict) yield both the key and value of each element.

Function iterators yield all values returned by the underlying function.

Tables with a \_\_call()) metamethod are treated as function iterators.

The iterator pipeline terminates when the underlying iterable is exhausted (for function iterators this means it returned nil).

**Note:** `vim.iter()` scans table input to decide if it is a list or a dict; to avoid this cost you can wrap the table with an iterator e.g. `vim.iter(ipairs({…}))`, but that precludes the use of list-iterator operations such as Iter:rev())).

Examples:

urltomarkdowncodeblockplaceholder1260.7448762593798892

Iter:all(`{pred}`) `Iter:all())` Returns true if all items in the iterator match the given predicate.

Parameters:

`{pred}` (`fun(...):boolean`) Predicate function. Takes all values returned from the previous stage in the pipeline as arguments and returns true if the predicate matches.

Iter:any(`{pred}`) `Iter:any())` Returns true if any of the items in the iterator match the given predicate.

Parameters:

`{pred}` (`fun(...):boolean`) Predicate function. Takes all values returned from the previous stage in the pipeline as arguments and returns true if the predicate matches.

Iter:each(`{f}`) `Iter:each())` Calls a function once for each item in the pipeline, draining the iterator.

For functions with side effects. To modify the values in the iterator, use Iter:map()).

Parameters:

`{f}` (`fun(...)`) Function to execute for each item in the pipeline. Takes all of the values returned by the previous stage in the pipeline as arguments.

Iter:enumerate() `Iter:enumerate())` Yields the item index (count) and value for each item of an iterator pipeline.

For list tables, this is more efficient:

urltomarkdowncodeblockplaceholder1270.589941484771854

instead of:

urltomarkdowncodeblockplaceholder1280.9777426514684822

Example:

urltomarkdowncodeblockplaceholder1290.377702004265434

Iter:filter(`{f}`) `Iter:filter())` Filters an iterator pipeline.

Example:

urltomarkdowncodeblockplaceholder1300.24506147403797884

Parameters:

`{f}` (`fun(...):boolean`) Takes all values returned from the previous stage in the pipeline and returns false or nil if the current iterator element should be removed.

Iter:find(`{f}`) `Iter:find())` Find the first value in the iterator that satisfies the given predicate.

Advances the iterator. Returns nil and drains the iterator if no value is found.

Examples:

urltomarkdowncodeblockplaceholder1310.17152374512369795

Iter:flatten(`{depth}`) `Iter:flatten())` Flattens a list-iterator, un-nesting nested values up to the given `{depth}`. Errors if it attempts to flatten a dict-like value.

Examples:

urltomarkdowncodeblockplaceholder1320.8407398175587595

Parameters:

`{depth}` (`number?`) Depth to which list-iterator should be flattened (defaults to 1)

Iter:fold(`{init}`, `{f}`) `Iter:fold())` Folds ("reduces") an iterator into a single value. `Iter:reduce())`

Examples:

urltomarkdowncodeblockplaceholder1330.6204365948339325

Parameters:

`{init}` (`any`) Initial value of the accumulator.

`{f}` (`fun(acc:A, ...):A`) Accumulation function.

Iter:join(`{delim}`) `Iter:join())` Collect the iterator into a delimited string.

Each element in the iterator is joined into a string separated by `{delim}`.

Consumes the iterator.

Parameters:

`{delim}` (`string`) Delimiter

Iter:last() `Iter:last())` Drains the iterator and returns the last item.

Example:

urltomarkdowncodeblockplaceholder1340.868519376834646

Iter:map(`{f}`) `Iter:map())` Maps the items of an iterator pipeline to the values returned by `f`.

If the map function returns nil, the value is filtered from the iterator.

Example:

urltomarkdowncodeblockplaceholder1350.11589626835648748

Parameters:

`{f}` (`fun(...):...:any`) Mapping function. Takes all values returned from the previous stage in the pipeline as arguments and returns one or more new values, which are used in the next pipeline stage. Nil return values are filtered from the output.

Iter:next() `Iter:next())` Gets the next value from the iterator.

Example:

urltomarkdowncodeblockplaceholder1360.7497388702225476

Iter:nth(`{n}`) `Iter:nth())` Gets the nth value of an iterator (and advances to it).

If `n` is negative, offsets from the end of a list-iterator.

Example:

urltomarkdowncodeblockplaceholder1370.12201413394633809

Parameters:

`{n}` (`number`) Index of the value to return. May be negative if the source is a list-iterator.

Iter:peek() `Iter:peek())` Gets the next value in a list-iterator without consuming it.

Example:

urltomarkdowncodeblockplaceholder1380.6120792908547625

Iter:pop() `Iter:pop())` "Pops" a value from a list-iterator (gets the last value and decrements the tail).

Example:

urltomarkdowncodeblockplaceholder1390.956725056935767

Example:

urltomarkdowncodeblockplaceholder1400.7556401086826683

Iter:rfind(`{f}`) `Iter:rfind())` Gets the first value satisfying a predicate, from the end of a list-iterator.

Advances the iterator. Returns nil and drains the iterator if no value is found.

Examples:

urltomarkdowncodeblockplaceholder1410.31779031676866176

Iter:rpeek() `Iter:rpeek())` Gets the last value of a list-iterator without consuming it.

Example:

urltomarkdowncodeblockplaceholder1420.4784821171025462

Iter:rskip(`{n}`) `Iter:rskip())` Discards `n` values from the end of a list-iterator pipeline.

Example:

urltomarkdowncodeblockplaceholder1430.3657723025029076

Parameters:

`{n}` (`number`) Number of values to skip.

Iter:skip(`{n}`) `Iter:skip())` Skips `n` values of an iterator pipeline.

Example:

urltomarkdowncodeblockplaceholder1440.3762470817003154

Parameters:

`{n}` (`number`) Number of values to skip.

Iter:slice(`{first}`, `{last}`) `Iter:slice())` Sets the start and end of a list-iterator pipeline.

Equivalent to `:skip(first - 1):rskip(len - last + 1)`.

Parameters:

`{first}` (`number`)

`{last}` (`number`)

Iter:take(`{n}`) `Iter:take())` Transforms an iterator to yield only the first n values.

Example:

urltomarkdowncodeblockplaceholder1450.6384961151172754

Parameters:

`{n}` (`integer`)

Iter:totable() `Iter:totable())` Collect the iterator into a table.

The resulting table depends on the initial source in the iterator pipeline. Array-like tables and function iterators will be collected into an array-like table. If multiple values are returned from the final stage in the iterator pipeline, each value will be included in a table.

Examples:

urltomarkdowncodeblockplaceholder1460.5596784708954385

The generated table is an array-like table with consecutive, numeric indices. To create a map-like table with arbitrary keys, use Iter:fold()).

Lua module: vim.snippet vim.snippet
---------------------------------------------------

Fields:

`{direction}` (`vim.snippet.Direction`) Navigation direction. -1 for previous, 1 for next.

vim.snippet.active(`{filter}`) `vim.snippet.active())` Returns `true` if there's an active snippet in the current buffer, applying the given filter if provided.

You can use this function to navigate a snippet as follows:

urltomarkdowncodeblockplaceholder1470.9129194941022836

Parameters:

`{filter}` (`vim.snippet.ActiveFilter?`) Filter to constrain the search with:

`direction` (vim.snippet.Direction): Navigation direction. Will return `true` if the snippet can be jumped in the given direction. See vim.snippet.ActiveFilter.

Parameters:

`{input}` (`string`)

vim.snippet.jump(`{direction}`) `vim.snippet.jump())` Jumps to the next (or previous) placeholder in the current snippet, if possible.

For example, map `<Tab>` to jump while a snippet is active:

urltomarkdowncodeblockplaceholder1480.38914287342945175

Parameters:

`{direction}` (`vim.snippet.Direction`) Navigation direction. -1 for previous, 1 for next.

vim.snippet.stop() `vim.snippet.stop())` Exits the current snippet.

Lua module: vim.text vim.text
------------------------------------------

vim.text.hexdecode(`{enc}`) `vim.text.hexdecode())` Hex decode a string.

Parameters:

`{enc}` (`string`) String to decode

Return (multiple):

(`string?`) Decoded string (`string?`) Error message, if any

vim.text.hexencode(`{str}`) `vim.text.hexencode())` Hex encode a string.

Parameters:

`{str}` (`string`) String to encode

Return:

(`string`) Hex encoded string

Lua module: tohtml vim.tohtml
--------------------------------------------

:\[range\]TOhtml `{file}` `:TOhtml` Converts the buffer shown in the current window to HTML, opens the generated HTML in a new split window, and saves its contents to `{file}`. If `{file}` is not given, a temporary file (created by tempname())) is used.

tohtml.tohtml(`{winid}`, `{opt}`) `tohtml.tohtml.tohtml())` Converts the buffer shown in the window `{winid}` to HTML and returns the output as a list of string.

Parameters:

`{winid}` (`integer?`) Window to convert (defaults to current window)

`{opt}` (`table?`) Optional parameters.

`{title}` (`string|false`, default: buffer name) Title tag to set in the generated HTML code.

`{number_lines}` (`boolean`, default: `false`) Show line numbers.

`{font}` (`string[]|string`, default: `guifont`) Fonts to use.

`{width}` (`integer`, default: 'textwidth' if non-zero or window width otherwise) Width used for items which are either right aligned or repeat a character infinitely.

`{range}` (`integer[]`, default: entire buffer) Range of rows to use.