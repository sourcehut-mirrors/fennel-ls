# fennel-ls
A language server for Fennel.
Supports Go-to-definition, and a little bit of completion suggestions.
Fennel-LS uses static analysis, and does not execute your code.

You can ask fennel-ls to **treat your file as a macro file** if the first line
exactly matches `;; fennel-ls: macro-file`. Expect this to change at some point
in the future when I come up with a better way to specify which files are meant
to be macro files.

## Table of Contents

- [Installation](#installation)
- [Usage](#usage)

## Installation
I recommend building from source. I promise it's really easy! You need to have `make` and `lua` (5.1+). Every other dependency is included. See the License section at the bottom of this file for more info on the bundled dependencies.
### Make (writes the file `/usr/local/bin/fennel-ls`)
```sh
make && sudo make install
```

### Make (writes the file `$HOME/bin/fennel-ls`)
```sh
make install PREFIX=$HOME
```

### Make (writes the file `./fennel-ls`)
```sh
make
```

### NixOS
If you are using NixOS, you can use the included `/flake.nix` or `/default.nix`.

### LuaRocks
I recommend just using `make` if possible, but if not, `fennel-ls` can be built with LuaRocks.
```sh
luarocks install fennel-ls --tree /path/to/your/new/luarocks/tree
```

## Usage
Once you've installed the binary somewhere on your computer, the next step is to set up your text editor! Each editor has a different way of doing it.

If you are using vim+lspconfig, it is pretty simple:
```lua
require('lspconfig').fennel_ls.setup()
```

For Emacs, (eglot, built-in to 29+):
```lisp
(with-eval-after-load 'eglot
  (add-to-list 'eglot-server-programs '(fennel-mode . ("fennel-ls"))))
```

It should be possible to set up for other text editors, but the instructions depend on which editor you use.
Generally you need to give this information to your editor:
* "fennel-ls" is a language server program on the $PATH
* it should be run for .fnl files.

## Usage

You can gather diagnostics without connecting your editor:

```sh
fennel-ls --check my-file.fnl f2.fnl # prints diagnostics for the files given
```

This will analyze the given files, and print out all compiler errors and lints.

# Default Settings

fennel-ls can be configured over LSP. Any setting that's not provided will be filled in with the defaults, which means that `{}` will be a valid configuration with default settings. You can provide different settings in the same shape as the default settings in order to override the defaults.

fennel-ls default settings:
```json
{
  "fennel-ls": {
    "fennel-path": "./?.fnl;./?/init.fnl;src/?.fnl;src/?/init.fnl",
    "macro-path": "./?.fnl;./?/init-macros.fnl;./?/init.fnl;src/?.fnl;src/?/init-macros.fnl;src/?/init.fnl",
    "checks": {
      "unused-definition": true,
      "unknown-module-field": true,
      "unnecessary-method": true,
      "bad-unpack": true,
      "var-never-set": true,
      "op-with-no-arguments": true,
      "multival-in-middle-of-call": true
    },
    "extra-globals": ""
  }
}
```

extra-globals
: Space separated list of allowed global identifiers; in addition to a set of predefined lua globals.

Your editor can send these settings using one of these two methods:
* The client sends an `initialize` request with the structure `{initializationOptions: {"fennel-ls": {...}}, ...}`
* The client sends a `workspace/didChangeConfiguration` notfication containing the field `{settings: {"fennel-ls": {YOUR_SETTINGS}}}`

## Adding a lint
You can't load external lint rules with fennel-ls, but I would love to receive patches that add new lint rules!
[Instructions to add a lint.](Adding-a-Lint-Rule.md)

## License
fennel-ls is licensed under the MIT license. See LICENSE for more info.
This project also contains files from other projects:
* test/pl/* comes from [Penlight](https://github.com/lunarmodules/Penlight) [MIT license]
  * [LICENSE](test/pl/LICENSE.md)
* src/fennel-ls/json/* is modified, but is originally from [json.lua](https://github.com/rxi/json.lua) [MIT license]
  * [LICENSE](src/fennel-ls/json/LICENSE)
* src/fennel-ls/docs/* contains information from the [lua](https://lua.org) reference [MIT license]
* test/faith/faith.lua is from [faith](https://git.sr.ht/~technomancy/faith) [MIT license]
* fennel and src/fennel.lua are compiled from [fennel](https://git.sr.ht/~technomancy/fennel) [MIT license]
