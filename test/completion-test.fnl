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

(fn check-completion [body line col expected ?unexpected]
  (local state (doto [] setup-server))
  (open-file state filename body)
  (let [response (dispatch.handle* state (completion-at filename line col))
        seen (collect [_ suggestion (ipairs (. response 1 :result))]
                suggestion.label suggestion.label)]
    (each [_ exp (ipairs expected)]
      (is.truthy (. seen exp) (.. exp " was not suggested, but should be")))
    (if ?unexpected
      (each [_ exp (ipairs ?unexpected)]
        (is.nil (. seen exp) (.. exp " was suggested, but shouldn't be"))))))

(describe "completions"
  (it "suggests globals"
    (check-completion "(" 0 1 [:_G :debug :table :io :getmetatable :setmetatable :_VERSION :ipairs :pairs :next]))

  (it "suggests locals in scope"
    (check-completion "(local x 10)\n(print )" 1 7 [:x]))

  (it "suggests locals in scope at the top level"
    (check-completion "(local x 10)\n\n" 1 0 [:x]))

  (it "suggests more locals in scope"
    (check-completion "(let [x 10] (let [y 100] \n    nil\n    ))" 2 4 [:x :y]))

  (it "suggests specials and macros at beginning of list"
    (check-completion "()" 0 1 [:do :let :fn :doto :-> :-?>> :?.])
    (check-completion "(d)" 0 3 [:do :doto]))

  (it "suggests macros in scope"
    (check-completion "(macro funny [] `nil)\n()" 1 1 [:funny])))

  ;; ;; Compiler hardening
  ;; (it "works without requiring the close parentheses"))
  ;; (it "works without a body in the `let`"))
  ;; (it "does not suggest locals out of scope")
  ;; (it "suggests items from the previous definitions in the same `let`")

  ;; ;; Functions
  ;; (it "suggests function arguments at the top scope of the function")
  ;; (it "suggests function arguments deep within the function")

  ;; ;; Scope Ordering Rules
  ;; (it "does not suggest locals past the suggestion location when a symbol is partially typed")
  ;; (it "does not suggest locals past the suggestion location without a symbol")
  ;; (it "does not suggest locals past the suggestion point at the top level")
  ;; (it "does not suggest items from later definitions in the same `let`")
  ;; (it "does not suggest macros defined from later definitions")

  ;; ;; Call ordering rules

  ;; (it "doesn't suggest specials in the middle of a list (open paren required)"
  ;;   (check-completion "(do )"
  ;;                     0 4 [] [:do :let :fn :-> :-?>> :?.])))


  ;; (it "doesn't suggest specials at the very top level")
  ;; (it "doesn't suggest macros in the middle of a list (open paren required)")
  ;; (it "doesn't suggest macros at the very top level")

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
