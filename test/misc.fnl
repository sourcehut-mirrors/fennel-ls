(local faith (require :faith))
(local fennel (require :fennel))
(local {: create-client
        : ROOT-URI}
  (require :test.utils.client))

(local language (require :fennel-ls.language))
(local utils    (require :fennel-ls.utils))

(local filename (.. ROOT-URI "imaginary.fnl"))

(fn test-multi-sym-split []
  (faith.= ["foo"] (utils.multi-sym-split "foo" 2))
  (faith.= ["foo"] (utils.multi-sym-split "foo:bar" 3))
  (faith.= ["foo" "bar"] (utils.multi-sym-split "foo:bar" 4))
  (faith.= ["is" "equal"] (utils.multi-sym-split "is.equal" 5))
  (faith.= ["a" "b" "c" "d" "e" "f"] (utils.multi-sym-split "a.b.c.d.e.f"))
  (faith.= ["obj" "bar"] (utils.multi-sym-split (fennel.sym "obj.bar")))
  nil)

(fn test-find-symbol []
  (let [state (doto (create-client)
                (: :open-file! filename "(match [1 2 4] [1 2 sym-one] sym-one)"))
        file (. state.server.files filename)
        (symbol parents) (language.find-symbol file.ast 23)]
    (faith.= symbol (fennel.sym :sym-one))
    (faith.=
      "[[1 2 sym-one] (match [1 2 4] [1 2 sym-one] sym-one) [(match [1 2 4] [1 2 sym-one] sym-one)]]"
      (fennel.view parents {:one-line? true})
      "bad parents"))

  (let [state (doto (create-client)
                (: :open-file! filename "(match [1 2 4] [1 2 sym-one] sym-one)"))
        file (. state.server.files filename)
        (symbol parents) (language.find-symbol file.ast 18)]
    (faith.= symbol nil)
    (faith.=
      "[[1 2 sym-one] (match [1 2 4] [1 2 sym-one] sym-one) [(match [1 2 4] [1 2 sym-one] sym-one)]]"
      (fennel.view parents {:one-line? true})
      "bad parents"))
  nil)

(fn test-failure []
  (let [self (create-client)
        state (require :fennel-ls.state)
        searcher (require :fennel-ls.searcher)]
   (faith.not= nil (searcher.lookup self.server :crash-files.test1))
   (faith.not= nil (state.get-by-module self.server :crash-files.test1)))
  ;; TODO turn off TESTING=1 in makefile
   ; (faith.not= nil (searcher.lookup self.server :crash-files.test2))
   ; (faith.not= nil (state.get-by-module self.server :crash-files.test2)))
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
