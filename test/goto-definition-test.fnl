(import-macros {: is-matching : describe : it : before-each} :test)

(local is (require :luassert))

(local {: ROOT-URI
        : setup-server} (require :test.utils))

(local dispatch (require :fennel-ls.dispatch))
(local message  (require :fennel-ls.message))

(describe "jump to definition"

  (fn check [request-file line char response-file start-line start-col end-line end-col]
    (local state (doto [] setup-server))
    (let [message (dispatch.handle* state
                     (message.create-request 2 "textDocument/definition"
                       {:position {:character char :line line}
                        :textDocument {:uri (.. ROOT-URI "/" request-file)}}))
          uri (.. ROOT-URI "/" response-file)]
      (is-matching
        message
        [{:jsonrpc "2.0" :id 2
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

  (it "can go to a field inside of a table literal"
    (check :goto-definition.fnl 35 19 :goto-definition.fnl 34 20 34 35))

  (it "can go to a function in another file when accessed by multisym"
    (check :goto-definition.fnl 7 7 :foo.fnl 2 4 2 13))

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
    (check :goto-definition.fnl 47 13 :goto-definition.fnl 47 30 47 52)))

  ;; TODO
  ;; (it "doesn't leak function arguments to the surrounding scope")
  ;; (it "can go to a function in another file imported via destructuring assignment") ;; WORKS, just needs a test case
  ;; (it "can go through more than one extra file")
  ;; (it "will give up instead of freezing on recursive requires")
  ;; (it "finds the definition of in-file macros")
  ;; (it "can follow import-macros (destructuring)")
  ;; (it "can follow import-macros (namespaced)")
  ;; (it "can go to the definition even in a lua file")
  ;; (it "finds (set a.b) definitions")
  ;; (it "finds (fn a.b [] ...) declarations")
  ;; (it "finds (tset a :b) definitions")
  ;; (it "finds (setmetatable a {__index {:b def}) definitions")
  ;; (it "finds definitions into a function (fn foo [] (local x 10) {: x}) (let [result (foo)] (print result.x)) finds result.x")
  ;; (it "finds basic setmetatable definitions with an __index function")
  ;; (it "can return to callsite and go through a function's arguments when they're available")
  ;; (it "can go to a function's reference OR read type inference comments when callsite isn't available (PICK ONE)")
  ;; (it "can work with a custom fennelpath") ;; Wait until an options system is done
