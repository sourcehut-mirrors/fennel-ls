(local dispatch (require :fennel-ls.dispatch))
(local message (require :fennel-ls.message))

(local ROOT-PATH
  (-> (io.popen "pwd")
      (: :read :*a)
      (: :sub 1 -2) ;; take off newline
      (.. "/test/test-project")))

(local ROOT-URI
  (.. "file://" ROOT-PATH))

(local default-params
   {:capabilities {:general {:positionEncodings [:utf-8]}}
    :clientInfo {:name "Neovim" :version "0.7.2"}
    :initializationOptions {}
    :processId 16245
    :rootPath ROOT-PATH
    :rootUri ROOT-URI
    :trace "off"
    :workspaceFolders [{:name ROOT-PATH
                        :uri ROOT-URI}]})

(local mt {})
(fn create-client [?opts]
  (let [self (doto {:server [] :prev-id 1} (setmetatable mt))
        initialize {:id 1
                    :jsonrpc "2.0"
                    :method "initialize"
                    :params (or (?. ?opts :params) default-params)}
        result (dispatch.handle* self.server initialize)]
    (case (?. ?opts :settings)
      settings
      (dispatch.handle* self.server
        {:jsonrpc "2.0"
         :method :workspace/didChangeConfiguration
         :params {: settings}}))
    (values self result)))

(fn next-id! [self]
  (set self.prev-id (+ self.prev-id 1))
  self.prev-id)

(fn open-file! [self name text]
  (dispatch.handle* self.server
    (message.create-notification :textDocument/didOpen
      {:textDocument
       {:uri name
        :languageId "fennel"
        :version 1
        : text}})))

(fn completion [self file line character]
  (dispatch.handle* self.server
    (message.create-request (next-id! self) :textDocument/completion
     {:position {: line : character}
      :textDocument {:uri file}})))

(fn definition [self file line character]
  (dispatch.handle* self.server
    (message.create-request (next-id! self) :textDocument/definition
      {:position {: line : character}
       :textDocument {:uri file}})))

(fn hover [self file line character]
  (dispatch.handle* self.server
     (message.create-request (next-id! self) :textDocument/hover
       {:position {: line : character}
        :textDocument {:uri file}})))

(fn references [self file line character ?includeDeclaration]
  (dispatch.handle* self.server
    (message.create-request (next-id! self) :textDocument/references
     {:position {: line : character}
      :textDocument {:uri file}
      :context {:includeDeclaration (not (not ?includeDeclaration))}})))

(fn rename [self file line character newName]
  (dispatch.handle* self.server
    (message.create-request (next-id! self) :textDocument/rename
     {:position {: line : character}
      :textDocument {:uri file}
      : newName})))

(set mt.__index
     {: open-file!
      : completion
      : definition
      : hover
      : references
      : rename})

{: create-client
 : ROOT-URI
 : ROOT-PATH}
