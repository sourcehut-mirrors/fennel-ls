(import-macros {: is-matching : describe : it : before-each} :test)
(local is (require :test.is))

(local {: view &as fennel} (require :fennel))
(local {: create-client
        : ROOT-URI}
  (require :test.mock-client))

(local language (require :fennel-ls.language))
(local utils    (require :fennel-ls.utils))

(local filename (.. ROOT-URI "imaginary.fnl"))

(describe "multi-sym-split"
  (it "should be 1 on regular syms"
    (is.same ["foo"] (utils.multi-sym-split "foo" 2)))

  (it "should be 1 before the :"
    (is.same ["foo"] (utils.multi-sym-split "foo:bar" 3)))

  (it "should be 2 at the :"
    (is.same ["foo" "bar"] (utils.multi-sym-split "foo:bar" 4)))

  (it "should be 2 after the :"
    (is.same ["is" "equal"] (utils.multi-sym-split "is.equal" 5)))

  (it "should be big"
    (is.same ["a" "b" "c" "d" "e" "f"] (utils.multi-sym-split "a.b.c.d.e.f"))
    (is.same ["obj" "bar"] (utils.multi-sym-split (fennel.sym "obj.bar")))))

(describe "utf8") ;; TODO

(describe "find-symbol"
  (it "finds a symbol and parents"
    (let [state (doto (create-client)
                  (: :open-file! filename "(match [1 2 4] [1 2 sym-one] sym-one)"))
          file (. state.server.files filename)
          (symbol parents) (language.find-symbol file.ast 23)]
      (is.equal symbol (fennel.sym :sym-one))
      (is-matching
        ;; awful way to check AST equality, but I don't mind
        parents [[1 2 [:sym-one]] [[:match] [1 2 4] [1 2 [:sym-one]] [:sym-one]]]
        "bad parents")))

  (it "finds nothing, but still gives parents"
    (let [state (doto (create-client)
                  (: :open-file! filename "(match [1 2 4] [1 2 sym-one] sym-one)"))
          file (. state.server.files filename)
          (symbol parents) (language.find-symbol file.ast 18)]
      (is.equal symbol nil)
      (is-matching
        parents [[1 2 [:sym-one]] [[:match] [1 2 4] [1 2 [:sym-one]] [:sym-one]]]
        "bad parents"))))
(describe "failure"
  (it "doesn't crash"
    (let [self (create-client)
          state (require :fennel-ls.state)
          searcher (require :fennel-ls.searcher)]
     (is.not.nil (searcher.lookup self.server :crash-files.test1))
     (is.not.nil (state.get-by-module self.server :crash-files.test1)))))
     ; (is.not.nil (searcher.lookup self.server :crash-files.test2))
     ; (is.not.nil (state.get-by-module self.server :crash-files.test2)))))
