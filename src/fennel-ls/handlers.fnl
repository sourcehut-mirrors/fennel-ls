"Handlers
You finally made it. Here is the main code that implements the language server protocol

Every time the client sends a message, it gets handled by a function in the corresponding table type.
(ie, a textDocument/didChange notification will call notifications.textDocument/didChange
 and a textDocument/defintion request will call requests.textDocument/didChange)"

(local {: pos->byte : apply-changes}   (require :fennel-ls.utils))
(local message (require :fennel-ls.message))
(local state   (require :fennel-ls.state))
(local language (require :fennel-ls.language))
(local formatter (require :fennel-ls.formatter))

(local {: view} (require :fennel))

(local requests [])
(local notifications [])

(local capabilities
  {:textDocumentSync 1 ;; FIXME: upgrade to 2
   ;; :notebookDocumentSync nil
   ;; :completionProvider nil
   :hoverProvider {:workDoneProgress false}
   ;; :signatureHelpProvider nil
   ;; :declarationProvider nil
   :definitionProvider {:workDoneProgress false}
   ;; :typeDefinitionProvider nil
   ;; :implementationProvider nil
   ;; :referencesProvider nil
   ;; :documentHighlightProvider nil
   ;; :documentSymbolProvider nil
   ;; :codeActionProvider nil
   ;; :codeLensProvider nil
   ;; :documentLinkProvider nil
   ;; :colorProvider nil
   ;; :documentFormattingProvider nil
   ;; :documentRangeFormattingProvider nil
   ;; :documentOnTypeFormattingProvider nil
   ;; :renameProvider nil
   ;; :foldingRangeProvider nil
   ;; :executeCommandProvider nil
   ;; :selectionRangeProvider nil
   ;; :linkedEditingRangeProvider nil
   ;; :callHierarchyProvider nil
   ;; :semanticTokensProvider nil
   ;; :monikerProvider nil
   ;; :typeHierarchyProvider nil
   ;; :inlineValueProvider nil
   ;; :inlayHintProvider nil
   :diagnosticProvider {:workDoneProgress false}})
   ;; :workspaceSymbolProvider nil
   ;; :workspace {:workspaceFolders nil
   ;;             :documentOperations {:didCreate nil
   ;;                              :willCreate nil
   ;;                              :didRename nil
   ;;                              :willRename nil
   ;;                              :didDelete nil
   ;;                              :willDelete nil}})

(λ requests.initialize [self send params]
  (state.init-state self params)
  {:capabilities capabilities
   :serverInfo {:name "fennel-ls" :version "0.0.0"}})

(λ requests.textDocument/definition [self send {: position :textDocument {: uri}}]
  (local file (state.get-by-uri self uri))
  (local byte (pos->byte file.text position.line position.character))
  (match-try (language.find-symbol file.ast byte)
    (symbol parents)
    (match-try
      (let [parent (. parents (length parents))]
        (if (. file.require-calls parent)
          (language.search self file parent [])))
      nil
      (language.search-main self file symbol))
    (result result-file)
    (message.range-and-uri
      (or result.binding result.?definition)
      result-file)
    (catch _ nil)))

(λ requests.textDocument/hover [self send {: position :textDocument {: uri}}]
  (local file (state.get-by-uri self uri))
  (local byte (pos->byte file.text position.line position.character))
  (match-try (language.find-symbol file.ast byte)
    symbol (language.search-main self file symbol)
    result {:contents {:kind "markdown"
                       :value (formatter.hover-format result)}}))

(λ notifications.textDocument/didChange [self send {: contentChanges :textDocument {: uri}}]
  (local file (state.get-by-uri self uri))
  (state.set-uri-contents self uri (apply-changes file.text contentChanges))
  (send (message.diagnostics file)))

(λ notifications.textDocument/didOpen [self send {:textDocument {: languageId : text : uri}}]
  (local file (state.set-uri-contents self uri text))
  (set file.open? true)
  (send (message.diagnostics file)))

(λ notifications.textDocument/didClose [self send {:textDocument {: uri}}]
  (local file (state.get-by-uri self uri))
  (set file.open? false))

(λ requests.shutdown [self send]
  "The server still needs to respond to this request, so the program can't close yet. Wait until notifications.exit"
  nil)

(λ notifications.exit [self]
  (os.exit 0))

{: requests
 : notifications}
