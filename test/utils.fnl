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

(fn setup-server [self ?config]
  (dispatch.handle* self initialization-message)
  (if ?config
    (dispatch.handle* self {:jsonrpc "2.0"
                            :method :workspace/didChangeConfiguration
                            :params ?config})))

(fn open-file [self name text]
  (dispatch.handle* self
    (message.create-notification :textDocument/didOpen
      {:textDocument
       {:uri name
        :languageId "fennel"
        :version 1
        : text}})))

(fn completion-at [file line character]
  (message.create-request 2 :textDocument/completion
   {:position {: line : character} :textDocument {:uri file}}))

{: ROOT-URI
 : setup-server
 : open-file
 : completion-at}
