# Manual

This document has information on how to configure and use fennel-ls after you [installed it](installation.md).

## Configuration

fennel-ls can be configured by creating a file named `flsproject.fnl` in the
root of your project.

The default settings are below, you only need to provide the settings you want
to change. An empty table `{}` is a valid configuration and serves as a marker
to indicate where the project root is located.

```fnl
{:fennel-path "./?.fnl;./?/init.fnl;src/?.fnl;src/?/init.fnl"
 :macro-path "./?.fnl;./?/init-macros.fnl;./?/init.fnl;src/?.fnl;src/?/init-macros.fnl;src/?/init.fnl"
 :lua-version "lua5.4"
 :libraries {}
 :extra-globals ""
 :lints {:unused-definition true
         :unknown-module-field true
         :unnecessary-method true
         :unnecessary-tset true
         :unnecessary-do true
         :redundant-do true
         :match-should-case true
         :bad-unpack true
         :var-never-set true
         :op-with-no-arguments true
         :multival-in-middle-of-call true
         :no-decreasing-comparison false}
```

- `extra-globals`: Space separated list of allowed global identifiers that will
  be added to a set of predefined lua globals.

  These identifiers and any of their fields will be considered valid and won't
  produce diagnostics. Use this when importing a library for which
  documentation is not available.

- `version`: One of `lua5.1`, `lua5.2`, `lua5.3`, `lua5.4`, `intersection`, or
  `union`.

  `intersection` represents the APIs that are available in *every* supported
  Lua version, `union` represents APIs available in *any* version.

- `libraries`: This setting controls which extra documentation fennel-ls will
  load in your environment. Each entry in the table is the name of the library
  and a boolean, `true` to enable the library and `false` to disable it.

  The name of the library is the name of a file that will be loaded from
  `~/.local/share/fennel-ls/docsets/` after appending the `.lua` extension.

  For example, if the table contains `{:love2d true}` the file `love2s.lua`
  will be loaded from `~/.local/share/fennel-ls/docsets/`.

  The available docsets are listed on the [Fennel
  wiki](http://wiki.fennel-lang.org/LanguageServer).

  See the full [docsets documentation](docsets.md) for more information on how
  to find, install, or create docsets.

  > fennel-ls respects the XDG convention, so if you changed `$XDG_DATA_HOME`
  > the files will be loaded from the location you specified.

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

Unused locals will be flagged unless they begin or end with an underscore. If
you have a local that is unused in your code but necessary for pattern matching
purposes, it's recommended to put an underscore at the end. For example:

```fennel
(case [1 1 2 3 5 8]
  [a_ a_] (print "First two elements are equal"))
```

## CLI Usage

fennel-ls can be used as a linter from the command line:

```sh
fennel-ls --lint my-file.fnl f2.fnl # prints diagnostics for the files given
```

This will analyze the given files and print out all compiler errors and lints,
without launching a server. A successful exit code indicates no problems found.
