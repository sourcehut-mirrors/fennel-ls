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

(fn did-change-configuration [self settings]
  (dispatch.handle* self.server
    (message.create-notification :workspace/didChangeConfiguration
      {: settings})))

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

(local client-mt
  {:__index {: open-file!
             : pretend-this-file-exists!
             : did-change-configuration
             : completion
             : definition
             : hover
             : references
             : rename
             : code-action}})

{: client-mt
 : default-encoding
 : ROOT-URI
 : ROOT-PATH}
