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

.PHONY: all clean test install ci selfcheck

all: $(EXE)

$(EXE): $(SRC)
	echo "#!/usr/bin/env $(LUA)" > $@
	$(FENNEL) $(FENNELFLAGS) --require-as-include --compile src/fennel-ls.fnl >> $@
	chmod 755 $@

clean:
	rm -f $(EXE)

test:
	TESTING=1 $(FENNEL) $(FENNELFLAGS) test/init.fnl

repl:
	$(FENNEL) $(FENNELFLAGS)

testall:
	$(MAKE) test LUA=lua5.1
	$(MAKE) test LUA=lua5.2
	$(MAKE) test LUA=lua5.3
	$(MAKE) test LUA=lua5.4
	$(MAKE) test LUA=luajit

docs:
	$(FENNEL) $(FENNELFLAGS) tools/gen-docs.fnl

install-deps:
	$(FENNEL) $(FENNELFLAGS) tools/vendor.fnl

install: $(EXE)
	mkdir -p $(DESTDIR)$(BINDIR) && cp $< $(DESTDIR)$(BINDIR)/

ci: testall $(EXE)

selfcheck:
	$(FENNEL) $(FENNELFLAGS) src/fennel-ls.fnl --check $(SRC)
