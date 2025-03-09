# Installation

## Manual installation

To install from source on a unix system that has Lua installed:

```sh
$ git clone https://git.sr.ht/~xerool/fennel-ls
$ cd fennel-ls
$ make
```

This build will create a `fennel-ls` executable for you using your default
system `lua`; use `make LUA=luajit` etc to use a different Lua version.

Run `make install PREFIX=$HOME` to put it in `~/bin` or `sudo make install` for
a system wide install.

You may want to also install [docsets](docsets.md) for external libraries.

## Packages

#### Arch Linux

I think `fennel-ls` and `fennel-ls-git` may be in the AUR.

#### NixOS

Included in [nixpkgs](https://github.com/NixOS/nixpkgs/blob/master/pkgs/by-name/fe/fennel-ls/package.nix)

#### Debian/Ubuntu

Unofficial `.deb` packages are available at
[https://apt.technomancy.us](https://apt.technomancy.us).

#### Luarocks

Alternatively, `fennel-ls` is available in LuaRocks, but recommendation is to
use one of the other packaging solutions over LuaRocks, if available.

```sh
luarocks install fennel-ls
```

## Editor integration

The following instructions assume you have installed `fennel-ls` as described
in the previous section.

### Emacs

On Emacs 30+, eglot will use fennel-ls automatically if it can be found in your `$PATH`.

For older versions:

```lisp
(with-eval-after-load 'eglot
  (add-to-list 'eglot-server-programs '(fennel-mode . ("fennel-ls"))))
```

This code tells eglot to connect fennel-ls to your fennel-mode buffers.

### Neovim

If you're using neovim+lspconfig, use this snippet:
```lua
require("lspconfig").fennel_ls.setup({})
```

If you're also using mason and you want to install fennel-ls that way, you can
use mason-lspconfig to ensure fennel-ls is installed:
```lua
require("mason-lspconfig").setup {
    ensure_installed = {"fennel_ls"}
}
```

### Sublime Text

Install the the [LSP 
package](https://packagecontrol.io/packages/LSP) from Package Control.

You can configure the LSP plugin to use fennel-ls directly by editing your
`Packages/User/LSP.sublime-settings` file, which can be opened via "Preferences
\> Package Settings \> LSP \> Settings" from the menu or with the Preferences: LSP
Settings command from the Command Palette.

You should add an entry to the top-level `"clients"` object (creating it if it
doesn't exist), with this configuration:
```json
"clients": {
    "fennel-ls": {
        "enabled": true,
        "selector": "source.fennel",
        "command": ["fennel-ls"]
    }
}
```

If you run into problems, check the [LSP Client Configuration
reference](https://lsp.sublimetext.io/client_configuration/) and double-check
the location of fennel-ls on the $PATH is visible to Sublime Text.

### Visual Studio Code

You need to [install an extension](https://codeberg.org/adjuvant/vscode-fennel-ls)
in order to use it.

### Other editors

It should be possible to set up for other text editors, but the instructions
depend on which editor you use. Generally you need to tell your editor:
* "fennel-ls" is a language server program on the $PATH
* it should be run for fennel files.
