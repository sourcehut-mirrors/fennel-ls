# Faith

> It's been a long road...  
> Getting from there to here.  

The Fennel Advanced Interactive Test Helper.

To use Faith, create a test runner file which calls the `run` function with
a list of module names. The modules should export functions whose
names start with `test-` and which call the assertion functions in the
`faith` module.

## Usage

Your test runner file `test/init.fnl` can be very short:

```fennel
(local t (require :faith))

(local default-modules [:test.one-thing :test.other :test.third])

(t.run (if (= 0 (length arg)) default-modules arg))
```

You can run the `t.run` function from the REPL as well after reloading
your test modules.

Tests are just functions in test modules which call assertion functions.

```fennel
(local t (require :faith))

;; A setup-all function can load files from disk; connect to a server, etc
(fn setup-all []
  (with-open [f (io.open "test/data.txt")]
    (let [contents (f:read :*all)]
      ;; whatever the setup-all function returns will be passed as
      ;; an argument to every test function.
      {: contents :length (length contents) :status "initialized"})))

(fn test-add [_data]
  (t.= 2 (+ 1 1))
  ;; assert= tests for deep equality, not just table identity
  (t.= [1 99] [1 (+ 45 44)]))

(fn test-check [data]
  (t.= 0 (- 2 2)))

{: setup-all
 : test-add
 : test-check}
```

You can provide `setup` and `teardown` functions to run before and after
each test, as well as, `setup-all` and `teardown-all` to run before and
after each test module.  Whatever values `setup-all` returns are passed
into each of the test functions and also the `teardown-all` function.

Note that in a language like Fennel that has tail-call optimization,
it's possible for an assertion on the last line of a function to fail
in a way that obscures the line number of the failure. If this is a
concern, you can put a `nil` or `(values)` on the last line of each
test function.

This is an issue for any test framework; it is not specific to Faith.

Faith supports PUC Lua 5.1 to 5.4 as well as LuaJIT.

If the `luasocket` or `luaposix` libraries are installed, Faith will
use them to calculate the total runtime of the test run. Without these
libraries, Lua is unable to track elapsed time with granularity of
under a second, so approximate times will be displayed instead.

## Assertions

All assertions take an optional message string as their last argument.

* `is`: checks truthiness (anything other than `false` or `nil`)
* `error`: checks that the given function errors out

All these assertions take the expected value first, then the actual.

* `=`: deep equality checks on tables, regular equality otherwise
* `not=`: checks the opposite of `=`
* `<`: checks that the arguments are in increasing order
* `<=`: checks that the arguments are in increasing or equal order
* `almost=`: is the actual value within a tolerance of expected?
* `identical`: regular `=` equality; checks tables for identity
* `match`: checks that the actual string matches an expected pattern
* `not-match`: checks the opposite
* `error-match`: checks that a function errors out and the error matches an
  expected pattern

You can call `skip` in a test to indicate that the test is incomplete
without triggering a failure.

## Developing Faith

Run `make testall` to run the full suite against all supported Lua
versions. Currently the `Makefile` assumes that there is a checkout of
Fennel itself in the same directory as your checkout of Faith, but you
can override this with, e.g., `make test FENNEL=/usr/local/bin/fennel`.

Discussion happens on [the Fennel mailing
list](https://lists.sr.ht/%7Etechnomancy/fennel) and on the `#fennel`
channel on Libera chat and matrix.org.

## TODO

* [ ] document hooks
* [ ] detailed/colored diffs for failed equality assertions?

## License

Faith was based on [lunatest](https://github.com/silentbicycle/lunatest)
originally but has evolved significantly since its beginning.

© 2009-2013 Scott Vokes and contributors
© 2023 Phil Hagelberg and contributors

Released under the [MIT License](LICENSE).
