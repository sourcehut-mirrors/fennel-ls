(local dispatch (require :fennel-ls.dispatch))
(local message (require :fennel-ls.message))

(local ROOT-PATH
  (-> (io.popen "pwd")
      (: :read :*a)
      (: :sub 1 -2) ;; take off newline
      (.. "/test/test-project")))

(local ROOT-URI
  (.. "file://" ROOT-PATH))

(local default-encoding :utf-8)

(local mt {})
(fn create-client [?opts ?provide-root-uri]
  (let [server []
        params (or (?. ?opts :params)
                   {:capabilities {:general {:positionEncodings [default-encoding]}}
                    :clientInfo {:name "Neovim" :version "0.7.2"}
                    :initializationOptions {}
                    :processId 16245
                    :rootPath (if ?provide-root-uri ROOT-PATH)
                    :rootUri (if ?provide-root-uri ROOT-URI)
                    :trace "off"
                    :workspaceFolders (if ?provide-root-uri
                                        [{:name ROOT-PATH
                                          :uri ROOT-URI}])})
        initialize {:id 1
                    :jsonrpc "2.0"
                    :method "initialize"
                    : params}
        initialize-response (dispatch.handle* server initialize)
        client (doto {: server :prev-id 1} (setmetatable mt))]
    (case (?. ?opts :settings)
      settings
      (dispatch.handle* server
        {:jsonrpc "2.0"
         :method :workspace/didChangeConfiguration
         :params {: settings}}))
    (values client server initialize-response)))

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

(fn pretend-this-file-exists! [self name text]
  (tset self.server.preload name text))

(fn completion [self file position]
  (dispatch.handle* self.server
    (message.create-request (next-id! self) :textDocument/completion
     {: position
      :textDocument {:uri file}})))

(fn definition [self file position]
  (dispatch.handle* self.server
    (message.create-request (next-id! self) :textDocument/definition
      {: position
       :textDocument {:uri file}})))

(fn hover [self file position]
  (dispatch.handle* self.server
     (message.create-request (next-id! self) :textDocument/hover
       {: position
        :textDocument {:uri file}})))

(fn references [self file position ?includeDeclaration]
  (dispatch.handle* self.server
    (message.create-request (next-id! self) :textDocument/references
     {: position
      :textDocument {:uri file}
      :context {:includeDeclaration (not (not ?includeDeclaration))}})))

(fn rename [self file position newName]
  (dispatch.handle* self.server
    (message.create-request (next-id! self) :textDocument/rename
     {: position
      :textDocument {:uri file}
      : newName})))

(fn code-action [self file range]
  (dispatch.handle* self.server
    (message.create-request (next-id! self) :textDocument/codeAction
     {: range
      :textDocument {:uri file}
      :context {:diagnostics []}})))

(set mt.__index
     {: open-file!
      : pretend-this-file-exists!
      : completion
      : definition
      : hover
      : references
      : rename
      : code-action})

{: create-client
 : default-encoding
 : ROOT-URI
 : ROOT-PATH}
