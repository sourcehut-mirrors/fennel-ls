(import-macros {: assert-matches : describe : it} :test.macros)
(local assert (require :luassert))

(local dispatch (require :fennel-ls.dispatch))
(local stringx (require :pl.stringx))

(local ROOT-PATH
  (-> (io.popen "pwd")
      (: :read :*a)
      (stringx.strip)
      (.. "/test/test-project")))
(local ROOT-URI
  (.. "file://" ROOT-PATH))

(local server-initialize-message
  {:id 1
   :jsonrpc "2.0"
   :method "initialize"
   :params
   {:capabilities {}
    :clientInfo {:name "Neovim" :version "0.7.2"}
    :initializationOptions {}
    :processId 16245
    :rootPath ROOT-PATH
    :rootUri ROOT-URI
    :trace "off"
    :workspaceFolders [{:name ROOT-PATH
                        :uri ROOT-URI}]}})

(describe "language server"
  (it "responds to initialize"
    (assert-matches
      (dispatch.handle* [] server-initialize-message)
      [{:id 1
        :jsonrpc "2.0"
        :result {:capabilities {}
                 :serverInfo {:name "fennel-ls" : version}}}]))

  (describe "jump to definition"
    (it "handles (local _ (require XXX)"
      (local state [])
      (dispatch.handle* state server-initialize-message)
      (assert-matches
        (dispatch.handle* state
         {:id 2
          :jsonrpc "2.0"
          :method "textDocument/definition"
          :params {:position {:character 11 :line 0}
                   :textDocument {:uri (.. ROOT-URI "/example.fnl")}}})
        (where [{:id 2
                 :jsonrpc "2.0"
                 :result {: uri :range {:start {:line 0 :character 0}
                                        :end {:line 0 :character 0}}}}]
               (stringx.endswith uri "foo.fnl"))))

    (it "handles (require XXX))"
      (local state [])
      (dispatch.handle* state server-initialize-message)
      (assert-matches
        (dispatch.handle* state
         {:id 2
          :jsonrpc "2.0"
          :method "textDocument/definition"
          :params {:position {:character 5 :line 1}
                   :textDocument {:uri (.. ROOT-URI "/example.fnl")}}})
        (where [{:id 2
                 :jsonrpc "2.0"
                 :result {: uri :range {:start {:line 0 :character 0}
                                        :end {:line 0 :character 0}}}}]
               (stringx.endswith uri "bar.fnl"))))))

    ;; (it "can go to a fn")
    ;; (it "can go to a local")
    ;; (it "can go to a table and its field")
    ;; (it "can go to a destructured local")
    ;; (it "can go to a table field in another file")))
