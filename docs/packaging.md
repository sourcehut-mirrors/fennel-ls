# Packaging
Sorry packagers, I have committed two ultimate sins.
1. I checked in some generated code into my repository.
2. I have copied others' code into my repository, also known as "vendoring" code.

## Generated Code
The files inside `src/fennel-ls/docs/generated/` are not hand-written, they are
generated. The documentation embedded into `fennel-ls` needs to come from
various documentation websites on the internet, such as
[the Lua Manual](https://www.lua.org/manual/5.1/manual.html), and I use
scripts to download and parse these sites into these generated files.

The content of these websites is available under the MIT license, so there isn't
any licensing issue.

I understand if you want to build from source instead of relying on the output.
You can rebuild these by running `make rm-docs` to remove the docs, and
`make docs` to regenerate these files.
```sh
$ make rm-docs
$ make docs
```

## Including LÖVE documentation
Due to license incompatibility between fennel-ls and the official LÖVE
documentation, this repository cannot include the LÖVE documentation by
default. It must be generated manually.

This can be done by passing a flag to the `docs` target.

```sh
$ make docs GET_DOCS_FLAGS=--generate-love2d
```

## Vendored Dependencies
The vendored dependencies are very easy to solve. You delete the dependency
files by running `make rm-deps`.
```sh
$ make rm-deps
rm -rf fennel deps/
$
```
Once these files are removed, you can safely use `make` to build the program.
```sh
# Not shown here: install fennel and lua and make and lua-dkjson

# building
make

# testing (only works if faith and penlight and dkjson is installed)
make test
```

# Dependencies Overview
Things marked with (vendored) are from the `deps/` folder, or from your
environment if you've built a clean one.

* Runtime Dependencies:
  * Lua
  * Fennel (vendored)
  * dkjson (vendored)
* Build Dependencies:
  * Make
  * Lua
  * Fennel (vendored)
* Test Dependencies:
  * Faith (vendored)
  * Penlight (vendored)

The specific versions of vendored packagens can be found in the
[vendoring script](../tools/get-deps.fnl).
