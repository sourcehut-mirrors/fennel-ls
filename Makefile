LUA ?= lua
# If ./fennel is present, use `lua fennel` to run the locally vendored fennel
# otherwise
FENNEL=$(if $(wildcard fennel),$(LUA) fennel,fennel)
EXE=fennel-ls

SRC:=$(shell find src -name "*.fnl")

DESTDIR ?=
PREFIX ?= /usr/local
BINDIR ?= $(PREFIX)/bin
MANDIR ?= $(PREFIX)/share/man/man1

FENNELFLAGS=--add-package-path "deps/?.lua" --add-fennel-path "src/?.fnl;deps/?.fnl"
REQUIRE_AS_INCLUDE_SETTINGS=$(shell $(FENNEL) tools/require-flags.fnl)

.PHONY: all clean test repl install docs docs-love2d install-deps ci selflint \
	deps rm-docs rm-deps count testall check-deps

all: $(EXE)

$(EXE): $(SRC)
	echo "#!/usr/bin/env $(LUA)" > $@
	$(FENNEL) $(FENNELFLAGS) $(REQUIRE_AS_INCLUDE_SETTINGS) --require-as-include \
		--compile src/fennel-ls.fnl >> $@
	chmod 755 $@

install: $(EXE) build/fennel-ls.1
	mkdir -p $(DESTDIR)$(BINDIR) && cp $< $(DESTDIR)$(BINDIR)/
	mkdir -p $(DESTDIR)$(MANDIR) && cp build/fennel-ls.1 $(DESTDIR)$(MANDIR)

## Generating docs

docs: src/fennel-ls/docs/generated/lua51.fnl \
	src/fennel-ls/docs/generated/lua52.fnl \
	src/fennel-ls/docs/generated/lua53.fnl \
	src/fennel-ls/docs/generated/lua54.fnl

src/fennel-ls/docs/generated/%.fnl:
	mkdir -p build/
	mkdir -p src/fennel-ls/docs/generated/
	$(FENNEL) $(FENNELFLAGS) tools/generate-lua-docs.fnl ${*} > $@

docs-love2d:
	@echo "This has moved to a separate source. Please see the wiki:"
	@echo "https://wiki.fennel-lang.org/LanguageServer"
	@exit 1

rm-docs:
	rm -rf src/fennel-ls/docs/

build/fennel-ls.1:
	echo ".TH FENNEL-LS 1" > $@
	pandoc --title-prefix=fennel-ls -t man docs/manual.md >> $@
	echo ".SH LICENSE\nCopyright © 2023-2025, Released under the MIT/X11 license" >> $@

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

ci: selflint testall

clean:
	rm -fr $(EXE) old-deps old-fennel build/
