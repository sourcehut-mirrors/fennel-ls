(import-macros {: is-matching : describe : it : before-each} :test)
(local {: view} (require :fennel))

(local is (require :test.is))

(local {: ROOT-URI
        : create-client} (require :test.client))

(describe "jump to definition"

  (var CLIENT nil)
  (fn check [request-file line char response-file start-line start-col end-line end-col]
    (let [client (or CLIENT (create-client))
          message (client:definition (.. ROOT-URI :/ request-file) line char)
          uri (.. ROOT-URI "/" response-file)]
      (set CLIENT client)
      (is-matching
        message
        [{:jsonrpc "2.0" :id client.prev-id
          :result {: uri
                   :range {:start {:line start-line :character start-col}
                           :end   {:line end-line   :character end-col}}}}]
        (.. "expected position: " start-line " " start-col " " end-line " " end-col))))

  (it "can go to a fn"
    (check :goto-definition.fnl 9 3 :goto-definition.fnl 4 4 4 7))

  (it "can go to a local"
    (check :goto-definition.fnl 7 17 :goto-definition.fnl 6 9 6 10))

  (it "can go to a function argument"
    (check :goto-definition.fnl 5 9 :goto-definition.fnl 4 9 4 10))

  (it "can handle variables shadowed with let"
    (check :goto-definition.fnl 14 10 :goto-definition.fnl 13 6 13 9))

  (it "can sort out the unification rule with match (variable unified)"
    (check :goto-definition.fnl 19 12 :goto-definition.fnl 17 8 17 9))

  (it "can sort out the unification rule with match (variable introduced)"
    (check :goto-definition.fnl 20 13 :goto-definition.fnl 20 9 20 10))

  (it "can go to a destructured local"
    (check :goto-definition.fnl 21 9 :goto-definition.fnl 16 13 16 16))

  (it "can go to a function inside a table"
    (check :goto-definition.fnl 28 6 :goto-definition.fnl 4 4 4 7))

  (it "can go to the table containing a function"
    (check :goto-definition.fnl 28 3 :goto-definition.fnl 26 7 26 10))

  (it "can go to a field inside of a table literal"
    (check :goto-definition.fnl 35 19 :goto-definition.fnl 34 20 34 35))

  (it "can go to a function in another file when accessed by multisym"
    (check :goto-definition.fnl 7 7 :foo.fnl 2 4 2 13))

  (it "can go to a function in another file imported via destructuring assignment" ;; WORKS, just needs a test case
    (check :goto-definition.fnl 2 11 :baz.fnl 0 4 0 9))

  (it "goes further if you go to definition on a binding"
    (check :goto-definition.fnl 31 12 :goto-definition.fnl 23 4 23 5))

  ;; (it "can go to a destructured function argument")

  (it "can go up and down destructuring"
    (check :goto-definition.fnl 38 15 :goto-definition.fnl 33 7 33 13))

  (it "can go up and down field accesses"
    (check :goto-definition.fnl 45 15 :goto-definition.fnl 40 7 40 13))

  (it "works directly on a require/include (require XXX))"
    (check :goto-definition.fnl 1 5 :bar.fnl 0 0 0 2))

  (it "goes to the last form of `do` and `let`"
    (check :goto-definition.fnl 47 13 :goto-definition.fnl 47 30 47 52))

  (it "can go to `a.b` from an `a.b.c` symbol"
    (check :goto-definition.fnl 54 9 :goto-definition.fnl 53 13 53 25))

  (it "doesn't leak function arguments to the surrounding scope"
    (check :goto-definition.fnl 58 7 :goto-definition.fnl 53 7 53 8))

  (it "can go to identifiers introduced by (for)"
    (check :goto-definition.fnl 61 9 :goto-definition.fnl 60 6 60 7))

  (it "can go to identifiers introduced by (each)"
    (check :goto-definition.fnl 64 2 :goto-definition.fnl 63 7 63 8))

  (it "can go to a top level identifier"
    (let [c (create-client)
          _ (c:open-file! :foo.fnl "(fn x []) x")
          response (c:definition :foo.fnl 0 10)]
      (is-matching response
        [{:jsonrpc "2.0" :id c.prev-id
          :result {:uri :foo.fnl
                   :range {:start {:line 0 :character 4}
                           :end   {:line 0 :character 5}}}}])))

  (it "doesn't crash when doing this"
    (let [c (create-client)
          _ (c:open-file! :foo.fnl "(macro cool [a b] `(let [,b 10] ,a))\n(cool x x)")
          _response (c:definition :foo.fnl 1 6)
          _response (c:definition :foo.fnl 1 8)]
      nil))

  ;; (it "can go through more than one extra file")
  ;; (it "will give up instead of freezing on recursive requires")
  ;; (it "finds the definition of in-file macros")
  ;; (it "can follow import-macros (destructuring)")
  ;; (it "can follow import-macros (namespaced)")
  ;; (it "can go to the definition even in a lua file")
  ;; (it "finds (set a.b) definitions")
  (it "finds (fn a.b [] ...) declarations"
    (check :goto-definition.fnl 51 12 :goto-definition.fnl 50 4 50 22)))
  ;; (it "finds (tset a :b) definitions")
  ;; (it "finds (setmetatable a {__index {:b def}) definitions")
  ;; (it "finds definitions into a function (fn foo [] (local x 10) {: x}) (let [result (foo)] (print result.x)) finds result.x")
  ;; (it "finds definitions through a function (fn foo [{: y}] {:x y}) (let [result (foo {:y {}})] (print result.x)) finds result.x")
  ;; (it "finds through setmetatable with an __index function")
  ;; (it "can go to a function's references OR read type inference comments when callsite isn't available (PICK ONE)")
  ;; (it "can work with a custom fennelpath") ;; Wait until an options system is done
