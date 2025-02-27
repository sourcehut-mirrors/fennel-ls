LUA ?= lua
# If ./fennel is present, use `lua fennel` to run the locally vendored fennel
# otherwise
FENNEL=$(if $(wildcard fennel),$(LUA) fennel,fennel)
EXE=fennel-ls

SRC:=$(shell find src -name "*.fnl")

DESTDIR ?=
PREFIX ?= /usr/local
BINDIR ?= $(PREFIX)/bin

FENNELFLAGS=--add-package-path "deps/?.lua" --add-fennel-path "src/?.fnl;deps/?.fnl"
REQUIRE_AS_INCLUDE_SETTINGS=$(shell $(FENNEL) tools/require-flags.fnl)

ROCKSPEC_LATEST_SCM=rockspecs/fennel-ls-scm-$(shell ls rockspecs | \
	grep -Eo 'scm-[0-9]+' | grep -Eo [0-9]+ | sort -n | tail -1).rockspec

.PHONY: all clean test repl install docs docs-love2d install-deps ci selflint \
	deps rm-docs rm-deps count testall check-deps check-luarocks

all: $(EXE)

$(EXE): $(SRC)
	echo "#!/usr/bin/env $(LUA)" > $@
	$(FENNEL) $(FENNELFLAGS) $(REQUIRE_AS_INCLUDE_SETTINGS) --require-as-include \
		--compile src/fennel-ls.fnl >> $@
	chmod 755 $@

install: $(EXE)
	mkdir -p $(DESTDIR)$(BINDIR) && cp $< $(DESTDIR)$(BINDIR)/

## Generating docs

docs:
	$(FENNEL) $(FENNELFLAGS) tools/get-docs.fnl $(GET_DOCS_FLAGS)

XDG_DATA_HOME ?= $(HOME)/.local/share
DOCSET_DIR = $(XDG_DATA_HOME)/fennel-ls/docsets/

$(DOCSET_DIR)/love2d.lua: src/fennel-ls/docs/generated/love2d.fnl
	mkdir -p $(DOCSET_DIR)
	$(FENNEL) $(FENNELFLAGS) --compile $< > $@

src/fennel-ls/docs/generated/love2d.fnl:
	$(FENNEL) $(FENNELFLAGS) tools/get-docs.fnl --generate-love2d

# has to be separate for licensing reasons
docs-love2d: $(DOCSET_DIR)/love2d.lua

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

repl:
	DEV=y $(FENNEL) $(FENNELFLAGS)

# to run one module: make test FAITH_TEST=test.lint
# to run one test: make test FAITH_TEST="test.lint test-unset-var"
test: $(EXE)
	DEV=y XDG_DATA_HOME=test/data $(FENNEL) $(FENNELFLAGS) test/init.fnl

testall:
	$(MAKE) test LUA=lua5.1
	$(MAKE) test LUA=lua5.2
	$(MAKE) test LUA=lua5.3
	$(MAKE) test LUA=lua5.4
	$(MAKE) test LUA=luajit

check-deps:
	rm -rf old-deps old-fennel
	mv deps old-deps
	mv fennel old-fennel
	$(MAKE) FENNEL=./old-fennel deps
	diff -r deps old-deps
	diff -r fennel old-fennel
	rm -rf old-deps old-fennel

check-luarocks:
	luarocks install $(ROCKSPEC_LATEST_SCM) --dev --local
	eval "$$(luarocks path)"; \
	fennel-ls --lint

ci: testall check-deps check-luarocks

clean:
	rm -fr $(EXE) old-deps old-fennel build/
