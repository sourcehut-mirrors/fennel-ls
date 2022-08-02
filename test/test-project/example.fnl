(local foo (require :foo))
(require :bar)
(local {: bazfn} (require :baz))

(fn bar [a b]
  (print a b)
  (local c 10)
  (foo.my-export c))

(bar 1 2)

(print bazfn)

{: bar}
