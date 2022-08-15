(fn my-function [arg1 arg2 arg3]
  (let [result nil]
    result))

(local foo 300)
(let [bar "some text"]
  (my-function foo bar 3))

(local foo {:field1 10 :field2 :colon-string})
(my-function foo.field1 foo.field2)

(local empty nil)
(print empty)

(fn sd [] "short docstring"
  nil)
(fn ld [arg1]
  "long docstring

This function has a long docstring, and returns nil.
The docstring has newlines and markdown and stuff in it.

```fnl
(ld 100 100) ;; ==> nil
```

@arg arg1 is ignored
@arg arg2 is ignored.
@returns nil"
  (let [result nil]
    result))

(ld (sd))
