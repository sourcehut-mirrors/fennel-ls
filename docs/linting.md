# How to add a new lint

## Creating a new lint
To start, you can set up all the plumbing:

1. Go into `src/fennel-ls/lint.fnl` and create a new function.
2. At the bottom of `src/fennel-ls/lint.fnl`, add an if statement in the
   `check` function.
    * Choose which `each` loop to put your function in, so your lint can be
      applied to right thing.
    * add `(if checks.<your-check> (table.insert diagnostics (<your-check> self file <the rest of the args>)))`
3. Enable your lint! In `src/fennel-ls/state.fnl`, find the
   `default-configuration` variable, and turn your check on by default.

## Writing your lint
Now, the fun part: writing your lint function.

The goal is to check whether the given arguments should emit a warning, and
what message to show. The current loops in `check` go over every:
* definition (Every time a new variable is bound)
* call (Every time the user calls a function or a special. Macros don't count.)

More loops might have been added since I wrote this document.

### Input arguments
All lints give you `self` and `file`. They're mostly useful to pass to other
functions.
* `self` is the table that represents the language server. It carries metadata
  and stuff around. You probably don't need to use it directly.
* `file` is an object that represents a .fnl file. It has some useful fields.
  Check out what fields it has by looking at the end of `compiler.fnl`.

`file.lexical` stores the value `true` for every single list, table, or symbo
that appears in the original file AST, and `nil` for things generated via
macroexpansion. Make sure that the AST you're checking is inside of
`file.lexical`; otherwise, your lint may not be actionable or relevant, because
the user won't be able to see or edit the code your lint is warning about.

The next arguments depend on which loop the lint is in:
#### If your lint is linting definitions:
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
 :referenced-by {:symbol `x.myfield :target @1 :ref-type "read"}}
;; for y
{:definition `(my-expression) :binding `y :multival 2 :keys [:foo :bar]}
```

#### If your lint is linting calls (to functions or specials, not macros)
* `head` is the symbol that is being called. It is the same as `(. call 1)`.
* `call` is the list that represents the call.

### Output:
Your lint function should return `nil` if there's nothing to report, or
return a diagnostic object representing your lint message.

The return value should have these fields:

* `range`: make these with `message.ast->range` to get the range for a list or
  symbol or table, or with `message.multisym->range` to get the range of a
  specific segment of a multisym. Try to report specifically on which piece of
  AST is wrong. If its the entire call, give the range of the call. If its a
  specific argument, give the range of that argument if possible, and the call
  if not. Remember that we can't get the range of things like numbers and
  strings, because they don't have tracking info.
* `message`: this is the message your lint will produce. Try to make it
  specific and helpful as possible.
* `severity`: hardcode this to `message.severity.WARN`. ERROR is for compiler
  errors, and WARN is for lints.
* `code`: Please use a new number counting up from 301 for each lint. The codes
  are nice to have so that the message of the lint can change without breaking
  tests that only check for the presence or absence of a lint.
* `codeDescription`: Use the name of your function.

### Testing:
I will think about this later. :)
