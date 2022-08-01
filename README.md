# fennel-ls
TO PROSPECTIVE USERS:
THIS PROJECT IS NOT IN A USABLE STATE YET. CHECK BACK LATER.

A language server for fennel-ls.

(Planned) Features:
* [X] Able to connect to a client
* [ ] Support for UTF-8 characters that aren't just plain ASCII. (especially `λ`)
* [ ] Settings to configure lua / fennel path, allowed globals, etc
* [ ] Builds for anything other than arch linux
* [X] Go-to-definition for (require) statements
* [ ] Go-to-definition for in-file definitions
* [ ] Go-to-definition for definitions in other files
* [ ] Go-to-definition into lua code
* [ ] Report compiler errors
* [ ] Report linting issues
* [ ] basic completion suggestions
* [ ] Hover over a symbol for documentation
* [ ] Signature help
* [ ] Go-to-references on definitions of things
* [ ] integration with fnlfmt
* [ ] Maybe some sort of type checking???
    * [ ] completion suggestions for fields / methods


## Setup:
You can match my environment to develop with the following steps.

1. Install luafilesystem
```sh
# On Arch linux, this can be done with pacman:
sudo pacman -S lua-filesystem
```

2. Build the binary
```sh
make
```

3. Configure your editor to use this language server

So far, I've only ever tested it with Neovim using the native language client and lspconfig.
If you know what that means, here's the relevant code to help you set up Neovim in the same way:
```lua
local lspconfig = require('lspconfig')
-- inform lspconfig about fennel-ls
require("lspconfig.configs")["fennel-ls"] = {
    default_config = {
        cmd = {"/path/to/fennel-ls/fennel-ls"},
        filetypes = {"fennel"},
        root_dir = function(dir) return lspconfig.util.find_git_ancestor(dir) end,
        settings = {}
    }
}
-- setup fennel-ls
-- If you're using a completion system like nvim-cmp, you probably need to modify this line.
lspconfig["fennel-ls"].setup(
    vim.lsp.protocol.make_client_capabilities()
)
```

## Caveats
Until I change this readme, you can assume that this project is incomplete and not meant to be used.

So far, I am only testing this project with Neovim. Since Neovim also uses Lua, there may be instances where fennel-ls encodes JSON incorrectly which may be compatible with Neovim, but not other editors. (ie, a json field that is supposed to be null may be missing, or [] and {} may be conflated). User beware!

If you want to help fix this, `./src/fennel-ls/message.fnl` is where messages are being constructed,
and `./src/fennel-ls/json-rpc.fnl` is where messages are being converted to json. I suspect a different json library will be necessary.

## License
fennel-ls is licensed under the MIT license. See LICENSE for more info.
However, this project contains files from other projects:
* src/pl comes from [Penlight](https://github.com/lunarmodules/Penlight)
* src/json comes from [json.lua](https://github.com/rxi/json.lua)
* fennel and src/fennel.lua are built from [fennel](https://git.sr.ht/~technomancy/fennel)

fennel-ls's MIT license may not apply to these files; check those projects for their respective code licenses.
