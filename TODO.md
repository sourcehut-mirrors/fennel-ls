# Wishlist of features
([X] = complete,  [ ] = planned)

My current goal is to work on completions a little bit more.
- [X] create a release

refactor brainstorm:
- [ ] get rid of `bytes` stuff and use "stack" everywhere
- [ ] search caching
- [ ] search depth limit / stop recursion
- [ ] search into calls

- [ ] entry point measurement for reference search

- [ ] arg return count
  - [ ] i guess searching into calls could do this?

- [ ] diagnostic code actions

- [ ] Hovering over a table should show the actual values, not just the AST
  - [ ] {: foo} shorthand in fennel.view
  - [ ] Add a summary to first line of table hovers.

- [ ] make hovers look like (fn table.insert [t ?i v] ...)

Here is my feature wishlist. I don't expect to ever get all of this done, but these are the sort of enhancements I am thinking about.
- [X] Able to connect to a client
- [X] Support for UTF-8 characters that aren't just plain ASCII. (especially `λ`) (perhaps just tell the IDE that I want to communicate with utf-8 offsets)
- [ ] People have tried fennel-ls in:
    - [X] Neovim (This project isn't a neovim plugin, but there are instructions on how to inform neovim of the fennel-ls binary once you build it.)
    - [X] emacs
    - [X] helix
    - [ ] vscode (publish an extension)
    - [ ] vim+coc (publish a node thingy)
- [x] Go-to-definition:
    - [X] literal table constructor
    - [X] table destructuring
    - [X] multisyms
    - [X] `.` special form (when called with constants)
    - [X] `do` and `let` special form
    - [X] `require` and cross-module definition lookups
    - [ ] goes to a.method on `(: a :method)` when triggered at `:method`
    - [X] expanded macros (a little bit)
    - [X] table mutation via `fn` special: `(fn obj.new-field [])`
    - [ ] macro calls / which macros are in scope
    - [ ] setmetatable
    - [ ] can search through function arguments / function calls / method calls
    - [ ] local/table mutation via set/tset
    - [ ] .lua files (antifennel decompiler)
    - [ ] mutation on aliased tables (difficult)
- [ ] Completion Suggestions
    - [X] from globals
    - [X] from current scope
    - [X] from macros (only on first form in a list)
    - [X] from specials (only on first form in a list)
    - [X] "dot completion" for table fields
    - [1/2] dot completion is aware of a stdlib
    - [ ] actually compliant rules about lexical scope (only see things declared before, not after)
    - [x] show docs/icons on each suggestion
    - [ ] "dot completion" for metatable `__index` fields
    - [ ] `(. obj :` string completions
    - [ ] `(: "foo" :` string completions
    - [ ] `(require :` module completions
    - [ ] from anywhere else that I'm forgetting right now
    - [ ] snippets? maybe more?
- [X] Reports compiler errors
    - [X] Report more than one error per top-level form
- [ ] Reports linting issues
    - [X] Unused locals
    - [X] Unknown fields of modules
    - [ ] Discarding results from pcall/xpcall/other functions
    - [.] `unpack` or `values` into a special
    - [ ] `do`/`values` with only one inner form
    - [ ] redundant `do` as the last/only item in a form that accepts a "body"
    - [ ] `values`/`unpack` in a non tail position
    - [ ] numbers and strings in a non tail position
    - [ ] deprecated specials/macros
    - [X] `var` forms that could be `local`
    - [ ] Arity checking
      - [ ] Too many args (assuming there is no ... argument)
      - [ ] Too few args (assuming the last argument is statically countable, and also account for ?optional arguments)
      - [ ] I need to also make it work for built-in functions
      - [ ] warn if an optional arg is present, but no call ever passes the arg
    - [ ] Code that matches the shape of `accumulate` or `icollect` or `collect`?? or other macros??
    - [ ] Dead code (I'm not sure what sort of things cause dead code)
    - [ ] Unused fields (difficult)
    - [ ] unification in a `match` pattern (difficult)
    - [ ] unused values in `λ` (difficult)
    - [ ] Brainstorm more linting patterns (I spent a couple minutes brainstorming these ideas, other ideas are welcome of course)
    - [ ] Type Checking
- [X] Hover over a symbol for documentation



- [ ] Signature help
    - [ ] respond to signature help queries
    - [ ] hide or grey out the `self` in an `a:b` multisym call
- [ ] Go-to-references
    - [x] lexical scope in the same file
    - [ ] function names work properly and are counted once
    - [ ] fields
    - [ ] go to references of fields when tables are aliased
    - [ ] global search across other files
- [ ] Options / Configuration
    - [X] Configure over LSP
    - [ ] Configure with some sort of per-project config file
    - [ ] Configure with environment variables I guess??
    - [X] fennel/lua path
    - [ ] lua version
    - [ ] allowed global list
    - [X] enable/disable various linters
- [X] rename
    - [X] local symbols
    - [ ] module fields (may affect code behavior, may modify other files)
    - [ ] arbitrary fields (may affect code behavior, may modify other files)
- [ ] formatting with fnlfmt
- [ ] Type annotations? Global type inference?


fn-arg-nil: Function arguments are assumed to be nil in a function body, until there's a type system to give more information.

hashfn: Hash functions currently don't work well.

refs-dedup: 

