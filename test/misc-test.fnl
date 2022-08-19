(import-macros {: is-matching : describe : it : before-each} :test)
(local is (require :luassert))

(local fennel (require :fennel))
(local {: multi-sym-split} (require :fennel-ls.utils))

(describe "multi-sym-split"
  (it "should be 1 on regular syms"
    (is.same ["foo"] (multi-sym-split "foo" 2)))

  (it "should be 1 before the :"
    (is.same ["foo"] (multi-sym-split "foo:bar" 3)))

  (it "should be 2 at the :"
    (is.same ["foo" "bar"] (multi-sym-split "foo:bar" 4)))

  (it "should be 2 after the :"
    (is.same ["is" "equal"] (multi-sym-split "is.equal" 5)))

  (it "should be big"
    (is.same ["a" "b" "c" "d" "e" "f"] (multi-sym-split "a.b.c.d.e.f"))
    (is.same ["obj" "bar"] (multi-sym-split (fennel.sym "obj.bar")))))
