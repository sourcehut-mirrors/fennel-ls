(local dispatch (require :fennel-ls.dispatch))
(local message (require :fennel-ls.message))

(local ROOT-PATH
  (-> (io.popen "pwd")
      (: :read :*a)
      (: :sub 1 -2) ;; take off newline
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

(fn open-file [state name text]
  (dispatch.handle* state
    (message.create-notification "textDocument/didOpen"
      {:textDocument
       {:uri name
        :languageId "fennel"
        :version 1
        : text}})))

(fn completion-at [file line character]
  (message.create-request 2 "textDocument/completion"
   {:position {: line : character} :textDocument {:uri file}}))

{: ROOT-URI
 : setup-server
 : open-file
 : completion-at}
