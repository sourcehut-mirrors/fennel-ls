FENNEL=./fennel
EXE=fennel-ls

SRC=$(wildcard src/*.fnl)
SRC+=$(wildcard src/fennel-ls/*.fnl)

.PHONY: clean test

all: $(EXE)

$(EXE): $(SRC)
	echo "#!/usr/bin/env lua" > $@
	LUA_PATH="./src/?.lua;./src/?/init.lua" FENNEL_PATH="./src/?.fnl;./src/?/init.fnl" \
		$(FENNEL) --require-as-include --compile src/fennel-ls.fnl >> $@
	chmod 755 $@

clean:
	rm -f $(EXE)

test:
	# requires busted to be installed
	FENNEL_PATH="./src/?.fnl;./src/?/init.fnl" $(FENNEL) --correlate test/init.fnl --verbose
