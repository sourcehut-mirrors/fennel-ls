LUA ?= lua
FENNEL=$(LUA) fennel
EXE=fennel-ls

SRC=$(wildcard src/*.fnl)
SRC+=$(wildcard src/fennel-ls/*.fnl)
SRC+=$(wildcard src/fennel-ls/docs/*.fnl)

DESTDIR ?=
PREFIX ?= /usr/local
BINDIR ?= $(PREFIX)/bin

OPTS=--add-package-path "./src/?.lua" --add-fennel-path "./src/?.fnl"
OPTS+=--skip-include fennel.compiler

.PHONY: all clean test install ci selfcheck

all: $(EXE)

$(EXE): $(SRC)
	echo "#!/usr/bin/env $(LUA)" > $@
	$(FENNEL) $(OPTS) --require-as-include --compile src/fennel-ls.fnl >> $@
	chmod 755 $@

clean:
	rm -f $(EXE)

test:
	TESTING=1 $(FENNEL) $(OPTS) --add-fennel-path "./test/faith/?.fnl" test/init.fnl

repl:
	$(FENNEL) $(OPTS) --add-fennel-path "./test/faith/?.fnl"

testall:
	$(MAKE) test LUA=lua5.1
	$(MAKE) test LUA=lua5.2
	$(MAKE) test LUA=lua5.3
	$(MAKE) test LUA=lua5.4
	$(MAKE) test LUA=luajit

install: $(EXE)
	mkdir -p $(DESTDIR)$(BINDIR) && cp $< $(DESTDIR)$(BINDIR)/

ci: testall $(EXE)

selfcheck:
	$(FENNEL) $(OPTS) src/fennel-ls.fnl --check $(SRC)
