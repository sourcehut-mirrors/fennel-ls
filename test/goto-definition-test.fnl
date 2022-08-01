(import-macros {: assert-matches : describe : it : before-each} :test.macros)
(local assert (require :luassert))

(local fennel (require :fennel))
(local {: ROOT-URI
        : setup-server} (require :test.util))

(local dispatch (require :fennel-ls.dispatch))
(local message  (require :fennel-ls.message))

(describe "jump to definition"

  (var state nil)

  (before-each
    (set state [])
    (setup-server state))

  (fn request-definition-at [line char file]
    (message.create-request 2 "textDocument/definition"
      {:position {:character char :line line}
       :textDocument {:uri (.. ROOT-URI "/" file)}}))

  (it "handles (local _ (require XXX)"
    (local uri (.. ROOT-URI "/" "foo.fnl"))
    (assert-matches
      (dispatch.handle* state (request-definition-at 0 11 "example.fnl"))
      [{:jsonrpc "2.0" :id 2
        :result {: uri :range {:start {:line 0 :character 0}
                               :end {:line 0 :character 0}}}}]))

  (it "handles (require XXX))"
    (local uri (.. ROOT-URI "/" "bar.fnl"))
    (assert-matches
      (dispatch.handle* state (request-definition-at 1 5 "example.fnl"))
      [{:jsonrpc "2.0" :id 2
        :result {: uri :range {:start {:line 0 :character 0}
                               :end {:line 0 :character 0}}}}])))

  ;; TODO
  ;; (it "can go to a fn"
  ;;   (local uri (.. ROOT-URI "/" "example.fnl"))
  ;;   (assert-matches
  ;;     (dispatch.handle* state (request-definition-at 8 2 "example.fnl"))
  ;;     [{:jsonrpc "2.0" :id 2
  ;;       :result {: uri :range {:start {:line 4 :character 0}
  ;;                              :end {:line 6 :character 17}}}}])))

   ;; (it "can open a require with a custom fennelpath")
   ;; (it "can go to a fn")
   ;; (it "can go to a local")
   ;; (it "can go to a table and its field")
   ;; (it "can go to a destructured local")
   ;; (it "can go to a table field in another file")
   ;; (it "can go to a table field in another file (through a destructuring assignment)")
   ;; (it "can go to a field in a lua file")
   ;; (it "finds the definition of macros")
   ;; (it "can go through more than one extra file")
   ;; (it "will give up on recursive requires")
   ;; (it "can follow import-macros")

  ;; (describe "diagnostic")
    ;; (it "reports compiler errors")
    ;; (it "reports lint warnings")

  ;; (describe "completion")

