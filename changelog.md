# Changelog

### Bug Fixes
* Diagnostics are now up to date, instead of being one change behind
* There was an issue with spaces in file paths
* There was an issue with file paths on Windows
* Signature help doesn't show up when calling non-functions

## 0.2.2 / 2025-10-25

### Features
* Add `documentSymbol` support, for jumping to symbols definitions in the current document
* Add `--fix` command-line argument to automatically apply lint fixes
* Add `:legacy-multival` and `legacy-multival-case` lints, disabled by default
* Code action "Expand macro" lets you see what a macro expands to
* Macro expansion is shown when hovering over a macro
* Added support for pull diagnostics, which should help with out of date lints
* Completions can complete missing variable names in binding contexts
    * For example, a completion of `hello-there` if the file contains `(local | 100) (print hello-there)` where `|` represents the cursor.
* New lint `empty-let` for replacing `(let [] ...)` with `(do ...)`
* New lint `duplicate-table-keys` for detecting duplicate keys (eg. `{:a 1 :a 2}`)
* New lint `too-many-arguments` for function calls that provide extra, useless arguments
* New lint `not-enough-arguments` for ensuring you don't accidentally implicitly pass nil
    * Disabled by default because it requires following fennel's optional argument naming conventions
* New lint `invalid-flsproject-settings` checks your `flsproject.fnl` file as you edit it
* Renamed lint `unnecessary-do-values` to `unnecessary-unary` and made it apply to many more forms
* New lint `nested-associative-operator` checks for nested operations that could be flattened (eg. `(+ 1 2 (+ 3 4) 5)`)
* New lint `zero-indexed` checks for `(. tbl 0)` operations.
    * Disabled by default because 0 *can* be a valid table key in some cases.

### Changes
* Updated to fennel 1.6.0
* Updated to dkjson 2.8

### Bug Fixes
* Completions no longer trigger unexpectedly in comments or strings
* When using --lint, diagnostics that don't have source info use ? as a line number instead of line 1
* lots of code simplification

## 0.2.1 / 2025-06-06

### Bug Fixes
* Fixed a path issue finding external docsets
* Fixed failing tests in 0.2.0

## 0.2.0 / 2025-06-03

### Features

* Signature help support.
* Provide human readable code actions titles.
* Add --help and --version command line flags.
* Support providing improved completion kinds to clients.
* Support highlighting references to the symbol under the cursor in the current file.
* Support loading external docsets from disk.
* Extract TIC-80 docs to external docset.
* Support `:lua-version` settings like `"lua5.4"` rather than requiring `"lua54"`.
* Support `"union"` in `:lua-version` for globals present in any Lua version.
* Support `"intersection"` in `:lua-version` for globals present in every Lua version.
* Show the kind of thing being completed better.
* Add lints for unnecessary `tset` and `do`.
* Add lint for replacing `match` with `case` when possible.
* Ignore unused locals if they end in underscore.
* Settings file: `flsproject.fnl`. Settings are now editor agnostic.
* Support better completions. The eglot client is no longer a special case.

### Changes

* Packaging scripts for nix and luarocks have been removed so they can be kept in downstream repositories.

### Bug Fixes
* (set (. x y) z) wasn't being analyzed properly.
* (local {: unknown-field} (require :module)) lint warns about the unknown field when accessed via destructuring.

## 0.1.3 / 2024-06-27

### Features
* Updated to fennel 1.5.0
* Better results when syntax errors are present
* Docs for each Lua version: 5.1 through 5.4
* Docs for TIC-80

### Changes
* --check is now --lint

### Bug Fixes
* Solved a case where there were duplicate completion candidates
* Special workaround for Eglot to be able to complete multisyms
    To be honest, this isn't even Eglot's fault; the LSP specification leaves it ambiguous
    [Eglot's issue](https://github.com/joaotavora/eglot/issues/402)
    [LSP's issue](https://github.com/microsoft/language-server-protocol/issues/648)
    [fennel-mode can't fix it on their end](https://git.sr.ht/~technomancy/fennel-mode/commit/188ee04e86792cd4bce75d52b9603cc833b63b48)

### Misc
* Switch json libraries from rxi/json.lua to dkjson
* Lots of refactoring and renaming things
* You can now build fennel-ls with no vendored dependencies if you want
* Building is more reproducible now! `tools/get-deps.fnl` will reproducibly get all the deps, instead of you needing to trust me
* faith updated to 0.2.0

## 0.1.2 / 2024-03-03

### Features
* Completions and docs for `coroutine`, `debug`, `io`, `math`, `os`, `string`, `table`, `utf8` and their fields.
* Global metadata can follow locals: With `(local p print)`, looking up `p` will show `print`'s information.
* New lint for erroneous calls to (values) that are in a position that would get truncated immediately.
* Upgrade to Fennel 1.4.2

### Bug Fixes
* `(-?> x)` and similar macros no longer give a warning (even in fennel 1.4.1 before my -?> patch landed)
* Fixed off-by-one when measuring the cursor position on a multisym. For example, `table|.insert` (where `|` is the cursor) will correctly give information about `table` instead of `insert`.
* Can give completions in the contexts "(let [x " and "(if ", which previously failed to compile.
* Fields added to a table via `(fn t.field [] ...)` now properly appear in completions
* `(include)` is now treated like `(require)`

### Misc
* Switched testing framework to faith
* Tests abstract out the filesystem
* Tests use the "|" character to mark the cursor, instead of manually specifying coordinates

## 0.1.1 / 2024-02-19

### Features
* Add [Nix(OS)](https://nixos.org) support
* Add LuaRocks build support
* Upgrade to Fennel 1.4.1, the first release of fennel that is compatible with fennel-ls without patches.
* Added a lint for operators with no arguments, such as (+)
* `textEdit` field is present in completions

### Bug Fixes
* Fix bug with renaming variables in method calls
* Lots of work to improve multival tracking
* --check gives a nonzero exit code when lints are found

## 0.1.0 / 2023-12-06

### Initial Features
* Completion: works across files, and works with table fields
* Hover: works across files, and works with table fields
* Go-To Definition: works across files, and works with table fields
* Go-To References: only same-file; lexical variables only
* Rename: only same-file; lexical variables only
* Diagnostics:
    * Compiler Errors
    * Unused Definitions
    * Unused Mutability with `var`
    * Unknown Module Field
    * Unnecessary `:` form
    * Unpack into operator

* Supports functions/values you define, and fennel builtins / macros
* Limited support for *some* of lua's builtins

### Info
* Uses bundled fennel 1.4.0-dev
* executes macro code in the macro sandbox
    * infinite loop macros will freeze fennel-ls
    * fennel-ls will have trouble working with macros that require disabled sandbox
* There was a security issue in previous versions of fennel-ls regarding macro sandboxing
