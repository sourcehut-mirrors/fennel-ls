# fennel-ls external library documentation

fennel-ls can load external documentation and completion information for
situations where it's not available at runtime.

## Installing docsets

The documentation files (also called docsets) are loaded from
`~/.local/share/fennel-ls/docsets/` and they are regular Lua files that contain
a single table describing the information to be displayed by the language
server.

> fennel-ls follows the XDG base directory convention, so if you changed
> `$XDG_DATA_HOME` the files will be loaded from the location you specified.

To install a new docset and make it available to fennel-ls, download the `.lua`
file for your library and place it in `~/.local/share/fennel-ls/docsets/`.

> You can find a list of the available docsets on the [Fennel
> wiki](http://wiki.fennel-lang.org/LanguageServer).

Next, you have to tell fennel-ls to load this library by adding it to the
`flsproject.fnl` file at the root of your project.

```fnl
{:libraries {:library-name true}}
```

The library name you specify here must match the name of the docset file you
downloaded.

Restart the LSP client or your editor and the new completions should be
available.

## Creating docsets

The top level Lua table in the docset should contain symbol names as keys and
*bindings* as values.

```fnl
{:symbol-a {
    ;; binding table
  }
 :symbol-b {
    ;; binding table
 }}
```

Each binding is table that describes that symbol. This is an example from the
Tic-80 library:

```fnl
{:binding "elli"
 :metadata {:fls/itemKind "Function"
            :fnl/arglist ["x" "y" "a" "b" "color"]
            :fnl/docstring "This function draws a filled ellipse of the desired
a, b radiuses and color with its center at x, y.
"}}
```

- `binding` is the full name of the symbol, so if this symbol is part of a
  module the name should be in the form `module.symbol`

- `fls/itemKind` describes the kind of this symbol, it can be any one of the
  [CompletionItemKind](https://microsoft.github.io/language-server-protocol/specifications/lsp/3.17/specification/#completionItemKind)
  values from the LSP specification.

- `fnl/arglist` and `fnl/docstring` should follow the usual Fennel conventions.

Symbols can also have sub-symbols, represented as fields in the binding
table. This is an example from the LÖVE library:

```fnl
{:love {:binding "love"
        :metadata {:fls/itemKind "Module"
                   :fnl/docstring "Modules can have documentation too"}
        :fields {:conf {:binding "love.conf"
                        :metadata {:fls/itemKind "Function"
                                   :fnl/arglist ["t"]
                                   :fnl/docstring "Using the love.conf function,
you can set some configuration options, [...]"}
```

### Complete example

Here is a simplified complete example to show all the pieces together, mainly
the top level table that contains all the bindings.

```fnl
{
 {:math {:binding "math"
         :metadata {:fls/itemKind "Module"
                    :fnl/docstring "A module for math functions"}
         :fields {:atan {:binding "math.atan"
                         :metadata {:fls/itemKind "Function"
                                    :fnl/arglist [a]
                                    :fnl/docstring "Arc tangent"}}
                  :phi {:binding "math.phi"
                        :metadata {:fls/itemKind "Constant"
                                   :fnl/docstring "It's golden!"}}}}}

 {:config {:binding "config"
           :metadata {:fls/itemKind "Function"
                      :fnl/arglist []
                      :fnl/docstring "A function to read the config options"}}}
}
```

The easiest way of generating this format is to create the table in a Fennel
script and then serializing it using the `fennel.view` function.

## Compilation

Finally, to be usable by fennel-ls the table needs to be compiled to Lua and
installed in the docsets directory.

```sh
fennel library-docset.fnl > library-docset.lua
cp library-docset.lua $HOME/.local/share/fennel-ls/docsets/
```

Refer to the
[fennel-ls-docsets](http://git.sr.ht/~technomancy/fennel-ls-docsets) repository
for an example of how to script these steps.
