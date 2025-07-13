# unused-definition
## What it does
Marks bindings that aren't read. Completely overwriting a value doesn't count
as reading it. A variable that starts or ends with an `_` will not trigger this
lint. Use this to suppress the lint.

## Why is this bad?
Unused definitions can lead to bugs and make code harder to understand. Either
remove the binding, or add an `_` to the variable name.

## Example
```fnl
(var value 100)
(set value 10)
```
Instead, use the value, remove it, or add `_` to the variable name.
```fnl
(var value 100)
(set value 10)
;; use the value
(print value)
```

## Known limitations
Fennel's pattern matching macros also check for leading `_` in symbols.
This means that adding `_` can change the semantics of the code. In this
situation, the user needs to add the `_` to the **end** of the symbol
to disable only the lint, without changing the pattern's meaning.
Only use a trailing underscore when it's required to prevent code from
changing meaning.
```fnl
;; Original. Works, but `b` is flagged by the lint
(match [10 nil]
  [a b] (print a "unintended")
  _ (print "we want this one")) ;; Prints this one!

;; Suppressing lint normally causes problems
(match [10 nil]
  [a _b] (print a "unintended") ;; Uh oh, we're printing "unintended" now!
  _ (print "we want this one"))

;; Solution! Underscore at the end
(match [10 nil]
  [a b_] (print a "unintended")
  _ (print "we want this one")) ;; Prints the right one
```

Think of the trailing underscore as the fourth possible sigil:
`?identifier` - must be used, and can be `nil`
`identifier` - must be used, and should be non-`nil`
`_identifier` - may be unused, and can be `nil`
`identifer_` - may be unused, but should be non-`nil`

# unknown-module-field
## What it does
Looks for module fields that can't be statically determined to exist. This only
triggers if the module is found, but there's no definition of the field inside
of the module.

## Why is this bad?
This is probably a typo, or a missing function in the module.

## Example
```fnl
;;; in `a.fnl`
{: print}

;;; in `b.fnl`
(local a (require :a))
(a.printtt 100)
```
Instead, use:
```fnl
;;; in `b.fnl`
(local a (require :a))
(a.print 100) ; typo fixed
```

## Known limitations
Fennel-ls doesn't have a full type system, so we're not able to check every
multisym statically, but as a heuristic, usually modules are able to be
evaluated statically. If you have a module that can't be figured out, please
let us know on the bug tracker.

# unnecessary-method
## What it does
Checks for unnecessary uses of the `:` method call syntax when a simple multisym
would work.

## Why is this bad?
Using the method call syntax unnecessarily adds complexity and can make code
harder to understand.

## Example
```fnl
(: alien :shoot-laser {:x 10 :y 20})
```

Instead, use:
```fnl
(alien:shoot-laser {:x 10 :y 20})
```

# unnecessary-tset
## What it does
Identifies unnecessary uses of `tset` when a `set` with a multisym would be clearer.

## Why is this bad?
Using `tset` makes the code more verbose and harder to read when a simpler
alternative exists.

## Example
```fnl
(tset alien :health 1337)
```

Instead, use:
```fnl
(set alien.health 1337)
```

# unnecessary-unary
## What it does
Warns about unnecessary `do` or `values` forms that only contain a single expression.

## Why is this bad?
Extra forms that don't do anything add syntactic noise.

## Example
```fnl
(do (print "hello"))

(values (+ 1 2))
```

Instead, use:
```fnl
(print "hello")

(+ 1 2)
```

# redundant-do
## What it does
Identifies redundant `do` blocks within implicit do forms like `fn`, `let`, etc.

## Why is this bad?
Redundant `do` blocks add unnecessary nesting and make code harder to read.

## Example
```fnl
(fn [] (do
  (print "first")
  (print "second")))
```

Instead, use:
```fnl
(fn []
  (print "first")
  (print "second"))
```

# bad-unpack
## What it does
Warns when `unpack` or `table.unpack` is used with operators that aren't
variadic at runtime.

## Why is this bad?
Fennel operators like `+`, `*`, etc. look like they should work with `unpack`,
but they don't actually accept a variable number of arguments at runtime.

## Example
```fnl
(+ 1 (unpack [2 3 4]))  ; Only adds 1 and 2
(.. (unpack ["a" "b" "c"]))  ; Only concatenates "a"
```

Instead, use:
```fnl
;; For concatenation:
(table.concat ["a" "b" "c"])

;; For other operators, use a loop:
(accumulate [sum 0 _ n (ipairs [1 2 3 4])]
  (+ sum n))
```

# var-never-set
## What it does
Identifies variables declared with `var` that are never modified with `set`.

## Why is this bad?
If a `var` is never modified, it should be declared with `local` or `let` instead
for clarity.

## Example
```fnl
(var x 10)
(print x)
```

Instead, use:
```fnl
(let [x 10]
  (print x))
```

# op-with-no-arguments
## What it does
Warns when an operator is called with no arguments, which can be replaced with
an identity value.

## Why is this bad?
Calling operators with no arguments is less clear than using the identity value
directly.

## Example
```fnl
(+)  ; Returns 0
(*)  ; Returns 1
(..)  ; Returns ""
```

Instead, use:
```fnl
0
1
""
```

## Known limitations
This lint isn't actually very useful.

# no-decreasing-comparison (off by default)
## What it does
Suggests using increasing comparison operators (`<`, `<=`) instead of decreasing ones (`>`, `>=`).

## Why is this bad?
Consistency in comparison direction makes code more readable and maintainable,
especially in languages with lisp syntax. You can think of `<` as a function that
tests if the arguments are in sorted order.

## Example
```fnl
(> a b)
(>= x y z)
```

Instead, use:
```fnl
(< b a)
(<= z y x)
```

# match-should-case
## What it does
Suggests using `case` instead of `match` when the meaning would not be altered.

## Why is this bad?
The `match` macro's meaning depends on the local variables in scope. When a
`match` call doesn't use the local variables, it can be replaced with the
`case` form.

## Example
```fnl
(match value
  10 "ten"
  20 "twenty"
  _ "other")
```

Instead, use:
```fnl
(case value
  10 "ten"
  20 "twenty"
  _ "other")
```

# inline-unpack
## What it does
Warns when multiple values from `values` or `unpack` are used in a non-final
position of a function call, where only the first value will be used.

## Why is this bad?
In Fennel (and Lua), multiple values are only preserved when they appear in the
final position of a function call. Using them elsewhere results in only the
first value being used. This is likely not what was intended, since the use of
`values` or `unpack` seems to imply that the code is interested in handling
multivals instead of discarding them.

## Example
```fnl
(print (values 1 2 3) 4)  ; confusingly prints "1   4"
```

Instead, use:
```fnl
;; Try putting the multival at the end:
(print 4 (values 1 2 3))

;; Try writing the logic out manually instead of using multival
(let [(a b c) (values 1 2 3)]
  (print a b c 4)
```

## Known limitations
It doesn't make sense to flag *all* places where a multival is discarded, because
discarding extra values is common in Lua. For example, in the standard library
of Lua, `string.gsub` and `require` actually return two results, even though
most of the time, only the first one is what's wanted.

This lint specifically flags discarding multivals from `values` and `unpack`,
instead of flagging all discards, because these forms indicate that the user
*intends* for something to happen with multivals.

You find more information about Lua's multivals in [Benaiah's excellent post explaining Lua's multivals](https://benaiah.me/posts/everything-you-didnt-want-to-know-about-lua-multivals),
or by searching the word "adjust" in the [Lua Manual](https://www.lua.org/manual/5.4/manual.html#3.4.12).

# empty-let
## What it does
Warns about `(let [] ...)` that should be `(do ...)`.

## Why is this bad?
Using `let` with no bindings is unnecessarily verbose when `do` serves the same purpose more clearly.

## Example
```fnl
(let []
  (print "hello")
  (print "world"))
```

Instead, use:
```fnl
(do
  (print "hello")
  (print "world"))
```

# mismatched-argument-count (off by default)
## What it does
Checks if function calls have the correct number of arguments based on the function's signature.

## Why is this bad?
Calling functions with the wrong number of arguments can lead to runtime errors
or unexpected behavior. This lint helps catch these issues early.

## Example
```fnl
(string.sub "hello")  ; missing required arguments
(string.sub "hello" 1 2 3)  ; too many arguments
```

Instead, use:
```fnl
(string.sub "hello" 1)  ; provide all required arguments
(string.sub "hello" 1 2)  ; remove extra arguments
```

## Known limitations
This lint is disabled by default because it can produce false positives.
It assumes that all optional arguments are reliably annotated with a ? sigil,
and any other arguments can be assumed to be required. This is reasonably
accurate if the code follows Fennel conventions. Also this lint is very new and
may have issues, so I'd like to let people try it on their own terms before
enabling it by default.

In the future I may split it into "too-many-arguments" (which is accurate regardless of code style)
and "not-enough-arguments" (which needs the arglist to be annotated properly)

# duplicate-table-keys
## What it does
Detects when the same key appears multiple times in a table literal.

## Why is this bad?
Duplicate keys in a table are usually a mistake and the later value will
overwrite the earlier one, which can lead to bugs.

## Example
```fnl
{:name "Alice"
 :age 25
 :name "Bob"}  ; "Alice" gets overwritten by "Bob"
```

Instead, use:
```fnl
{:name "Bob"
 :age 25}
```

