(import-macros {: assert-matches : describe : it} :test.macros)
(local assert (require :luassert))

(local dispatch (require :fennel-ls.dispatch))
(local stringx (require :pl.stringx))

(local ROOT-PATH
  (-> (io.popen "pwd")
      (: :read :*a)
      (stringx.strip)))
(local ROOT-URI
  (.. "document://" ROOT-PATH))

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

  (it "can jump to definition"
    (local state [])
    (dispatch.handle* state server-initialize-message)
    (assert-matches
      (dispatch.handle* state
       {:id 2
        :jsonrpc "2.0"
        :method "textDocument/definition"
        :params {:position {:character 5 :line 0}
                 :textDocument {:uri (.. ROOT-URI "/test.fnl")}}})
      [{:id 2
        :jsonrpc "2.0"
        :result {: uri : range}}]))) ;; FIXME: test whether the location is correct
