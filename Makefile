LUA_LIB=/usr/lib/liblua.so.5.4
LUA_INCLUDE_DIR=/usr/include/lua5.4
FENNEL=./fennel
EXE=fennel-ls

SRC=$(wildcard src/*.fnl)
SRC+=$(wildcard src/fennel-ls/*.fnl)

.PHONY: clean test

all: $(EXE)

$(EXE): $(SRC)
	LUA_PATH="./src/?.lua;./src/?/init.lua" FENNEL_PATH="./src/?.fnl;./src/?/init.fnl" $(FENNEL) --compile-binary src/fennel-ls.fnl fennel-ls $(LUA_LIB) $(LUA_INCLUDE_DIR)

clean:
	rm -f fennel-ls

test:
	# requires busted to be installed
	FENNEL_PATH="./src/?.fnl;./src/?/init.fnl" $(FENNEL) --correlate test/init.fnl --verbose
