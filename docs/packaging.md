# Packaging
Sorry packagers, I have committed two ultimate sins.
1. I checked in some generated code into my repository.
2. I have copied others' code into my repository, also known as "vendoring" code.

Debian packaging is at https://git.sr.ht/~technomancy/fennel-ls/log/debian/latest

## Generated Code
The files inside `src/fennel-ls/docs/generated/` are not hand-written, they are
generated. The documentation embedded into `fennel-ls` needs to come from
various documentation websites on the internet, such as
[the Lua Manual](https://www.lua.org/manual/5.1/manual.html), and I use
scripts to download and parse these sites into these generated files.

The content of these websites is available under the MIT license, so there isn't
any licensing issue.

I understand if you want to build from source instead of relying on the output.
You can rebuild these by removing the generated docs and regenerating them.
However, this requires internet access.
```sh
$ rm -rf src/fennel-ls/docs/generated/
$ make docs
```

## Vendored Dependencies
The vendored dependencies are very easy to solve:

When the `VENDOR` flag is set to `false`, the build process will use
system-installed versions of fennel to build, and the built program will
search for its dependencies dynamically using lua's path system,
instead of statically including the vendored dependencies.

```sh
# Install system dependencies first
# You need: fennel, lua, lua-dkjson, make

# Optional: remove the vendored code from the repo
rm fennel deps/ -r

# Build with system dependencies
make VENDOR=false

# Testing with system dependencies (also requires faith and penlight)
make test VENDOR=false
```

# Dependencies Overview
Things marked with (vendored) are vendored unless `VENDOR=false` is set.

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

The specific versions of vendored dependencies can be found in the
[vendoring script](../tools/get-deps.fnl).

## Verifying Reproducibility

The Makefile provides targets to verify that the vendored dependencies and
generated docs match what the build scripts produce:

```sh
# Check that deps are reproducible
make check-deps

# Check that generated docs are reproducible
make check-docs
```
