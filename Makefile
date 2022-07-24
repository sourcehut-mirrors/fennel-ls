STATIC_LUA_LIB=/usr/lib/liblua.so.5.4
LUA_INCLUDE_PATH=$(shell lua5.4 -e 'print(package.cpath:match("[^;]+"))')
SOURCES=$(wildcard *.fnl)

fennel-ls: $(SOURCES)
	fennel --compile-binary main.fnl fennel-ls $(STATIC_LUA_LIB) $(LUA_INCLUDE_PATH)

