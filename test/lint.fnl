(local faith (require :faith))
(local {: view} (require :fennel))
(local {: create-client} (require :test.utils))

(fn find [diagnostics e]
  "returns the index of the diagnostic "
   (accumulate [result nil
                i d (ipairs diagnostics)
                &until result]
     (if (and (or (= e.message nil)
                  (if (= (type e.message) "function")
                    (e.message d.message)
                    (= e.message d.message)))
              (or (= e.code nil)
                  (= e.code d.code))
              (or (= e.range nil)
                  (and (= e.range.start.line      d.range.start.line)
                       (= e.range.start.character d.range.start.character)
                       (= e.range.end.line        d.range.end.line)
                       (= e.range.end.character   d.range.end.character))))
       i)))

(fn check [file-contents expected unexpected]
  (let [{: diagnostics} (create-client file-contents)]
    (each [_ e (ipairs unexpected)]
      (let [i (find diagnostics e)]
        (faith.= nil i (.. "Lint matching " (view e) "\n"
                           "from:    " (view file-contents) "\n"
                           (view (. diagnostics i) {:escape-newlines? true})))))

    (each [_ e (ipairs expected)]
      (let [i (find diagnostics e)]
        (faith.is i (.. "No lint matching " (view e) "\n"
                        "from:    " (view file-contents) "\n"
                        (view diagnostics {:empty-as-sequence? true
                                           :escape-newlines? true})))
        (table.remove diagnostics i)))))

(fn test-unused []
  (check "(local x 10)"
         [{:message "unused definition: x"
           :code 301
           :range {:start {:character 7 :line 0}
                   :end   {:character 8 :line 0}}}] [])
  (check "(fn x [])"
         [{:message "unused definition: x"
           :code 301
           :range {:start {:character 4 :line 0}
                   :end   {:character 5 :line 0}}}] [])
  (check "(let [(x y) (values 1 2)] x)"
         [{:code 301
           :range {:start {:character 9  :line 0}
                   :end   {:character 10 :line 0}}}] [])
  ;; setting a var without reading
  (check "(var x 1) (set x 2) (set [x] [3])"
          [{:code 301
            :range {:start {:character 5 :line 0}
                    :end   {:character 6 :line 0}}}] [])
  ;; setting a field without reading is okay
  (check "(fn [a b] (set a.x 10) (fn b.f []))" [] [{}])
  (check "(case {:b 1} (where (or {:a x} {:b x})) x)" [] [{}])

  (check "(fn foo [a] nil) (foo)" [{:message "unused definition: a"}] [])
  (check "(λ foo [a] nil) (foo)" [{:message "unused definition: a"}] [])
  (check "(lambda foo [a] nil) (foo)" [{:message "unused definition: a"}] [])

  nil)

(fn test-ampersand []
  (check "(let [[x & y] [1 2 3]]
            (print x (. y 1) (. y 2)))"
         [] [{:message "unused definition: &"} {}])
  (check "(let [{1 x & y} [1 2 3]]
            (print x (. y 2) (. y 3)))"
         [] [{:message "unused definition: &"} {}])
  (check "(let [[x &as y] [1 2 3]]
            (print x (. y 2) (. y 3)))"
         [] [{:message "unused definition: &as"} {}])
  (check "(let [{1 x &as y} [1 2 3]]
            (print x (. y 2) (. y 3)))"
         [] [{:message "unused definition: &as"} {}])
  (check "(fn [x & more]
            (print x more))"
         [] [{:message "unused definition: &"} {}])
  nil)

(fn test-unknown-module-field []
  (check {:the-guy-they-tell-you-not-to-worry-about.fnl
          "(local M {:a 1})
           (fn M.b [] 2)
           M"
          :main.fnl
          "(local {: a : c &as guy} (require :the-guy-they-tell-you-not-to-worry-about))
           (print guy.b guy.d)"}
         [{:code 302 :message "unknown field: c"}
          {:code 302 :message "unknown field: guy.d"}]
         [{:code 302 :message "unknown field: a"}
          {:code 302 :message "unknown field: b"}])
  (check "table.insert2 table.insert"
         [{:code 302 :message "unknown field: table.insert2"}]
         [{:code 302 :message "unknown field: table.insert"}])
  ;; if you explicitly write "_G", it should turn off this test.
  ;; Hardcoded at the top of analyzer.fnl/search-document.
  (check "_G.insert2"
         []
         [{:code 302}])
  ;; we don't care about nested
  (check {:requireme.fnl "{:field []}"
          :main.fnl "(local {: field} (require :requireme))
                     field.unknown"}
         []
         [{:code 302}])
  (check "package.loaded.mymodule io.stderr.write"
         []
         [{:code 302}])
  nil)

(fn test-unnecessary-colon []
  (check "(let [x :haha] (: x :find :a))"
         [{:message "unnecessary : call: use (x:find)"
           :code 303
           :range {:start {:character 15 :line 0}
                   :end   {:character 29 :line 0}}}] [])

  ;; no warning from macros
  (check "(let [x :haha y :find] (-> x (: y :a))
          (let [x :haha] (-> x (: :find :a))"
         [] [{:code 303}])

  ;; no warning when its an expression, or when string has spaces
  (check "(let [x :haha]
            (: x \"bar baz\") (: x 1) (: x x))"
         [] [{:code 303}])
  nil)

(fn test-unpack-into-op []
  (check "(+ (unpack [1 2 3]))"
         [{:code 304}] [])

  (check "(.. (table.unpack [\"hello\" \"world\"]))"
         [{:code 304 :message #($:find "table.concat")}] [])

  (check "(* (table.unpack [\"hello\" \"world\"]))"
         [{:code 304 :message #(not ($:find "table%.concat"))}]
         [{:code 304 :message #($:find "table.concat")}])

  ;; only when lexical
  (check "(-> [1 2 3] unpack +)"
         [] [{:code 304}])
  nil)

(fn test-unset-var []
  (check "(var x nil) (print x)"
         [{:code 305
           :range {:start {:character 5 :line 0}
                   :end   {:character 6 :line 0}}}] [])

  (check "(var x 1) (set x 2) (print x)"
         [] [{}])
  (check "(local x 10) (?. x)"
         [] [{:code 305}])
  nil)

;; missing test for 306

(fn test-unpack-in-middle []
  (check "(+ 1 2 3 (values 4 5) 6)"
         [{:code 307
           :range {:start {:line 0 :character 9}
                   :end   {:line 0 :character 21}}}]
         [])

  ;; not in a statement, should be covered by another lint
  (check "(let [x 10] (values 4 5) x)"
         [] [{:code 307}])
  (check "(do (values 4 5) (_G.unpack 6 7) (table.unpack 8 9) 10)"
         [] [{:code 307}])
  nil)

;; TODO lints:
;; unnecessary (do) in body position
;; duplicate keys in kv table
;; (tset <sym> <str>) --> (set <sym>.<str>)
;; (tset <sym> <any>) --> (set (. <sym> <any>))
;; {&as x} and [&as x] pattern with no other matches
;; Unused variables / fields (maybe difficult)
;; discarding results to various calls, such as unpack, values, etc
;; unnecessary `do`/`values` with only one inner form
;; `pairs` or `ipairs` call in a (for) binding table
;; mark when unification is happening on a `match` pattern (may be difficult)
;; steal as many lints as possible from cargo
;; unnecessary parens around single multival destructure

;; unused variable, when a function binding is only used in its body, and the function value is discarded

{: test-unused
 : test-ampersand
 : test-unknown-module-field
 : test-unnecessary-colon
 : test-unset-var
 : test-unpack-into-op
 : test-unpack-in-middle}
