# Changelog

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
