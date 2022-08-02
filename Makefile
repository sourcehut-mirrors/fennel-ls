LUA_LIB=/usr/lib/liblua.so.5.4
LUA_INCLUDE_DIR=/usr/include/lua5.4
SOURCES=$(wildcard src/*.fnl)
SOURCES+=$(wildcard src/fennel-ls/*.fnl)

.PHONY: test

fennel-ls: $(SOURCES)
	LUA_PATH="./src/?.lua;./src/?/init.lua" FENNEL_PATH="./src/?.fnl;./src/?/init.fnl" ./fennel --compile-binary src/fennel-ls.fnl fennel-ls $(LUA_LIB) $(LUA_INCLUDE_DIR)
clean:
	rm -f fennel-ls
test:
	FENNEL_PATH="./src/?.fnl;./src/?/init.fnl" ./fennel --correlate test/init.fnl --verbose
