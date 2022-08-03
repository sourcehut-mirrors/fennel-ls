(local foo (require :foo))
(require :bar)
(local {: bazfn} (require :baz))

(fn bar [a b]
  (print a b)
  (local c 10)
  (foo.my-export c))

(bar 1 2)

(print bazfn)

(let [bar "shadowed"]
  (print bar))

(λ test [{: foo}]
  (let [a 10]
    (match [0 10]
      [1 a] a
      [0 b] b)))

{: bar}
