# Manual
This document goes over how to set up fennel-ls.

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
I think `fennel-ls` and `fennel-ls-git` may be in the AUR.

#### Luarocks
Alternatively, `fennel-ls` is available in LuaRocks. Luarocks is kind of a pain to support though.
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


## Configuration
fennel-ls can be configured by creating a file named `flsproject.fnl` in your
workspace root. Any setting that isn't provided will be filled in with the
defaults, which means that `{}` is a valid configuration with default settings.
You can provide different settings in the same shape as the default settings to
override the defaults.

The default `flsproject.fnl` settings are:

```fnl
{:fennel-path "./?.fnl;./?/init.fnl;src/?.fnl;src/?/init.fnl"
 :macro-path "./?.fnl;./?/init-macros.fnl;./?/init.fnl;src/?.fnl;src/?/init-macros.fnl;src/?/init.fnl"
 :lua-version "lua54"
 :libraries {:love2d false
             :tic-80 false}
 :extra-globals ""
 :lints {:unused-definition true
         :unknown-module-field true
         :unnecessary-method true
         :bad-unpack true
         :var-never-set true
         :op-with-no-arguments true
         :multival-in-middle-of-call true}}
```

extra-globals: Space separated list of allowed global identifiers; in addition to a set of predefined lua globals.

version: One of lua51, lua52, lua53, or lua54.

libraries: This setting controls which extra documentation fennel-ls can load in to your environment. I've only done this for tic-80 for now.


## Usage

Fennel-ls *cannot* tell the difference between a regular file and a macro file.
You can ask fennel-ls to **treat your file as a macro file** if the first line
exactly matches `;; fennel-ls: macro-file`. Expect this to change at some point
in the future when I come up with a better way to specify which files are meant
to be macro files.

## Features


Feature         | Locals | Fields | Builtin Globals | Across Files | Builtins | Macros | User globals |
--------------- | ------ | ------ | --------------- | ------------ | -------- | ------ | ------------ |
Completions     | [X]    | [X]    | [X]             | [X]          | [X]      | [X]    | [ ]          |
Hover           | [X]    | [X]    | [X]             | [X]          | [X]      | [X]    | [ ]          |
Goto Definition | [X]    | [X]    | N/A             | [X]          | N/A      | [ ]    | [ ]          |
Rename          | [X]    | [ ]    | N/A             | [ ]          | N/A      | [ ]    | [ ]          |
Goto Reference  | [X]    | [ ]    | [ ]             | [ ]          | [ ]      | [ ]    | [ ]          |

Fennel-ls can report all fennel compiler errors, plus a few custom lints.

## CLI Usage
```sh
fennel-ls --lint my-file.fnl f2.fnl # prints diagnostics for the files given
```

This will analyze the given files, and print out all compiler errors and lints, without launching a server.

