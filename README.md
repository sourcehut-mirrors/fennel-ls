# fennel-ls
A language server for fennel-ls.
Uses static analysis, and doesn't actually run your code, which makes it perfect for analyzing your (os.execute "rm -rf") code.
If you want live analysis of your code as it runs, consider using a REPL.

Features / To Do List / Things I would enjoy patches for:
([X] = complete,  [ ] = incomplete)

- [X] Able to connect to a client
- [ ] Support for UTF-8 characters that aren't just plain ASCII. (especially `λ`)
- [ ] Settings to configure lua / fennel path, allowed globals, etc
- [ ] Supporting builds for anything other than arch linux
- [ ] Testing/support/instructions for any clients: (LSP is supposed to be editor-agnostic, but that's only if you're able to actually follow the spec, and I'm not sure that fennel-ls is compliant)
    - [X] Neovim (This project isn't a neovim plugin, but there are instructions on how to inform neovim of the fennel-ls binary once you build it.)
    - [ ] emacs
    - [ ] vscode
    - [ ] vim+coc
- [ ] Go-to-definition understands:
    - [X] literal table constructor
    - [X] table destructuring
    - [X] multisyms
    - [X] `.` special form (when called with constants)
    - [ ] `do` special form
    - [X] `require` and cross-module definition lookups
    - [X] macro bodies (a little bit)
    - [ ] mutation via set/tset
    - [ ] mutation from `fn`: `(fn obj.new-field [])`
    - [ ] actual macro calls
    - [ ] .lua files
    - [ ] setmetatable
    - [ ] function arguments / function calls
    - [ ] mutation on aliased tables (difficult)
- [X] Reports compiler errors
- [ ] Reports linting issues
    - [ ] Think of more linting patterns (I spent a couple minutes brainstorming these ideas, other ideas are welcome of course)
    - [ ] Dead code. I'm not sure what sort of things would cause dead code in fennel
    - [ ] Unused variables / fields (maybe difficult)
    - [ ] Discarded results for some calls
    - [ ] `do`/`values` with only one inner form
    - [ ] Warning when unification is happening on a `match` pattern (may be difficult)

- [ ] Completion Suggestions
    - [ ] from standard library
    - [ ] "dot completion" for multisyms
    - [ ] from current scope
    - [ ] `(: "foo" :` complete the string
    - [ ] snippets? I guess?
- [X] Hover over a symbol for documentation
- [ ] Signature help
    - [ ] Regular help
    - [ ] hide or grey out the `self` in a `a:b` multisym call
- [ ] Go-to-references
    - [ ] lexical scope in the same file
    - [ ] fields, including when tables are aliased
    - [ ] global search across other files
- [ ] Options
    - [ ] Configure over LSP
    - [ ] Configure with some sort of per-project config file
    - [ ] Configure with environment variables I guess??
    - [ ] fennel/lua path
    - [ ] lua version
    - [ ] allowed global list
    - [ ] enable/disable various linters
- [ ] rename local symbols
- [ ] rename module fields (may affect code behavior, may modify other files)
- [ ] rename arbitrary things (may affect code behavior, may modify other files)
- [ ] formatting with fnlfmt
- [ ] Type annotations? Global type inference?

{field: {}}


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
LSP is editor-agnostic, but that's only if you're able to actually follow the spec, and I'm not sure that fennel-ls is compliant.

So far, I've only ever tested it with Neovim using the native language client and `lspconfig`.
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

It should be possible to set up for other clients, but I haven't looked into these steps. If you get it working in any other environments, I'd love to know! It would be great to have instructions on how to set up other editors!

## Caveats
So far, I am only testing this project with Neovim. Since Neovim also uses Lua, there may be instances where fennel-ls encodes JSON incorrectly which may be compatible with Neovim, but not other editors. (ie, a json field that is supposed to be null may be missing, or [] and {} may be conflated). User beware!

If you want to help fix this, `./src/fennel-ls/message.fnl` is where messages are being constructed,
and `./src/fennel-ls/json-rpc.fnl` is where messages are being converted to json. I suspect a different json library will be necessary.

## License
fennel-ls is licensed under the MIT license. See LICENSE for more info.
However, this project contains files from other projects:
* test/pl comes from [Penlight](https://github.com/lunarmodules/Penlight) [MIT license]
* src/json comes from [json.lua](https://github.com/rxi/json.lua) [MIT license]
* fennel and src/fennel.lua are compiled from [fennel](https://git.sr.ht/~technomancy/fennel) [MIT license]

fennel-ls's license may not apply to these files; check those projects for more details.
