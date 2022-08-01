"The actual code
You finally made it. Here is the main code that implements the language server protocol

Every time the client sends a message, it gets handled by a function in the corresponding table type.
(ie, a textDocument/didChange notification will call notifications.textDocument/didChange
 and a textDocument/defintion request will call requests.textDocument/didChange)"
(local fennel (require :fennel))

(local parser  (require :fennel-ls.parser))
(local util    (require :fennel-ls.util))
(local mod     (require :fennel-ls.mod))
(local {: log} (require :fennel-ls.log))
(local state   (require :fennel-ls.state))

(local requests [])
(local notifications [])

(local capabilities
  {:textDocumentSync 1 ;; FIXME: upgrade to 2
   ;; :notebookDocumentSync nil
   ;; :completionProvider nil
   ;; :hoverProvider nil
   ;; :signatureHelpProvider nil
   ;; :declarationProvider nil
   :definitionProvider {:workDoneProgress false}})
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
   ;; :diagnosticProvider {:workDoneProgress false}})
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

(fn string? [j]
  (= (type j) :string))

(local require* (fennel.sym :require))
(local local* (fennel.sym :local))
(λ requests.textDocument/definition [self send {: position :textDocument {: uri}}]
  (local file (state.get-by-uri self uri))

  (set file.ast (or file.ast
                    (parser.from-fennel (. self.files uri))))
  (local ast file.ast)

  (local byte (util.pos->byte file.text position.line position.character))

  (var result nil)
  (λ check [ast]
    (log (fennel.view ast))
    (each [_ item (ipairs ast) :until (or result (parser.past? item byte))]
      (log (fennel.view ast))
      (if (parser.contains? item byte)
        (match item
          (where [require* module &as l]
                 (and (fennel.list? l)
                      (string? module)))
          (set result module)
          (where [local* _ [require* module &as l1] &as l2]
                 (and (fennel.list? l1)
                      (fennel.list? l2)
                      (string? module)))
          (set result module)
          (where obj (fennel.list? obj))
          (check obj)))))

  (check ast)

  (if result
    {:uri (mod.lookup self result)
     :range {:start {:line 0 :character 0}
             :end {:line 0 :character 0}}}))


(λ notifications.textDocument/didChange [self send {: contentChanges :textDocument {: uri}}]
  (local file (state.get-by-uri self uri))
  (assert file.open?)
  (util.apply-changes (. self.files uri) contentChanges))

(λ notifications.textDocument/didOpen [self send {:textDocument {: languageId : text : uri}}]
  (local file (state.set-uri-contents self uri text))
  (set file.open? true))

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

