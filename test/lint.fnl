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

(fn check [file-contents expected ?unexpected]
  (let [{: diagnostics} (create-client file-contents)]
    (each [_ e (ipairs (or ?unexpected []))]
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

(fn assert-ok [file-contents]
  (let [{: diagnostics} (create-client file-contents)]
    (faith.= nil (next diagnostics) (view diagnostics))))

(fn test-unused []
  (check "(local x 10)"
         [{:message "unused definition: x"
           :code 301
           :range {:start {:character 7 :line 0}
                   :end   {:character 8 :line 0}}}])
  (check "(fn x [])"
         [{:message "unused definition: x"
           :code 301
           :range {:start {:character 4 :line 0}
                   :end   {:character 5 :line 0}}}])
  (check "(let [(x y) (values 1 2)] x)"
         [{:code 301
           :range {:start {:character 9  :line 0}
                   :end   {:character 10 :line 0}}}])
  (check "(case [1 1 2 3 5 8] [a a] (print :first-two-equal))" [{:code 301}])
  (assert-ok "(case [1 1 2 3 5 8] [a_ a_] (print :first-two-equal))")
  ;; setting a var without reading
  (check "(var x 1) (set x 2) (set [x] [3])"
          [{:code 301
            :range {:start {:character 5 :line 0}
                    :end   {:character 6 :line 0}}}])
  ;; setting a field without reading is okay
  (assert-ok "(fn [a b] (set a.x 10) (fn b.f []))")
  (assert-ok "(case {:b 1} (where (or {:a x} {:b x})) x)")

  (check "(fn foo [a] nil) (foo)" [{:message "unused definition: a"}])
  (check "(λ foo [a] nil) (foo)" [{:message "unused definition: a"}])
  (check "(lambda foo [a] nil) (foo)" [{:message "unused definition: a"}])

  nil)

(fn test-ampersand []
  (assert-ok "(let [[x & y] [1 2 3]]
                (print x (. y 1) (. y 2)))")
  (assert-ok "(let [{1 x & y} [1 2 3]]
                (print x (. y 2) (. y 3)))")
  (assert-ok "(let [[x &as y] [1 2 3]]
                (print x (. y 2) (. y 3)))")
  (assert-ok "(let [{1 x &as y} [1 2 3]]
                (print x (. y 2) (. y 3)))")
  (assert-ok "(fn [x & more]
                (print x more))")
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
  ;; specials are OK too
  (check {:unpacker.fnl "(local unpack (or table.unpack _G.unpack)) {: unpack}"
          :main.fnl "(local u (require :unpacker))
                     (print (u.unpack [:haha :lol]))"}
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
                   :end   {:character 29 :line 0}}}])

  ;; no warning from macros
  (assert-ok "(let [x :haha y :find] (-> x (: y :a))
                (let [x :haha] (-> x (: :find :a))))")

  ;; no warning when its an expression, or when string has spaces
  (assert-ok "(let [x :haha]
                (: x \"bar baz\") (: x 1) (: x x))")
  nil)

(fn test-unpack-into-op []
  (check "(+ (unpack [1 2 3]))"
         [{:code 304}])

  (check "(.. (table.unpack [\"hello\" \"world\"]))"
         [{:code 304 :message #($:find "table.concat")}])

  (check "(* (table.unpack [\"hello\" \"world\"]))"
         [{:code 304 :message #(not ($:find "table%.concat"))}])

  ;; only when lexical
  (assert-ok "(-> [1 2 3] table.unpack +)")
  nil)

(fn test-unset-var []
  (check "(var x nil) (print x)"
         [{:code 305
           :range {:start {:character 5 :line 0}
                   :end   {:character 6 :line 0}}}])

  (assert-ok "(var x 1) (set x 2) (print x)")
  (assert-ok "(local x 10) (?. x)")
  nil)

;; missing test for 306

(fn test-unpack-in-middle []
  (check "(+ 1 2 3 (values 4 5) 6)"
         [{:code 307
           :range {:start {:line 0 :character 9}
                   :end   {:line 0 :character 21}}}])

  ;; not in a statement, should be covered by another lint
  (assert-ok "(let [x 10] (values 4 5) x)")
  (assert-ok "(do (values 4 5) (_G.unpack 6 7) (table.unpack 8 9) 10)")
  nil)

(fn test-unnecessary-tset []
  ;; valid, if you're targeting older Fennels
  (assert-ok "(local [tbl key] [{} :k]) (tset tbl key 249)")
  ;; never a good use of tset
  (check "(local tbl {}) (tset tbl :key 9)"
         [{:code 309
           :codeDescription "unnecessary-tset"
           :message "unnecessary tset"
           :range {:start {:character 15 :line 0}
                   :end {:character 32 :line 0}}}])
  (check "(local tbl {}) (tset tbl :key :nested 9)" [{:code 309}])
  ;; Lint only triggers on keys that can be written as a sym
  (check "(local tbl {}) (tset tbl \"hello-world\" 249)" [{:code 309}])
  (assert-ok "(local tbl {}) (tset tbl \"01234567\" 249)")
  (assert-ok "(local tbl {}) (tset tbl \"hello world\" 1)")
  (assert-ok "(local tbl {}) (tset tbl \"0123.4567\" 1)")
  nil)

(fn test-unnecessary-do []
  ;; multi-arg do
  (assert-ok "(do (print :x) 11)")
  ;; unnecessary do
  (check "(do 9)" [{:message "unnecessary do"
                    :code 310
                    :codeDescription "unnecessary-do-values"
                    :range {:start {:character 0 :line 0}
                            :end {:character 6 :line 0}}}])
  ;; unnecessary values
  (check "(print :hey (values :lol))"
         [{:code 310
           :codeDescription "unnecessary-do-values"
           :message "unnecessary values"
           :range {:start {:character 12 :line 0}
                   :end {:character 25 :line 0}}}])
  nil)

(fn test-redundant-do []
  ;; good do
  (assert-ok "(case 134 x (do (print :x x) 11))")
  ;; unnecessary one
  (check "(let [x 29] (do (print 9) x))"
         [{:code 311
           :codeDescription "redundant-do"
           :message "redundant do"
           :range {:start {:character 12 :line 0}
                   :end {:character 28 :line 0}}}])
  nil)

(fn test-match-should-case []
  ;; most basic pinning
  (assert-ok "(let [x 99] (match 99 x :yep!))")
  ;; pinning inside where clause
  (assert-ok "(let [x 99]
                (match 98
                  y (print y)
                  (where x (= 0 (math.fmod x 2))) (print x)))")
  ;; nested pinning
  (assert-ok "(let [x 99]
            (match [{:x 32}]
              [{: x}] (print x)))" [] [{}])
  ;; values pattern
  (assert-ok "(let [x 99]
                (match 49
                  (x _ 9) (print :values-ref)))")
  ;; warn: basic no pinning
  (check "(match 91 z (print :yeah2 z))"
         [{:message "no pinned patterns; use case instead of match"
           :code 308
           :range {:start {:character 1 :line 0}
                   :end {:character 6 :line 0}}}])
  ;; warn: nested no pinning
  (check "(match [32] [lol] (print :nested-no-pin lol))"
         [{:message "no pinned patterns; use case instead of match"
           :code 308
           :range {:start {:character 1 :line 0}
                   :end {:character 6 :line 0}}}])
  nil)

;; TODO lints:
;; duplicate keys in kv table
;; (tset <sym> <any>) --> (set (. <sym> <any>)) (might be wanted for compat?)
;; {&as x} and [&as x] pattern with no other matches
;; Unused fields (maybe difficult)
;; discarding results to various calls, such as unpack, values, etc
;; `pairs` or `ipairs` call in a (for) binding table
;; steal as many lints as possible from cargo
;; unnecessary parens around single multival destructure

;; unused variable, when a function binding is only used in its body, and the function value is discarded

{: test-unused
 : test-ampersand
 : test-unknown-module-field
 : test-unnecessary-colon
 : test-unnecessary-tset
 : test-unnecessary-do
 : test-redundant-do
 : test-unset-var
 : test-match-should-case
 : test-unpack-into-op
 : test-unpack-in-middle}
 
