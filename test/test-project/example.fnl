(local foo (require :foo))
(require :bar)

(fn bar [a b]
  (print a b)
  (foo.my-export))

{: bar}
