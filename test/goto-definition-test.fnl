(import-macros {: is-matching : describe : it : before-each} :test.macros)
(local is (require :luassert))

(local fennel (require :fennel))
(local {: ROOT-URI
        : setup-server} (require :test.util))

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
    (check "example.fnl" 9 3 "example.fnl" 4 4 4 7))

  (it "can go to a local"
    (check "example.fnl" 7 17 "example.fnl" 6 9 6 10))

  (it "can go to a function argument"
    (check "example.fnl" 5 9 "example.fnl" 4 9 4 10))

  (it "can handle variables shadowed with let"
    (check "example.fnl" 14 10 "example.fnl" 13 6 13 9))

  (it "can sort out the unification rule with match (variable unified)"
    (check "example.fnl" 19 12 "example.fnl" 17 8 17 9))

  (it "can sort out the unification rule with match (variable introduced)"
    (check "example.fnl" 20 13 "example.fnl" 20 9 20 10))

  (it "can go to a destructured local"
    (check "example.fnl" 21 9 "example.fnl" 16 13 16 16))

  (it "can go to a function inside a table"
    (check "example.fnl" 28 6 "example.fnl" 4 4 4 7))

  ;; (it "can go to a field inside of a table")

  (it "can go to a function in another file when accessed by multisym"
    (check "example.fnl" 7 7 "foo.fnl" 2 4 2 13))

  (it "goes further if you go to definition on a binding"
    (check "example.fnl" 31 12 "example.fnl" 23 4 23 5))


  ;; (it "can go to a destructured function argument")

  ;; it can go up and down destructuring
  (it "can trace a variable that was introduced with destructuring assignment"
    (check "example.fnl" 38 15 "example.fnl" 33 7 33 13)))


  ;; (it "works directly on a require/include (require XXX))"
  ;;   (check "example.fnl" 1 5 "bar.fnl" 0 0 0 0))

  ;; (it "can go to a reference that occurs in a macro")
  ;; (it "doesn't have ghost definitions from the same byte ranges as the macro files it's using")
  ;; (it "can go to a function in another file imported via destructuring assignment")
  ;; (it "can work with a custom fennelpath")
  ;; (it "can go through more than one extra file")
  ;; (it "will give up instead of freezing on recursive requires")
  ;; (it "does slightly better in the presense of macros")
  ;; (it "finds the definition of macros")
  ;; (it "can follow import-macros")
  ;; (it "can go to the definition even in a lua file")
  ;; (it "can go to a function's arguments when they're available")

