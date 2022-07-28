(local fennel (require :fennel))
(local {: make-error-message} (require :fls.error))

(local requests [])
(local notifications [])

(local capabilities
  {:textDocumentSync 2
   :notebookDocumentSync nil
   :completionProvider nil
   :hoverProvider nil
   :signatureHelpProvider nil
   :declarationProvider nil
   :definitionProvider nil
   :typeDefinitionProvider nil
   :implementationProvider nil
   :referencesProvider nil
   :documentHighlightProvider nil
   :documentSymbolProvider nil
   :codeActionProvider nil
   :codeLensProvider nil
   :documentLinkProvider nil
   :colorProvider nil
   :documentFormattingProvider nil
   :documentRangeFormattingProvider nil
   :documentOnTypeFormattingProvider nil
   :renameProvider nil
   :foldingRangeProvider nil
   :executeCommandProvider nil
   :selectionRangeProvider nil
   :linkedEditingRangeProvider nil
   :callHierarchyProvider nil
   :semanticTokensProvider nil
   :monikerProvider nil
   :typeHierarchyProvider nil
   :inlineValueProvider nil
   :inlayHintProvider nil
   :diagnosticProvider nil
   :workspaceSymbolProvider nil})
;   :workspace {:workspaceFolders nil
;               :fileOperations {:didCreate nil
;                                :willCreate nil
;                                :didRename nil
;                                :willRename nil
;                                :didDelete nil
;                                :willDelete nil})

(λ requests.initialize [self params]
  {:capabilities capabilities
   :serverInfo {:name "fennel-ls" :version "0.0.0"}})

(λ requests.shutdown [self])
  ;; Okay, I'll wait for the exit notification to actaully exit

(λ notifications.exit [self]
  (os.exit 0))

(λ run-request [self id method ?params]
  (match (. requests method)
    callback {:jsonrpc "2.0"
              : id
              :result (callback self ?params)}
    nil (make-error-message
          :MethodNotFound
          (.. "\"" method "\" is not in the requests table")
          id)))

(λ run-response [self id result])
  ;; I don't care about responses yet

(λ run-bad-response [self id err]
  (error (.. "oopsie: " err.code)))

(λ run-notification [self method ?params]
  (match (. notifications method)
    callback (callback self ?params)
    nil nil)) ;; Silent error for unknown notifications

(λ run [self msg]
  "The entry point for all messages."
  (match (values msg (type msg))
    {:jsonrpc "2.0" : id : method :params ?params} (run-request      self id method ?params)
    {:jsonrpc "2.0" : method :params ?params}      (run-notification self method ?params)
    {:jsonrpc "2.0" : id : result}                 (run-response     self id result)
    {:jsonrpc "2.0" : id :error err}               (run-bad-response self id err)
    (str :string)                                  (make-error-message :ParseError str)
    _                                              (make-error-message :BadMessage nil msg.id)))

{: run}
