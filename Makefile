LUA_LIB=/usr/lib/liblua.so.5.4
LUA_INCLUDE_PATH=$(shell lua5.4 -e 'print(package.cpath:match("[^;]+"))')
SOURCES=$(wildcard src/*.fnl)
SOURCES+=$(wildcard src/fennel-ls/*.fnl)

.PHONY: test

fennel-ls: $(SOURCES)
	FENNEL_PATH=src/?.fnl fennel --compile-binary src/fennel-ls.fnl fennel-ls $(LUA_LIB) $(LUA_INCLUDE_PATH)

test:
	fennel --correlate test/init.fnl


