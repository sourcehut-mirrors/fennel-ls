LUA ?= lua
FENNEL=$(LUA) fennel
EXE=fennel-ls

SRC=$(wildcard src/*.fnl)
SRC+=$(wildcard src/fennel-ls/*.fnl)
SRC+=$(wildcard src/fennel-ls/docs/*.fnl)

BUILD_DIR=./build

DESTDIR ?=
PREFIX ?= /usr/local
BINDIR ?= $(PREFIX)/bin

FENNELFLAGS=--add-package-path "src/?.lua;deps/?.lua" --add-fennel-path "src/?.fnl;deps/?.fnl"
FENNELFLAGS+=--skip-include fennel.compiler
EXTRA_FENNELFLAGS ?=
FENNELFLAGS+= $(EXTRA_FENNELFLAGS)

.PHONY: all clean test repl install docs install-deps ci selfcheck

all: $(EXE)

$(EXE): $(SRC)
	echo "#!/usr/bin/env $(LUA)" > $@
	$(FENNEL) $(FENNELFLAGS) --require-as-include --compile src/fennel-ls.fnl >> $@
	chmod 755 $@

repl:
	$(FENNEL) $(FENNELFLAGS)

docs:
	$(FENNEL) $(FENNELFLAGS) tools/get-docs.fnl

rm-docs:
	rm -rf src/fennel-ls/docs/

deps:
	$(FENNEL) $(FENNELFLAGS) tools/get-deps.fnl

rm-deps:
	rm -rf fennel deps/

selfcheck:
	$(FENNEL) $(FENNELFLAGS) src/fennel-ls.fnl --check $(SRC)

install: $(EXE)
	mkdir -p $(DESTDIR)$(BINDIR) && cp $< $(DESTDIR)$(BINDIR)/

test:
	TESTING=1 $(FENNEL) $(FENNELFLAGS) test/init.fnl

ci:
	$(MAKE) test LUA=lua5.1
	$(MAKE) test LUA=lua5.2
	$(MAKE) test LUA=lua5.3
	$(MAKE) test LUA=lua5.4
	$(MAKE) test LUA=luajit

clean:
	rm -f $(EXE)
