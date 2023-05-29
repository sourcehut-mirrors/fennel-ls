(import-macros {: is-matching : describe : it : before-each} :test)
(local is (require :test.is))

(local {: view} (require :fennel))
(local {: ROOT-URI
        : create-client} (require :test.mock-client))

(local dispatch (require :fennel-ls.dispatch))
(local message (require :fennel-ls.message))

(local filename (.. ROOT-URI "/imaginary-file.fnl"))

(fn check-completion [body line col expected ?unexpected]
  (let [client (doto (create-client)
                 (: :open-file! filename body))
        response (client:completion filename line col)
        seen (collect [_ suggestion (ipairs (. response 1 :result))]
                suggestion.label suggestion.label)]
    (if expected
      (each [_ exp (ipairs expected)]
        (is (. seen exp) (.. exp " was not suggested, but should be"))))
    (if ?unexpected
      (each [_ exp (ipairs ?unexpected)]
        (is.nil (. seen exp) (.. exp " was suggested, but shouldn't be"))))))

(fn check-no-completion [body line col expected ?unexpected]
  (let [client (doto (create-client)
                 (: :open-file! filename body))
        response (client:completion filename line col)]
    (is-matching (. response 1)
      {:jsonrpc "2.0" :id id :result nil}
      "there shouldn't be a result")))

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
    ;; it's not the language server's job to do filtering,
    ;; so there's no negative assertions here for other symbols
    (check-completion "(d)" 0 2 [:do :doto]))

  (it "suggests macros in scope"
    (check-completion "(macro funny [] `nil)\n()" 1 1 [:funny]))

  (it "does not suggest locals out of scope"
    (check-completion "(do (local x 10))\n" 1 0 [] [:x]))

  (it "does not suggest function args out of scope"
    (check-completion "(fn [x] (print x))\n" 1 0 [] [:x])
    (check-completion "(fn [x] (print x))\n(print " 1 7 [] [:x]))

  (describe "When the program doesn't compile"
    (it "still completes without requiring the close parentheses"
      (check-completion "(fn foo [z]\n  (let [x 10 y 20]\n    " 1 2 [:x :y :z]))

    (it "still completes with no body in the `let`"
      (check-completion "(let [x 10 y 20]\n  )" 1 2 [:x :y]))

    (it "still completes items from the previous definitions in the same `let`"
      (check-completion "(let [a 10\n      b 20\n      " 1 6 [:a :b]))

    (it "completes fields with a partially typed multisym that ends in :"
      (check-completion "(local x {:field (fn [])})\n(x:" 1 3 [:field] [:local]))

    (it "doesn't crash with a partially typed multisym contains ::"
      (check-no-completion "(local x {:field (fn [])})\n(x::f" 1 3 [:field])))

  ;; Functions
  (it "suggests function arguments at the top scope of the function"
    (check-completion "(fn foo [arg1 arg2 arg3]\n  )" 1 2 [:arg1 :arg2 :arg3]))

  (it "suggests function arguments at the top scope of the function"
    (check-completion "(fn foo [arg1 arg2 arg3]\n  (do (do (do ))))" 1 14 [:arg1 :arg2 :arg3]))

  ;; ;; Scope Ordering Rules
  ;; (it "does not suggest locals past the suggestion location when a symbol is partially typed")
  ;; (it "does not suggest locals past the suggestion location without a symbol")
  ;; (it "does not suggest locals past the suggestion point at the top level")
  ;; (it "does not suggest items from later definitions in the same `let`")
  ;; (it "does not suggest macros defined from later definitions")

  ;; ;; Call ordering rules
  (it "doesn't suggest specials in the middle of a list"
    (check-completion "(do )"
      0 4 [] [:do :let :fn :-> :-?>> :?.]))

  ;; (it "doesn't suggest specials at the very top level")
  ;; (it "doesn't suggest macros in the middle of a list (open paren required)")
  ;; (it "doesn't suggest macros at the very top level")

  (it "suggests fields of tables"
    (check-completion
      "(let [my-table {:foo 10 :bar 20}]\n  my-table.)))"
      1 11
      [:foo :bar]
      [:_G :local :doto :1])) ;; no globals, specials, macros, or others

  (it "suggests fields of tables indirectly"
    (check-completion
      "(let [foo (require :foo)]\n  foo.)))"
      1 6
      [:my-export :constant]
      [:_G :local :doto :1])) ;; no globals, specials, macros, or others

  ;; (it "suggests fields of strings"))
  (it "suggests known fn fields of tables when using a method call multisym"
    (check-completion "(local x {:field (fn [])})\n(x:fi" 1 5 [:field] [:table])))


  ;; (it "suggests known fn keys when using the `:` special")
  ;; (it "suggests known keys when using the `.` special")
  ;; (it "suggests known module names in `require` and `include` and `import-macros` and `require-macros` and friends")
  ;; (it "knows the fields of the standard lua library.")
  ;; (it "suggests special forms for the call position of a list, but not other positions")
  ;; (it "does not suggest special forms for the \"call\" position when a list isn't actually a call, ie destructuring assignment")
  ;; (it "suggests keys when typing out destructuring, as in `(local {: typinghere} (require :mod))`")
  ;; (it "only suggests tables for `ipairs` / begin work on type checking system")
