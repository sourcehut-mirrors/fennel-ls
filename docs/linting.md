# How to add a new lint

## Creating a new lint
Go into `src/fennel-ls/lint.fnl` and create a new call to add-lint.

## Writing your lint
Now, the fun part: writing your lint function.

The goal is to check whether the given arguments should emit a warning, and
what message to show. You can request that your lint is called for every
* function-call (Every time the user calls a function)
* special-call (Every time the user calls a special)
* macro-call (Every time the user calls a macro)
* definition (Every time a new variable is bound)
* reference (Every time an identifier is referring to something in scope)

More types might have been added since I wrote this document.

### Input arguments
All lints receive a `server` and `file`. These values are mostly useful to
pass to other functions.
* `server` is the table that represents the language server. It carries
  metadata and stuff around. You probably don't need to use it directly.
* `file` is an object that represents a fennel source file. It has some
   useful fields. Check out what fields it has by looking at the end of
   `compiler.fnl`.

The next arguments depend on which type the lint is in:

#### "Call" type lints. (aka combinations aka compound forms aka lists):
There are three call types: `function-call`, `special-call`, and `macro-call`.
* `ast` is the AST of the call. it will be a list.
* `macroexpanded` will be the AST generated from the expansion of the macro,
  if the call was invoking a macro.

For example, if I had the code
```fnl
(let [(x y) (values 1 2)]
  (print (+ 1 x y)))
```
and I created a `function-call` lint, My lint would would be called once
with `ast` as `(print (+ 1 x y))`. If I created a `special-call` lint,
my lint would be called with `ast` as `(let [(x y) (values 1 2)] (print (+ 1 x y)))`,
with `(values 1 2)`, and with `(+ 1 x y)`.

#### "Reference" type lints
References are any time a symbol is referring to a local or global variable.
* `symbol` is the symbol that's referring to something.
For example, in the code
```fnl
(let [x 10]
  (print x))
```
`let` and `x` on line 1 are **not** references. `let` is a special, and `x` is
introducing a new binding, not referring to existing ones.
`print` and `x` on line 2 **are** references, and so a `reference` type
lint would be called for `print` and for `x`.

#### "Definition" type lints
* `symbol` is the symbol being bound. It is just a regular fennel sym.
* `definition` is a table full of information about what is being bound:
  * `definition.binding` is the symbol again.
  * `definition.definition`, if present, is the expression that we're
    evaluating.
  * `definition.referenced-by` is a list of "reference" object things.
  * `definition.keys`, if present, tells you what part of the definition is
    getting bound to `symbol`. It might be nil.
  * `definition.multival` tells you which value of the definition is getting
    bound to `symbol`, assuming `definition.definition` produces multiple
    values.
  * `definition.var?` is a boolean, which tells if the `symbol` is introduced
    as a variable.

#### "Other" type lints
Don't write these. :)

For example, if I write the code `(var x 1000)`, the definition will be:
```fnl
{:definition 1000 :binding `x :var? true}
```
If I write the code `(let [(x {:foo {:bar y}}) (my-expression)] x.myfield)`,
the definitions will be:
```fnl
;; for x
{:definition `(my-expression)
 :binding `x
 :multival 1
 :referenced-by {:symbol `x.myfield :ref-type "read"}}
;; for y
{:definition `(my-expression) :binding `y :multival 2 :keys [:foo :bar]}
```

### Output:
Your lint function should return `nil` if there's nothing to report, or
return a diagnostic object representing your lint message.

The return value should have these fields:

* `range`: make these with `message.ast->range` to get the range for a list or
  symbol or table, or with `message.multisym->range` to get the range of a
  specific segment of a multisym. Try to report specifically on which piece of
  AST is wrong. If its an entire list, give the range of the list. If a
  specific argument is problematic, give the range of that argument if possible,
  and the call if not. `message.ast->range` will not fail on lists, symbols, or
  tables, but it may fail on other AST items. (by returning `nil`)
* `message`: this is the message your lint will produce. Try to make it
  specific and helpful as possible; it doesn't have to be the same every time
  the lint is triggered.
* `severity`: hardcode this to `message.severity.WARN`. ERROR is for compiler
  errors, and WARN is for lints.
* `fix`: Optional. If there's a way to address this programmatically, you can
  add a "fix" field with the code to generate a quickfix. See the other lints
  for examples.

### Testing:
I will think about this later. :) For now see examples in `test/lint.fnl`.
