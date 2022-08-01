(local foo (require :foo))
(require :bar)
(local {: bazfn} (require :baz))

(fn bar [a b]
  (print a b)
  (foo.my-export))

(bar 1 2)

(print bazfn)

{: bar}
