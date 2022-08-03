(import-macros {: assert-matches : describe : it} :test.macros)
(local assert (require :luassert))

(local {: ROOT-PATH : ROOT-URI} (require :test.util))
(local dispatch (require :fennel-ls.dispatch))

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
      [{:jsonrpc "2.0" :id 1
        :result {:capabilities {}
                 :serverInfo {:name "fennel-ls" : version}}}])))
