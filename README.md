# fennel-ls
[Source](https://git.sr.ht/~xerool/fennel-ls) | [Issues](https://todo.sr.ht/~xerool/fennel-ls) | [Mailing List](https://lists.sr.ht/~xerool/fennel-ls)

Provides intelligent editing features for fennel files.

## Installation

### fennel-ls Language Server Binary
On Linux or Mac OS,
```sh
$ git clone https://git.sr.ht/~xerool/fennel-ls
$ cd fennel-ls
$ make
```
will create a bleeding-edge latest git `fennel-ls` binary for you.

#### Arch Linux
I think `fennel-ls` and `fennel-ls-git` is in the AUR.

#### Luarocks
`fennel-ls` is available in LuaRocks.
```sh
luarocks install fennel-ls
```
#### NixOS
If you are using NixOS, you can use the included `/flake.nix` or `/default.nix`.

### Emacs
prerequisites: You have installed the [fennel-ls binary](#fennel-ls-language-server-binary).

For Emacs 30+, eglot will use fennel-ls automatically if its on the $PATH.
For older versions:
```lisp
(with-eval-after-load 'eglot
  (add-to-list 'eglot-server-programs '(fennel-mode . ("fennel-ls"))))
```
This code tells eglot to connect fennel-ls to your fennel-mode buffers.

### Neovim
prerequisites: You have installed the [fennel-ls binary](#fennel-ls-language-server-binary).
If you're using neovim+lspconfig, use this snippet:
```lua
require("lspconfig").fennel_ls.setup()
```

If you're also using mason and you want to install fennel-ls that way, you can
use mason-lspconfig to ensure fennel-ls is installed:
```lua
require("mason-lspconfig").setup {
    ensure_installed = {"fennel_ls"}
}
```

### Other editors
It should be possible to set up for other text editors, but the instructions
depend on which editor you use. Generally you need to tell your editor:
* "fennel-ls" is a language server program on the $PATH
* it should be run for fennel files.

## Usage
You can ask fennel-ls to **treat your file as a macro file** if the first line
exactly matches `;; fennel-ls: macro-file`. Expect this to change at some point
in the future when I come up with a better way to specify which files are meant
to be macro files.

## CLI Usage
```sh
fennel-ls --lint my-file.fnl f2.fnl # prints diagnostics for the files given
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

extra-globals: Space separated list of allowed global identifiers; in addition to a set of predefined lua globals.

Your editor can send these settings using one of these two methods:
* The client sends an `initialize` request with the structure `{initializationOptions: {"fennel-ls": {...}}, ...}`
* The client sends a `workspace/didChangeConfiguration` notfication containing the field `{settings: {"fennel-ls": {YOUR_SETTINGS}}}`

## License
fennel-ls is licensed under the MIT license. See LICENSE for more info.
This project also contains files from other projects:
* fennel and deps/fennel.lua are compiled from [fennel](https://git.sr.ht/~technomancy/fennel) [MIT license]
* deps/faith.lua is from [faith](https://git.sr.ht/~technomancy/faith) [MIT license]
* deps/pl/stringio.lua is from [Penlight](https://github.com/lunarmodules/Penlight) [MIT license]
* deps/dkjson.lua is from [dkjson](http://dkolf.de/dkjson-lua/) [MIT license]

* src/fennel-ls/docs/generated/* contains files generated from other sources. It contains information from:
  * the [lua](https://lua.org) reference [MIT license]
  * [TIC80's "learn" webpage](https://tic80.com/learn) [MIT license]
