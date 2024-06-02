(local faith (require :faith))
(local fennel (require :fennel))
(local {: create-client-with-files} (require :test.utils))

(local language (require :fennel-ls.language))
(local utils    (require :fennel-ls.utils))


(fn test-multi-sym-split []
  (faith.= ["foo"] (utils.multi-sym-split "foo" 2))
  (faith.= ["foo"] (utils.multi-sym-split "foo:bar" 3))
  (faith.= ["foo" "bar"] (utils.multi-sym-split "foo:bar" 4))
  (faith.= ["is" "equal"] (utils.multi-sym-split "is.equal" 5))
  (faith.= ["a" "b" "c" "d" "e" "f"] (utils.multi-sym-split "a.b.c.d.e.f"))
  (faith.= ["obj" "bar"] (utils.multi-sym-split (fennel.sym "obj.bar")))
  nil)

(fn test-find-symbol []
  (let [{: server : uri} (create-client-with-files "(match [1 2 4] [1 2 sym-one] sym-one)")
        file (. server.files uri)
        (symbol parents) (language.find-symbol file.ast 23)]
    (faith.= symbol (fennel.sym :sym-one))
    (faith.=
      "[[1 2 sym-one] (match [1 2 4] [1 2 sym-one] sym-one) [(match [1 2 4] [1 2 sym-one] sym-one)]]"
      (fennel.view parents {:one-line? true})
      "bad parents"))

  (let [{: server : uri} (create-client-with-files "(match [1 2 4] [1 2 sym-one] sym-one)")
        file (. server.files uri)
        (symbol parents) (language.find-symbol file.ast 18)]
    (faith.= symbol nil)
    (faith.=
      "[[1 2 sym-one] (match [1 2 4] [1 2 sym-one] sym-one) [(match [1 2 4] [1 2 sym-one] sym-one)]]"
      (fennel.view parents {:one-line? true})
      "bad parents"))
  nil)

(fn test-failure []
  (create-client-with-files "(macro foo {} nil)
                             (λ test {} nil)
                             (λ {} nil")
  (create-client-with-files "(fn foo []\n  #\n  (print :test))")
  nil)

(fn test-split-spaces []
  (faith.= [] (utils.split-spaces ""))
  (faith.= ["foo"] (utils.split-spaces "foo"))
  (faith.= ["foo"] (utils.split-spaces "  foo "))
  (faith.= ["foo-bar" "bar" "baz"] (utils.split-spaces "foo-bar bar baz"))
  (faith.= ["foo-bar" "bar" "baz"] (utils.split-spaces " foo-bar  bar baz  "))
  nil)

{: test-multi-sym-split
 : test-find-symbol
 : test-failure
 : test-split-spaces}
