(local stringx (require :pl.stringx))
(local dispatch (require :fennel-ls.dispatch))

(local ROOT-PATH
  (-> (io.popen "pwd")
      (: :read :*a)
      (stringx.strip)
      (.. "/test/test-project")))
(local ROOT-URI
  (.. "file://" ROOT-PATH))

(local initialization-message
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

(fn setup-server [state]
  (dispatch.handle* state initialization-message))

{: ROOT-URI : setup-server}
