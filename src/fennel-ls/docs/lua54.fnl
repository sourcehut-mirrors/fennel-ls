"Lua 5.4 Documentation of globals.
I wish these were generated, but I did them by hand:

Pandoc converted the reference file to .md, and I manually sliced up
and edited the markdown into this page."

(local {: sym} (require :fennel))
(local docs
  {:_G {:metadata {:fnl/docstring "A global variable (not a function) that holds the global environment. Lua and Fennel do not use this variable; changing its value does not affect any environment, nor vice versa."}}
   :_VERSION {:metadata {:fnl/docstring "A global variable (not a function) that holds a string containing the running Lua version. The current value of this variable is `Lua 5.4`."}}
   :arg {:metadata {:fnl/docstring "A global variable (not a function) that holds the command line arguments."}}
   :assert {:metadata {:fnl/arglist [:v :?message]
                       :fnl/docstring "Raises an error if the value of its argument `v` is false (i.e., **nil**
or **false**); otherwise, returns all its arguments. In case of error,
`?message` is the error object; when absent, it defaults to
\"`assertion failed!`\""}}
   :collectgarbage {:metadata {:fnl/arglist [:?opt :?arg]
                               :fnl/docstring "This function is a generic interface to the garbage collector. It
performs different functions according to its first argument, `opt`:

-   **\"`collect`\":** Performs a full garbage-collection cycle. This is
    the default option.
-   **\"`stop`\":** Stops automatic execution of the garbage collector.
    The collector will run only when explicitly invoked, until a call to
    restart it.
-   **\"`restart`\":** Restarts automatic execution of the garbage
    collector.
-   **\"`count`\":** Returns the total memory in use by Lua in Kbytes.
    The value has a fractional part, so that it multiplied by 1024 gives
    the exact number of bytes in use by Lua.
-   **\"`step`\":** Performs a garbage-collection step. The step
    \"size\" is controlled by `arg`. With a zero value, the collector
    will perform one basic (indivisible) step. For non-zero values, the
    collector will perform as if that amount of memory (in Kbytes) had
    been allocated by Lua. Returns **true** if the step finished a
    collection cycle.
-   **\"`isrunning`\":** Returns a boolean that tells whether the
    collector is running (i.e., not stopped).
-   **\"`incremental`\":** Change the collector mode to incremental.
    This option can be followed by three numbers: the garbage-collector
    pause, the step multiplier, and the step size (see
    [§2.5.1](https://lua.org/manual/5.4/manual.html#2.5.1)). A zero means
    to not change that value.
-   **\"`generational`\":** Change the collector mode to generational.
    This option can be followed by two numbers: the garbage-collector
    minor multiplier and the major multiplier (see
    [§2.5.2](https://lua.org/manual/5.4/manual.html#2.5.2)). A zero means
    to not change that value.

See [§2.5](https://lua.org/manual/5.4/manual.html#2.5) for more details
about garbage collection and some of these options.

This function should not be called by a finalizer."}}
   :coroutine {} ;; TODO support for modules
   :debug {} ;; TODO support for modules
   :dofile {:metadata {:fnl/arglist [:?filename]
                       :fnl/docstring "Opens the named file and executes its content as a Lua chunk. When
called without arguments, `dofile` executes the content of the standard
input (`stdin`). Returns all values returned by the chunk. In case of
errors, `dofile` propagates the error to its caller. (That is, `dofile`
does not run in protected mode.)"}}
   :error {:metadata {:fnl/arglist [:message :?level]
                      :fnl/docstring "Raises an error (see [§2.3](https://lua.org/manual/5.4/manual.html#2.3)) with `message` as the error object.
This function never returns.

Usually, `error` adds some information about the error position at the
beginning of the message, if the message is a string. The `level`
argument specifies how to get the error position. With level 1 (the
default), the error position is where the `error` function was called.
Level 2 points the error to where the function that called `error` was
called; and so on. Passing a level 0 avoids the addition of error
position information to the message."}}
   :getmetatable {:metadata {:fnl/arglist [:object]
                             :fnl/docstring "If `object` does not have a metatable, returns **nil**. Otherwise, if
the object\'s metatable has a `__metatable` field, returns the
associated value. Otherwise, returns the metatable of the given object."}}
   :io {} ;; TODO support for modules
   :ipairs {:metadata {:fnl/arglist [:t]
                       :fnl/docstring  "Returns three values (an iterator function, the table `t`, and 0) so
that the construction

```fnl
(each [i v (ipairs t)] <body>)
```

will iterate over the key--value pairs (`1,t[1]`), (`2,t[2]`), `...`, up
to the first absent index."}}
   :load {:metadata {:fnl/arglist [:chunk :?chunkname :?mode :?env]
                     :fnl/docstring "Loads a chunk.

If `chunk` is a string, the chunk is this string. If `chunk` is a
function, `load` calls it repeatedly to get the chunk pieces. Each call
to `chunk` must return a string that concatenates with previous results.
A return of an empty string, **nil**, or no value signals the end of the
chunk.

If there are no syntactic errors, `load` returns the compiled chunk as a
function; otherwise, it returns **fail** plus the error message.

When you load a main chunk, the resulting function will always have
exactly one upvalue, the `_ENV` variable (see
[§2.2](https://lua.org/manual/5.4/manual.html#2.2)). However, when you
load a binary chunk created from a function (see
[`string.dump`](https://lua.org/manual/5.4/manual.html#pdf-string.dump)),
the resulting function can have an arbitrary number of upvalues, and there
is no guarantee that its first upvalue will be the `_ENV` variable. (A
non-main function may not even have an `_ENV` upvalue.)

Regardless, if the resulting function has any upvalues, its first
upvalue is set to the value of `env`, if that parameter is given, or to
the value of the global environment. Other upvalues are initialized with
**nil**. All upvalues are fresh, that is, they are not shared with any
other function.

`chunkname` is used as the name of the chunk for error messages and debug
information (see [§4.7](https://lua.org/manual/5.4/manual.html#4.7)). When
absent, it defaults to `chunk`, if `chunk` is a string, or to
\"`=(load)`\" otherwise.

The string `mode` controls whether the chunk can be text or binary (that
is, a precompiled chunk). It may be the string \"`b`\" (only binary
chunks), \"`t`\" (only text chunks), or \"`bt`\" (both binary and text).
The default is \"`bt`\".

It is safe to load malformed binary chunks; `load` signals an
appropriate error. However, Lua does not check the consistency of the
code inside binary chunks; running maliciously crafted bytecode can
crash the interpreter."}}
   :loadfile {:metadata {:fnl/arglist [:filename :?mode :?env]
                         :fnl/docstring "Similar to [`load`](https://lua.org/manual/5.4/manual.html#pdf-load), but
gets the chunk from file `filename` or from the standard input, if no file
name is given."}}
   :math {} ;; TODO support for modules
   :next {:metadata {:fnl/arglist [:table :?index]
                     :fnl/docstring "Allows a program to traverse all fields of a table. Its first argument
is a table and its second argument is an index in this table. A call to
`next` returns the next index of the table and its associated value.
When called with **nil** as its second argument, `next` returns an
initial index and its associated value. When called with the last index,
or with **nil** in an empty table, `next` returns **nil**. If the second
argument is absent, then it is interpreted as **nil**. In particular,
you can use `next(t)` to check whether a table is empty.

The order in which the indices are enumerated is not specified, *even
for numeric indices*. (To traverse a table in numerical order, use **for**.)

You should not assign any value to a non-existent field in a table
during its traversal. You may however modify existing fields. In
particular, you may set existing fields to **nil**."}}
   :os {} ;; TODO support for modules
   :package {} ;; TODO support for modules
   :pairs {:metadata {:fnl/arglist [:t]
                      :fnl/docstring "If `t` has a metamethod `__pairs`, calls it with `t` as argument and
returns the first three results from the call.

Otherwise, returns three values: the
[`next`](https://lua.org/manual/5.4/manual.html#pdf-next) function, the
table `t`, and **nil**, so that the construction

```fnl
(each [k v (pairs t) <body>)
```

will iterate over all key--value pairs of table `t`.

See function [`next`](https://lua.org/manual/5.4/manual.html#pdf-next) for
the caveats of modifying the table during its traversal."}}
   :pcall {:metadata {:fnl/arglist [:f :...]
                      :fnl/docstring "Calls the function `f` with the given arguments in *protected mode*.
This means that any error inside `f` is not propagated; instead, `pcall`
catches the error and returns a status code. Its first result is the
status code (a boolean), which is **true** if the call succeeds without
errors. In such case, `pcall` also returns all results from the call,
after this first result. In case of any error, `pcall` returns **false**
plus the error object. Note that errors caught by `pcall` do not call a
message handler."}}
   :print {:metadata {:fnl/arglist [:...]
                      :fnl/docstring "Receives any number of arguments and prints their values to `stdout`,
converting each argument to a string following the same rules of
[`tostring`](https://lua.org/manual/5.4/manual.html#pdf-tostring).

The function `print` is not intended for formatted output, but only as
a quick way to show a value, for instance for debugging. For complete
control over the output, use
[`string.format`](https://lua.org/manual/5.4/manual.html#pdf-string.format)
and [`io.write`](https://lua.org/manual/5.4/manual.html#pdf-io.write)."}}
   :rawequal {:metadata {:fnl/arglist [:v1 :v2]
                         :fnl/docstring "Checks whether `v1` is equal to `v2`, without invoking the `__eq`
metamethod. Returns a boolean."}}
   :rawget {:metadata {:fnl/arglist [:table :index]
                       :fnl/docstring "Gets the real value of `(. table index)`, without using the `__index`
metavalue. `table` must be a table; `index` may be any value."}}
   :rawlen {:metadata {:fnl/arglist [:v]
                       :fnl/docstring "Returns the length of the object `v`, which must be a table or a string,
without invoking the `__len` metamethod. Returns an integer."}}
   :rawset {:metadata {:fnl/arglist [:table :index :value]
                       :fnl/docstring "Sets the real value of `(. table index)` to `value`, without using the
`__newindex` metavalue. `table` must be a table, `index` any value
different from **nil** and NaN, and `value` any Lua value.

This function returns `table`."}}
   :require {:metadata {:fnl/arglist [:modname]
                        :fnl/docstring "Loads the given module. The function starts by looking into the
[`package.loaded`](https://lua.org/manual/5.4/manual.html#pdf-package.loaded)
table to determine whether `modname` is already loaded. If it is, then
`require` returns the value stored at `package.loaded[modname]`. (The
absence of a second result in this case signals that this call did not
have to load the module.) Otherwise, it tries to find a *loader* for the
module.

To find a loader, `require` is guided by the table
[`package.searchers`](https://lua.org/manual/5.4/manual.html#pdf-package.searchers).
Each item in this table is a search function, that searches for the module
in a particular way. By changing this table, we can change how `require`
looks for a module. The following explanation is based on the default
configuration for
[`package.searchers`](https://lua.org/manual/5.4/manual.html#pdf-package.searchers).

First `require` queries `package.preload[modname]`. If it has a value,
this value (which must be a function) is the loader. Otherwise `require`
searches for a Lua loader using the path stored in
[`package.path`](https://lua.org/manual/5.4/manual.html#pdf-package.path).
If that also fails, it searches for a C loader using the path stored in
[`package.cpath`](https://lua.org/manual/5.4/manual.html#pdf-package.cpath).
If that also fails, it tries an *all-in-one* loader (see
[`package.searchers`](https://lua.org/manual/5.4/manual.html#pdf-package.searchers)).

Once a loader is found, `require` calls the loader with two arguments:
`modname` and an extra value, a *loader data*, also returned by the
searcher. The loader data can be any value useful to the module; for the
default searchers, it indicates where the loader was found. (For
instance, if the loader came from a file, this extra value is the file
path.) If the loader returns any non-nil value, `require` assigns the
returned value to `package.loaded[modname]`. If the loader does not
return a non-nil value and has not assigned any value to
`package.loaded[modname]`, then `require` assigns **true** to this
entry. In any case, `require` returns the final value of
`package.loaded[modname]`. Besides that value, `require` also returns as
a second result the loader data returned by the searcher, which
indicates how `require` found the module.

If there is any error loading or running the module, or if it cannot
find any loader for the module, then `require` raises an error."}}
   :select {:metadata {:fnl/arglist [:index :...]
                       :fnl/docstring "If `index` is a number, returns all arguments after argument number
`index`; a negative number indexes from the end (-1 is the last
argument). Otherwise, `index` must be the string `\"#\"`, and `select`
returns the total number of extra arguments it received."}}
   :setmetatable {:metadata {:fnl/arglist [:table :metatable]
                             :fnl/docstring "Sets the metatable for the given table. If `metatable` is **nil**,
removes the metatable of the given table. If the original metatable has
a `__metatable` field, raises an error.

This function returns `table`.

To change the metatable of other types from Lua code, you must use the
debug library ([§6.10](https://lua.org/manual/5.4/manual.html#6.10))."}}
   :string {} ;; TODO support modules
   :table {} ;; TODO support modules
   :tonumber {:metadata {:fnl/arglist [:e :?base]
                         :fnl/docstring "When called with no `base`, `tonumber` tries to convert its argument to
a number. If the argument is already a number or a string convertible to
a number, then `tonumber` returns this number; otherwise, it returns
**fail**.

The conversion of strings can result in integers or floats, according to
the lexical conventions of Lua (see
[§3.1](https://lua.org/manual/5.4/manual.html#3.1)). The string may have
leading and trailing spaces and a sign.

When called with `base`, then `e` must be a string to be interpreted as
an integer numeral in that base. The base may be any integer between 2
and 36, inclusive. In bases above 10, the letter \'`A`\' (in either
upper or lower case) represents 10, \'`B`\' represents 11, and so forth,
with \'`Z`\' representing 35. If the string `e` is not a valid numeral
in the given base, the function returns **fail**."}}
   :tostring {:metadata {:fnl/arglist [:v]
                         :fnl/docstring "Receives a value of any type and converts it to a string in a
human-readable format.

If the metatable of `v` has a `__tostring` field, then `tostring` calls
the corresponding value with `v` as argument, and uses the result of the
call as its result. Otherwise, if the metatable of `v` has a `__name`
field with a string value, `tostring` may use that string in its final
result.

For complete control of how numbers are converted, use
[`string.format`](https://lua.org/manual/5.4/manual.html#pdf-string.format)."}}
   :type {:metadata {:fnl/arglist [:v]
                     :fnl/docstring "Returns the type of its only argument, coded as a string. The possible
results of this function are \"`nil`\" (a string, not the value
**nil**), \"`number`\", \"`string`\", \"`boolean`\", \"`table`\",
\"`function`\", \"`thread`\", and \"`userdata`\"."}}
   :utf8 {} ;; TODO support modules
   :warn {:metadata {:fnl/arglist [:msg1 :...]
                     :fnl/docstring "Emits a warning with a message composed by the concatenation of all its
arguments (which should be strings).

By convention, a one-piece message starting with \'`@`\' is intended to
be a *control message*, which is a message to the warning system itself.
In particular, the standard warning function in Lua recognizes the
control messages \"`@off`\", to stop the emission of warnings, and
\"`@on`\", to (re)start the emission; it ignores unknown control
messages."}}
   :xpcall {:metadata {:fnl/arglist [:f :msgh :...]
                       :fnl/docstring "This function is similar to [`pcall`](https://lua.org/manual/5.4/manual.html#pdf-pcall), except that it sets a
new message handler `msgh`."}}})

(each [k v (pairs docs)]
  (set v.binding (sym k)))

docs
