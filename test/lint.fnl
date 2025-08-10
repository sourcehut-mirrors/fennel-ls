(local faith (require :faith))
(local {: view} (require :fennel))
(local {: create-client} (require :test.utils))

(fn find [diagnostics e]
  "returns the index of the diagnostic "
   (accumulate [result nil
                i d (ipairs diagnostics)
                &until result]
     (let [d (or d.self d)]
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
         i))))

(fn check [file-contents expected ?unexpected]
  (let [{: uri : client} (create-client file-contents)
        [{:result {:items diagnostics}}] (client:diagnostic uri)]
    (each [_ e (ipairs (or ?unexpected []))]
      (let [i (find diagnostics e)]
        (faith.= nil i (.. "Lint matching " (view e) "\n"
                           "from:    " (view file-contents) "\n"
                           (view (. diagnostics i) {:escape-newlines? true})))))

    (each [_ e (ipairs expected)]
      (let [i (find diagnostics e)]
        (faith.is i (.. "No lint matching " (view e) "\n"
                        "from:    " (view file-contents) "\n"
                        "possible matches: " (view diagnostics {:empty-as-sequence? true
                                                                :escape-newlines? true})))
        (table.remove diagnostics i)))))

(fn assert-ok [file-contents]
  (let [{: uri : client} (create-client file-contents)
        [{:result {:items diagnostics}}] (client:diagnostic uri)]
    (faith.= nil (next diagnostics) (view diagnostics))))

(fn test-unused []
  (check "(local x 10)"
         [{:message "unused definition: x"
           :code :unused-definition
           :range {:start {:character 7 :line 0}
                   :end   {:character 8 :line 0}}}])
  (check "(fn x [])"
         [{:message "unused definition: x"
           :code :unused-definition
           :range {:start {:character 4 :line 0}
                   :end   {:character 5 :line 0}}}])
  (check "(let [(x y) (values 1 2)] x)"
         [{:code :unused-definition
           :range {:start {:character 9  :line 0}
                   :end   {:character 10 :line 0}}}])
  (check "(case [1 1 2 3 5 8] [a a] (print :first-two-equal))"
         [{:code :unused-definition}])
  (assert-ok "(case [1 1 2 3 5 8] [a_ a_] (print :first-two-equal))")
  ;; setting a var without reading
  (check "(var x 1) (set x 2) (set [x] [3])"
          [{:code :unused-definition
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
         [{:code :unknown-module-field :message "unknown field: c"}
          {:code :unknown-module-field :message "unknown field: guy.d"}]
         [{:code :unknown-module-field :message "unknown field: a"}
          {:code :unknown-module-field :message "unknown field: b"}])
  (check "table.insert2 table.insert"
         [{:code :unknown-module-field :message "unknown field: table.insert2"}]
         [{:code :unknown-module-field :message "unknown field: table.insert"}])
  ;; if you explicitly write "_G", it should turn off this test.
  ;; Hardcoded at the top of analyzer.fnl/search-document.
  (check "_G.insert2"
         []
         [{:code :unknown-module-field}])
  ;; we don't care about nested
  (check {:requireme.fnl "{:field []}"
          :main.fnl "(local {: field} (require :requireme))
                     field.unknown"}
         []
         [{:code :unknown-module-field}])
  ;; specials are OK too
  (check {:unpacker.fnl "(local unpack (or table.unpack _G.unpack)) {: unpack}"
          :main.fnl "(local u (require :unpacker))
                     (print (u.unpack [:haha :lol]))"}
         []
         [{:code :unknown-module-field}])
  (check "package.loaded.mymodule io.stderr.write"
         []
         [{:code :unknown-module-field}])
  nil)

(fn test-unnecessary-method []
  (check "(let [x :haha] (: x :find :a))"
         [{:message "unnecessary : call: use (x:find)"
           :code :unnecessary-method
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
         [{:code :bad-unpack}])

  (check "(.. (table.unpack [\"hello\" \"world\"]))"
         [{:code :bad-unpack :message #($:find "table.concat")}])

  (check "(* (table.unpack [\"hello\" \"world\"]))"
         [{:code :bad-unpack :message #(not ($:find "table%.concat"))}])

  ;; only when lexical
  (assert-ok "(-> [1 2 3] table.unpack +)")
  nil)

(fn test-unset-var []
  (check "(var x nil) (print x)"
         [{:code :var-never-set
           :range {:start {:character 5 :line 0}
                   :end   {:character 6 :line 0}}}])

  (assert-ok "(var x 1) (set x 2) (print x)")
  (assert-ok "(local x 10) (?. x)")
  nil)

;; missing test for 306

(fn test-unpack-in-middle []
  (check "(+ 1 2 3 (values 4 5) 6)"
         [{:code :inline-unpack
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
         [{:code :unnecessary-tset
           :message "unnecessary tset"
           :range {:start {:character 15 :line 0}
                   :end {:character 32 :line 0}}}])
  (check "(local tbl {}) (tset tbl :key :nested 9)"
         [{:code :unnecessary-tset}])
  ;; Lint only triggers on keys that can be written as a sym
  (check "(local tbl {}) (tset tbl \"hello-world\" 249)"
         [{:code :unnecessary-tset}])
  ;; symbols like tbl.01234567 *are* valid >:)
  (check "(local tbl {}) (tset tbl \"01234567\" 249)"
         [{:code :unnecessary-tset}])
  (assert-ok "(local tbl {}) (tset tbl \"hello world\" 1)")
  (assert-ok "(local tbl {}) (tset tbl \"0123.4567\" 1)")
  nil)

(fn test-unnecessary-unary []
  ;; multi-arg do
  (assert-ok "(do (print :x) 11)")
  ;; unnecessary do
  (check "(do 9)"
         [{:message "unnecessary unary do"
           :code :unnecessary-unary
           :range {:start {:character 0 :line 0}
                   :end {:character 6 :line 0}}}])
  ;; unnecessary values
  (check "(print :hey (values :lol))"
         [{:code :unnecessary-unary
           :message "unnecessary unary values"
           :range {:start {:character 12 :line 0}
                   :end {:character 25 :line 0}}}])
  (check "(+ (* 3) (* 4 4))"
         [{:message "unnecessary unary *"
           :code :unnecessary-unary
           :range {:start {:character 3 :line 0}
                   :end {:character 8 :line 0}}}])
  nil)

(fn test-empty-do []
  ;; good do
  (assert-ok "(do (print 1) 2)")
  ;; unnecessary one
  (check "(do (do) 1 2)"
         [{:code :empty-do
           :message "remove do with no body"
           :range {:start {:character 4 :line 0}
                   :end {:character 8 :line 0}}}])
  nil)

(fn test-redundant-do []
  ;; good do
  (assert-ok "(case 134 x (do (print :x x) 11))")
  ;; unnecessary one
  (check "(let [x 29] (do (print 9) x))"
         [{:code :redundant-do
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
              [{: x}] (print x)))")
  ;; values pattern
  (assert-ok "(let [x 99]
                (match 49
                  (x _ 9) (print :values-ref)))")
  ;; warn: basic no pinning
  (check "(match 91 z (print :yeah2 z))"
         [{:message "no pinned patterns; use case instead of match"
           :code :match-should-case
           :range {:start {:character 1 :line 0}
                   :end {:character 6 :line 0}}}])
  ;; warn: nested no pinning
  (check "(match [32] [lol] (print :nested-no-pin lol))"
         [{:message "no pinned patterns; use case instead of match"
           :code :match-should-case
           :range {:start {:character 1 :line 0}
                   :end {:character 6 :line 0}}}])
  ;; shouldn't trigger on quoted forms
  (assert-ok "(macro foo [] `(match x x x))")
  nil)

(fn test-op-with-no-arguments []
  (assert-ok "(and 1 2)")
  (assert-ok "(and false 1)")
  (assert-ok "(and nil 1)")
  (check "(and)"
         [{:message "write true instead of (and)"
           :code :op-with-no-arguments
           :range {:start {:character 0 :line 0}
                   :end {:character 5 :line 0}}}])
  nil)

(fn test-empty-let []
  (assert-ok "(let [x 1] x)")
  (check "(let [] print)"
         [{:message "use do instead of let with no bindings"
           :code :empty-let
           :range {:start {:character 5 :line 0}
                   :end {:character 7 :line 0}}}])
  (assert-ok "(-> [] (let print))")
  nil)

(fn test-decreasing-comparison []
  (assert-ok "(let [x 5] (< 1 x 4))")
  (assert-ok "(let [x 5] (<= 1 x 4))")
  (assert-ok "(let [x 5] (> 4 x 1))")
  (assert-ok "(let [x 5] (>= 4 x 1))")
  (let [add-opts #{:main.fnl $ :flsproject.fnl "{:lints {:no-decreasing-comparison true}}"}]
    (assert-ok (add-opts "(let [x 5] (< 1 x 4))"))
    (assert-ok (add-opts "(let [x 5] (<= 1 x 4))"))
    (check (add-opts "(let [x 5] (> 4 x 1))")
           [{:message "Use increasing operator instead of decreasing"
             :code :no-decreasing-comparison
             :range {:start {:character 11 :line 0}
                     :end {:character 20 :line 0}}}])
    (check (add-opts "(let [x 5] (>= 4 x 1))")
           [{:message "Use increasing operator instead of decreasing"
             :code :no-decreasing-comparison
             :range {:start {:character 11 :line 0}
                     :end {:character 21 :line 0}}}])
    nil))

(fn test-arg-count []
  ;; methods
  (let [add-opts #{:main.fnl $ :flsproject.fnl "{:lints {:not-enough-arguments true}}"}]
    (check     (add-opts "(fn foo [a b c ?d ?e] (print a b c ?d ?e))\n(foo 1 2)")
               [{:code :not-enough-arguments
                 :message "foo expects at least 3 argument(s); found 2"}])
    (assert-ok (add-opts "(fn foo [a b c ?d ?e] (print a b c ?d ?e))\n(foo 1 2 3)"))
    (assert-ok (add-opts "(fn foo [a b c ?d ?e] (print a b c ?d ?e))\n(foo 1 2 3 4 5)"))
    (check     (add-opts "(fn foo [a b c ?d ?e] (print a b c ?d ?e))\n(foo 1 2 3 4 5 6)")
               [{:code :too-many-arguments
                 :message "foo expects at most 5 argument(s); found 6"}])
    (assert-ok (add-opts "(let [f :hi] (f:byte))"))
    (check     (add-opts "(let [f :hi] (f:sub))")
               [{:code :not-enough-arguments
                 :message "f:sub expects at least 1 argument(s); found 0"}])
    (check     (add-opts "(let [f :hi] (f:sub 1 2 3))")
               [{:code :too-many-arguments
                 :message "f:sub expects at most 2 argument(s); found 3"}])
    (check     (add-opts "(let [obj {:field (fn foo [])}] (obj:field))")
               [{:code :too-many-arguments
                 :message "obj.field expects 0 arguments; found 1"}])
    (assert-ok (add-opts "(let [foo 10] (fn [] foo))"))
    (assert-ok (add-opts "(fn [])"))
    nil))

(fn test-duplicate-keys []
  (assert-ok "{:a 1 :b 2}")
  (assert-ok "(local _ {:a 1}) {:a 2}")
  (check "{:a 1 :a 2}" [{:code :duplicate-table-keys :message "key a appears more than once"}])
  (check "{:there :are
           :lots :of
           :choices :for
           :which :key
           :to :include
           :in :the
           :message :.
           :which :one?}" [{:code :duplicate-table-keys :message "key which appears more than once"}])
  (check "(local a 1) {:a 2 : a}" [{:code :duplicate-table-keys}])
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

(fn test-nested-associative-operator []
  (check "(and foo (and bar baz) xyz)"
         [{:message "nested and can be collapsed"
           :code :nested-associative-operator}])

  (check "(+ a (+ b c) d)"
         [{:message "nested + can be collapsed"
           :code :nested-associative-operator}])

  (check "(or x (or y z))"
         [{:message "nested or can be collapsed"
           :code :nested-associative-operator}])

  (check "(and foo (and bar baz) (and this that))"
         [{:message "nested and can be collapsed"
           :code :nested-associative-operator}])

  (assert-ok "(and true false true)") ; no nesting
  (assert-ok "(+ 1 2 3)") ; no nesting
  (assert-ok "(* (+ 1 2) 3)") ; different operations
  (assert-ok "(and true (or false true))") ; different operators
  nil)

(fn test-zero-indexed []
  (let [add-opts #{:main.fnl $ :flsproject.fnl "{:lints {:zero-indexed true}}"}]
    (check (add-opts "(local x {})
                      (. x 0)")
           [{:code "zero-indexed"
             :message "indexing a table with 0; did you forget that Lua is 1-indexed?"}])
    (check (add-opts "(. math 0)")
           [{:code "zero-indexed"
             :message "indexing a table with 0; did you forget that Lua is 1-indexed?"}])
    (assert-ok (add-opts "(. math 1)"))
    (assert-ok (add-opts "(. arg 0)"))
    (assert-ok (add-opts "(. math :0)")))
  nil)



{: test-unused
 : test-ampersand
 : test-unknown-module-field
 : test-unnecessary-method
 : test-unnecessary-tset
 : test-unnecessary-unary
 : test-empty-do
 : test-redundant-do
 : test-unset-var
 : test-match-should-case
 : test-unpack-into-op
 : test-unpack-in-middle
 : test-op-with-no-arguments
 : test-empty-let
 : test-decreasing-comparison
 : test-arg-count
 : test-duplicate-keys
 : test-nested-associative-operator
 : test-zero-indexed}
