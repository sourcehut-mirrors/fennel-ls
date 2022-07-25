(local requests [])
(local notifications [])

(local capabilities
  {:positionEncoding "utf-8"
   :textDocumentSync nil
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
   :workspaceSymbolProvider nil
   :workspace {:workspaceFolders nil
               :fileOperations {:didCreate nil
                                :willCreate nil
                                :didRename nil
                                :willRename nil
                                :didDelete nil
                                :willDelete nil}}})

(λ requests.initialize [params]
  {:capabilities capabilities
   :serverInfo {:name "fennel-ls" :version "0.0.0"}})

(λ requests.shutdown [])
  ;; no op

(λ notifications.exit []
  (os.exit 0))

(λ handle-request [id method ?params]
  (let [callback (. requests method)
        result {: id :jsonrpc "2.0"}]
    (if callback
      (tset result :result (callback ?params))
      (tset result :error (.. "Unknown message type: " method)))
    result))

(λ handle-response [id result])
  ;; Do nothing

(λ handle-bad-response [id err]
  (error (.. "oopsie: " err.code)))

(λ handle-notification [method ?params]
  (let [callback (. notifications method)]
    (if callback
      (callback ?params))))

(λ handle [msg]
  "The entry point for all messages."
  (assert (= msg.jsonrpc "2.0") "Aha! You forgot to repeat that jsonrpc is version 2.0!")
  (match msg
    {: id : method :params ?params} (handle-request id method ?params)
    {: method :params ?params}      (handle-notification method ?params)
    {: id : result}                 (handle-response id result)
    {: id :error err}               (handle-bad-response id err)
    _ {:id msg.id
       :error "I just received a message that doesn't make sense to me"
       :jsonrpc "2.0"}))

{: handle}
