(local dispatch (require :fennel-ls.dispatch))
(local message (require :fennel-ls.message))

(local ROOT-PATH "/path/to/test/project")

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

(fn did-save [self file]
  (dispatch.handle* self.server
    (message.create-notification :textDocument/didSave
     {:textDocument {:uri file}})))


(local client-mt
  {:__index {: open-file!
             : pretend-this-file-exists!
             : completion
             : definition
             : hover
             : references
             : rename
             : code-action
             : did-save}})

{: client-mt
 : default-encoding
 : ROOT-URI
 : ROOT-PATH}
