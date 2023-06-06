# fennel-ls
A language server for fennel-ls.
Supports Go-to-definition, and a little bit of completion suggestions.
Fennel-LS uses static analysis, and does not execute your code.

For now, you can ask fennel-ls to **treat your file as a macro file** if the very first characters in the file exactly match `;; fennel-ls: macro-file`. Expect this to change at some point in the future when I come up with a better way to specify which files are meant to be macro files.

## Building / Installing
The build dependencies are `make` and `lua`. Lua 5.1 or higher is needed. Every other dependency is already included in the repository. See the License section at the bottom of the readme if you care about what other dependencies are being used.

Pick your favorite command to build and install the language server.

```sh
make && sudo make install # to install into /usr/local/bin
make && make install PREFIX=$HOME # if you have ~/bin on your $PATH
```

For now, the only way to install is to build from source, but I plan on adding fennel-ls to luarocks soon.

## Set Up Your Editor

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
Generally this involves somehow configuring this information:
* "fennel-ls" is a language server program on the path
* it should be run for .fnl files.

If you get it working in any other environments, I'd love to know! It would be great to have instructions on how to set up other editors!

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
      "unknown-module-field": true
    }
  }
}
```

## License
fennel-ls is licensed under the MIT license. See LICENSE for more info.
This project also contains files from other projects:
* test/pl/* comes from [Penlight](https://github.com/lunarmodules/Penlight) [MIT license]
* src/json/* comes from [json.lua](https://github.com/rxi/json.lua) [MIT license]
* src/fennel-ls/docs/* contains information from the [lua](https://lua.org) reference [MIT license]
* test/lust.lua is modified, but originially comes from from [lust](https://github.com/bjornbytes/lust) [MIT license]
* fennel and src/fennel.lua are compiled from [fennel](https://git.sr.ht/~technomancy/fennel) [MIT license]
