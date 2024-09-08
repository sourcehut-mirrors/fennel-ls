LUA ?= lua
# If ./fennel is present, use `lua fennel` to run the locally vendored fennel
# otherwise
FENNEL=$(if $(wildcard fennel),$(LUA) fennel,fennel)
EXE=fennel-ls

SRC:=$(shell find src -name "*.fnl")

BUILD_DIR=./build

DESTDIR ?=
PREFIX ?= /usr/local
BINDIR ?= $(PREFIX)/bin

FENNELFLAGS=--add-package-path "src/?.lua;deps/?.lua" --add-fennel-path "src/?.fnl;deps/?.fnl"
REQUIRE_AS_INCLUDE_SETTINGS=$(shell $(FENNEL) tools/require-flags.fnl)

ROCKSPEC_LATEST_SCM=rockspecs/fennel-ls-scm-$(shell ls rockspecs | grep -Eo 'scm-[0-9]+' | grep -Eo [0-9]+ | sort -n | tail -1).rockspec

.PHONY: all clean test repl install docs install-deps ci selflint count

all: $(EXE)

$(EXE): $(SRC)
	echo "#!/usr/bin/env $(LUA)" > $@
	$(FENNEL) $(FENNELFLAGS) $(REQUIRE_AS_INCLUDE_SETTINGS) --require-as-include --compile src/fennel-ls.fnl >> $@
	chmod 755 $@

repl:
	$(FENNEL) $(FENNELFLAGS)

docs:
	$(FENNEL) $(FENNELFLAGS) tools/get-docs.fnl $(GET_DOCS_FLAGS)

rm-docs:
	rm -rf src/fennel-ls/docs/

deps:
	$(FENNEL) $(FENNELFLAGS) tools/get-deps.fnl

rm-deps:
	rm -rf fennel deps/

selflint:
	$(FENNEL) $(FENNELFLAGS) src/fennel-ls.fnl --lint $(SRC)

count:
	cloc $(shell find src -name "*.fnl" | grep -v "generated")

install: $(EXE)
	mkdir -p $(DESTDIR)$(BINDIR) && cp $< $(DESTDIR)$(BINDIR)/

test: $(EXE)
	TESTING=1 $(FENNEL) $(FENNELFLAGS) test/init.fnl

ci:
	$(MAKE) test LUA=lua5.1
	$(MAKE) test LUA=lua5.2
	$(MAKE) test LUA=lua5.3
	$(MAKE) test LUA=lua5.4
	$(MAKE) test LUA=luajit

	# Make sure the dependency files are correct
	mv deps old-deps
	mv fennel old-fennel
	$(MAKE) FENNEL=./old-fennel deps
	diff -r deps old-deps
	diff -r fennel old-fennel
	rm -rf old-deps
	rm -f old-fennel

	# test that luarocks builds and runs
	DEBIAN_FRONTEND=noninteractive sudo apt install -y luarocks
	luarocks install $(ROCKSPEC_LATEST_SCM) --dev --local 
	eval "$$(luarocks path)"; \
	fennel-ls --lint

clean:
	rm -f $(EXE)
