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
(local value 100)
(set value 10)
```

Instead, use the value, remove it, or add `_` to the variable name.
```fnl
(local value 100)
(set value 10)
;; use the value
(print value)
```

## Known limitations
Fennel's pattern matching macros also check for leading `_` for symbol names.
This means that adding an `_` can change the semantics of the code. In this
situation, add the `_` to the end of the symbol to disable the lint without
changing the pattern's meaning.
```fnl
(match [10 nil]
    ;; pattern works as intended, but triggers the lint
    [a b] (print a "unintended")
    _ (print "unintended"))

(match [10 nil]
    ;; pattern matches when we don't want it to
    [a _b] (print a "unintended")
    _ (print "unintended"))

(match [10 nil]
    ;; works as intended and doesn't trigger lint
    [a b_] (print a "unintended")
    _ (print "unintended"))
```

Think of it this way:
`identifier` - must be used, and should be non-`nil`
`?identifier` - must be used, and can be `nil`
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

# unnecessary-do-values
## What it does
Warns about unnecessary `do` or `values` forms that only contain a single expression.

## Why is this bad?
Extra `do` or `values` forms without multiple expressions add syntactic noise.

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

## Note
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

# multival-in-middle-of-call
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

## Limitations
It doesn't make sense to flag *all* places where a multival is discarded, because
discarding extra values is common in Lua. For example, in the standard library
of Lua, `string.gsub` and `require` actually return two results, even though
most of the time, only the first one is what's wanted.

This lint specifically flags discarding multivals from `values` and `unpack`,
instead of flagging all discards, because these forms indicate that the user
*intends* for something to happen with multivals.

## Note
You find more information about Lua's multivals in [Benaiah's excellent post explaining Lua's multivals](https://benaiah.me/posts/everything-you-didnt-want-to-know-about-lua-multivals),
or by searching the word "adjust" in the [Lua Manual](https://www.lua.org/manual/5.4/manual.html#3.4.12).