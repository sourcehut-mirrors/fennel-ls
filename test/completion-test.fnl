(import-macros {: is-matching : describe : it : before-each} :test)
(local is (require :luassert))

(local {: view} (require :fennel))
(local {: ROOT-URI
        : open-file
        : completion-at
        : setup-server} (require :test.utils))

(local dispatch (require :fennel-ls.dispatch))
(local message (require :fennel-ls.message))

(local filename (.. ROOT-URI "imaginary-file.fnl"))

(describe "completions"
  (it "suggests globals"
    (local state (doto [] setup-server))
    ;; empty file
    (open-file state filename "(")
    (let [response (dispatch.handle* state (completion-at filename 0 1))]
      ;; TODO fix this test. Write a helper that will search a table and ensure at least one value matches.
      (is-matching response
        (where
          [{:result
            [{:label a}
             {:label b}
             {:label c}]}]
          (. _G a)
          (. _G b)
          (. _G c))
        "oops")))

  (it "suggests locals in scope"
    (local state (doto [] setup-server))
    (open-file state filename "(local x 10)\n(print )")
    (let [response (dispatch.handle* state (completion-at filename 1 7))]
      (var seen-suggestion false)
      (each [_ suggestion (ipairs (. response 1 :result))]
        (if (= suggestion.label :x)
          (set seen-suggestion true)))
      (assert seen-suggestion "x was not suggested"))))

  ;; (it "treats things in a call position differently")
  ;; (it "does not suggest locals out of scope")
  ;; (it "suggests fields of tables")
  ;; (it "suggests known fn fields of tables when using a method call multisym")
  ;; (it "suggests known fn keys when using the `:` special")
  ;; (it "suggests known keys when using the `.` special")
  ;; (it "suggests known module names in `require` and `include` and `import-macros` and `require-macros` and friends")
  ;; (it "knows the fields of the standard lua library.")
  ;; (it "suggests special forms for the call position of a list, but not other positions")
  ;; (it "does not suggest special forms for the \"call\" position when a list isn't actually a call, ie destructuring assignment")
  ;; (it "suggests keys when typing out destructuring, as in `(local {: typinghere} (require :mod))`")
  ;; (it "only suggests tables for `ipairs` / begin work on type checking system")
