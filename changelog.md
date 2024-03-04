# Changelog

## 0.1.2

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

## 0.1.1

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

## 0.1.0

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
