"Handlers
You finally made it. Here is the main code that implements the language server protocol

Every time the client sends a message, it gets handled by a function in the corresponding table type.
(ie, a textDocument/didChange notification will call notifications.textDocument/didChange
 and a textDocument/defintion request will call requests.textDocument/definition)"

(local {: pos->byte : apply-changes}   (require :fennel-ls.utils))
(local message (require :fennel-ls.message))
(local state   (require :fennel-ls.state))
(local language (require :fennel-ls.language))
(local formatter (require :fennel-ls.formatter))
(local utils (require :fennel-ls.utils))

(local {: view} (require :fennel))

(local requests [])
(local notifications [])

(local capabilities
  {:textDocumentSync 1 ;; FIXME: upgrade to 2
   ;; :notebookDocumentSync nil
   :completionProvider {:workDoneProgress false} ;; TODO
   :hoverProvider {:workDoneProgress false
                   :resolveProvider false
                   :triggerCharacters ["(" "[" "{" "." ":" "\""]
                   :completionItem {:labelDetailsSupport false}}
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
   ;;                                  :willCreate nil
   ;;                                  :didRename nil
   ;;                                  :willRename nil
   ;;                                  :didDelete nil
   ;;                                  :willDelete nil}})

(λ requests.initialize [self send params]
  (state.init-state self params)
  {:capabilities capabilities
   :serverInfo {:name "fennel-ls" :version "0.0.0"}})

(λ requests.textDocument/definition [self send {: position :textDocument {: uri}}]
  (let [file (state.get-by-uri self uri)
        byte (pos->byte file.text position.line position.character)]
    (match-try (language.find-symbol file.ast byte)
      (symbol parents)
      (match-try
        (let [parent (. parents 1)]
          (if (. file.require-calls parent)
            (language.search self file parent [] {:stop-early? true})))
        nil
        (language.search-main self file symbol {:stop-early? true} byte))
      (result result-file)
      (message.range-and-uri
        (or result.binding result.definition)
        result-file)
      (catch _ nil))))

(λ requests.textDocument/hover [self send {: position :textDocument {: uri}}]
  (let [file (state.get-by-uri self uri)
        byte (pos->byte file.text position.line position.character)]
    (match-try (language.find-symbol file.ast byte)
      symbol (language.search-main self file symbol {} byte)
      result {:contents {:kind "markdown"
                         :value (formatter.hover-format result)}}
      (catch _ nil))))


;; All of the helper functions for textDocument/completion are here until I
;; finish refactoring them, and then they can find a home in language.fnl
(λ collect-scope [scope typ callback ?target]
  (let [result (or ?target [])]
    (var scope scope)
    (while scope
      (icollect [i v (pairs (. scope typ)) &into result]
        (callback i v))
      (set scope scope.parent))
    result))

(λ find-things-in-scope [file parents typ callback ?target]
  (let [scope (or (accumulate [result nil
                               i parent (ipairs parents)
                               &until result]
                    (. file.scopes parent))
                  file.scope)]
    (collect-scope scope typ callback ?target)))

(λ scope-completion [file byte ?symbol parents]
    (let [result []]
      (find-things-in-scope file parents :manglings #{:label $} result)
      (find-things-in-scope file parents :macros #{:label $} result)
      (find-things-in-scope file parents :specials #{:label $} result)
      (icollect [_ k (ipairs file.allowed-globals) &into result]
        {:label k})))

(λ field-completion [self file symbol split]
  (match (. file.references symbol)
    ref
    (let [stack (fcollect [i (- (length split) 1) 2 -1]
                  (. split i))]
      (match-try (language.search-assignment self file ref stack {})
        {: definition}
        (match (values definition (type definition))
          (str :string) (icollect [k v (pairs string)]
                          {:label k})
          (tbl :table) (icollect [k v (pairs tbl)]
                         (if (= (type k) :string)
                           {:label k})))
        (catch _ nil)))))

(λ requests.textDocument/completion [self send {: position :textDocument {: uri}}]
  (let [file (state.get-by-uri self uri)
        byte (pos->byte file.text position.line position.character)
        (?symbol parents) (language.find-symbol file.ast byte)]
    (match (-?> ?symbol utils.multi-sym-split)
      (where (or nil [_ nil])) (scope-completion file byte ?symbol parents)
      [a b &as split] (field-completion self file ?symbol split))))

(λ notifications.textDocument/didChange [self send {: contentChanges :textDocument {: uri}}]
  (local file (state.get-by-uri self uri))
  (state.set-uri-contents self uri (apply-changes file.text contentChanges))
  (send (message.diagnostics file)))

(λ notifications.textDocument/didOpen [self send {:textDocument {: languageId : text : uri}}]
  (local file (state.set-uri-contents self uri text))
  (set file.open? true)
  (send (message.diagnostics file)))

(λ notifications.textDocument/didClose [self send {:textDocument {: uri}}]
  ;; TODO reload from disk if we didn't get a didSave
  (local file (state.get-by-uri self uri))
  (set file.open? false))

(λ notifications.workspace/didChangeConfiguration [self send params]
  (set self.settings params.fennel-ls))
  ;; TODO respect the settings

(λ requests.shutdown [self send]
  "The server still needs to respond to this request, so the program can't close yet. Just wait until notifications.exit"
  nil)

(λ notifications.exit [self]
  (os.exit 0))

{: requests
 : notifications}
