"The actual code
You finally made it. Here is the main code that implements the language server protocol

Every time the client sends a message, it gets handled by a function in the corresponding table type.
(ie, a textDocument/didChange notification will call notifications.textDocument/didChange
 and a textDocument/defintion request will call requests.textDocument/didChange)"
(local fennel (require :fennel))
(local sym? fennel.sym?)
(local list? fennel.list?)
(local fennelutils (require :fennel.utils))

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

;; These three functions are mutually recursive
(var
  (search-assignment
   search-symbol
   search)
  nil)

(set search-assignment
  (λ search-assignment [self file binding ?definition stack]
    (if (= 0 (length stack))
      binding
      ;; TODO sift down the binding
      (search self file ?definition stack))))

(set search-symbol
  (λ search-symbol [self file symbol stack]
    (let [split (util.multi-sym-split symbol)]
      (for [i (length split) 2 -1]
        (table.insert stack (. split i))))
    (match (. file.references symbol)
      to (search-assignment self file to.binding to.definition stack)
      nil nil)))

(set search
  (λ search [self file item stack]
    (if (fennelutils.table? item)
        (if (. item (. stack (length stack)))
          (search self file (. item (table.remove stack)) stack)
          nil)
        (sym? item)
        (search-symbol self file item stack)
        ;; TODO
        ;; functioncall (continue searching in body)
        ;; require call (search in the new module)
        :else (error (.. "I don't know what to do with " (fennel.view item))))))

(λ find-symbol [ast byte ?recursively-called]
  (if (not= :table (type ast))
      nil
      (parser.does-not-contain? ast byte)
      nil
      (sym? ast)
      ast
      (or (not ?recursively-called)
          (fennel.list? ast)
          (fennel.sequence? ast))
      ;; TODO binary search
      (accumulate
        [result nil
         _ v (ipairs ast)
         &until (or result (parser.past? v byte))]
        (find-symbol v byte true))
      :else
      (accumulate
        [result nil
         k v (pairs ast)
         &until result]
        (or
          (find-symbol k byte true)
          (find-symbol v byte true)))))

(λ requests.textDocument/definition [self send {: position :textDocument {: uri}}]
  (local file (state.get-by-uri self uri))
  (local byte (util.pos->byte file.text position.line position.character))
  (match (find-symbol file.ast byte)
    symbol
    (match (search-symbol self file symbol [])
      definition
      {:range (parser.range file.text definition)
       :uri uri})))

(λ notifications.textDocument/didChange [self send {: contentChanges :textDocument {: uri}}]
  (local file (state.get-by-uri self uri))
  (assert file.open?)
  (util.apply-changes (. self.files uri) contentChanges))

(λ notifications.textDocument/didOpen [self send {:textDocument {: languageId : text : uri}}]
  (local file (state.set-uri-contents self uri text))
  (set file.open? true))

(λ notifications.textDocument/didClose [self send {:textDocument {: uri}}]
  ;; TODO fix
  (local file (state.get-by-uri self uri))
  (set file.open? false))

(λ requests.shutdown [self send]
  "The server still needs to respond to this request, so the program can't close yet. Wait until notifications.exit"
  nil)

(λ notifications.exit [self]
  (os.exit 0))

{: requests
 : notifications}
