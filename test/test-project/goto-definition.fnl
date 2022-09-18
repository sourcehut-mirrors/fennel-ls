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

(fn test [{: foo}]
  (let [a 10]
    (match [0 10]
      [1 a] a
      [0 b] b))
  (print foo))

(fn b []
  (print "function"))

(local obj {: bar :a b})

(obj.bar 2 3)
(obj:a)

(local redefinition b)

(local findme 10)
(local deep {:a {:b {:field findme}}})
(local {:a {:b shallow}} deep)
(local mixed [{:key [5 {:foo shallow}]}])
(local [{:key [_ {:foo funny}]}] mixed)
(print funny.field)

(local findme 10) ;; via field access instead of destructure
(local deep {:a {:b {:field findme}}})
(local shallow deep.a.b)
(local mixed [{:key [5 {:foo shallow}]}])
(local funny (. mixed 1 :key 2 :foo))
(print funny.field)

(local object (do (let [a 10] {:my-definition :here})))

(local module {})
(fn module.my-function [a b c] "docstring" (let [body (+ a b c)] body))
(module.my-function 1 2 3)

(local x {:y {:z (+ 1 1)}})
(print x.y.z)
