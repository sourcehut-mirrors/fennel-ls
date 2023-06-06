"Handlers
You finally made it. Here is the main code that implements the language server protocol

Every time the client sends a message, it gets handled by a function in the corresponding table type.
(ie, a textDocument/didChange notification will call notifications.textDocument/didChange
 and a textDocument/defintion request will call requests.textDocument/definition)"

(local {: pos->byte : apply-changes} (require :fennel-ls.utils))
(local diagnostics (require :fennel-ls.diagnostics))
(local message (require :fennel-ls.message))
(local state (require :fennel-ls.state))
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
   :referencesProvider {:workDoneProgress false}
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
        byte (utils.pos->byte file.text position.line position.character)]
    (case-try (language.find-symbol file.ast byte)
      (symbol parents)
      ;; TODO unruin this match-try
      (let [parent (. parents 1)]
        (if (. file.require-calls parent)
          (language.search self file parent [] {:stop-early? true})
          (language.search-main self file symbol {:stop-early? true} byte)))
      (result result-file)
      (message.range-and-uri
        (or result.binding result.definition)
        result-file)
      (catch _ nil))))

(λ requests.textDocument/references [self send {:position {: line : character}
                                                :textDocument {: uri}
                                                :context {:includeDeclaration ?include-declaration?}}]
  (let [file (state.get-by-uri self uri)
        byte (utils.pos->byte file.text line character)]
    (case-try (language.find-symbol file.ast byte)
      symbol
      (if (. file.definitions symbol)
        (values (. file.definitions symbol) file)
        (language.search-main self file symbol {:stop-early? true} byte))
      (definition result-file)
      (let [result
            (icollect [_ symbol (ipairs definition.referenced-by)]
              ;; TODO we currently assume all references are in the same file
              (message.range-and-uri symbol result-file))]
        (if ?include-declaration?
          (table.insert result
                (message.range-and-uri definition.binding result-file)))

        ;; TODO don't include duplicates
        result)
      (catch _ nil))))

(λ requests.textDocument/hover [self send {: position :textDocument {: uri}}]
  (let [file (state.get-by-uri self uri)
        byte (utils.pos->byte file.text position.line position.character)]
    (case-try (language.find-symbol file.ast byte)
      symbol (language.search-main self file symbol {} byte)
      result {:contents (formatter.hover-format result)
              :range (message.ast->range symbol file)}
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

;; CompletionItemKind
(local kinds
 {:Text 1 :Method 2 :Function 3 :Constructor 4 :Field 5 :Variable 6 :Class 7
  :Interface 8 :Module 9 :Property 10 :Unit 11 :Value 12 :Enum 13 :Keyword 14
  :Snippet 15 :Color 16 :File 17 :Reference 18 :Folder 19 :EnumMember 20
  :Constant 21 :Struct 22 :Event 23 :Operator 24 :TypeParameter 25})

(λ make-completion-item [self file name scope]
  ;; TODO consider passing stop-early?
  (case (language.search-name-and-scope self file name scope)
    def (formatter.completion-item-format name def)))

(λ scope-completion [self file byte ?symbol parents]
  (let [scope (or (accumulate [result nil
                               _ parent (ipairs parents)
                               &until result]
                    (. file.scopes parent))
                  file.scope)
        ?parent (. parents 1)
        result []
        in-call-position? (and ?parent (= ?symbol (. ?parent 1)))]
    (collect-scope scope :manglings #(make-completion-item self file $ scope) result)
    (when in-call-position?
      (collect-scope scope :macros #{:label $ :kind kinds.Keyword} result)
      (collect-scope scope :specials #(make-completion-item self file $ scope) result))
    (icollect [_ k (ipairs file.allowed-globals) &into result]
      (make-completion-item self file k scope))))

(λ field-completion [self file symbol split]
  (case (. file.references symbol)
    ref
    (let [stack (fcollect [i (- (length split) 1) 2 -1]
                  (. split i))]
      (case (language.search-assignment self file ref stack {})
        {: definition}
        (case (values definition (type definition))
          (_str :string) (icollect [k _ (pairs string)]
                           {:label k :kind kinds.Field})
          (tbl :table) (icollect [k _ (pairs tbl)]
                         (if (= (type k) :string)
                           {:label k :kind kinds.Field})))
        _ nil))))

(λ create-completion-item [self file name scope]
  (let [result (language.search-name-and-scope self file name scope)]
    {:label result.label :kind result.kind}))

(λ requests.textDocument/completion [self send {: position :textDocument {: uri}}]
  (let [file (state.get-by-uri self uri)
        byte (utils.pos->byte file.text position.line position.character)
        (?symbol parents) (language.find-symbol file.ast byte)]
    (case (-?> ?symbol utils.multi-sym-split)
      (where (or nil [_ nil])) (scope-completion self file byte ?symbol parents)
      [_a _b &as split] (field-completion self file ?symbol split))))


(λ notifications.textDocument/didChange [self send {: contentChanges :textDocument {: uri}}]
  (local file (state.get-by-uri self uri))
  (state.set-uri-contents self uri (utils.apply-changes file.text contentChanges))
  (diagnostics.check self file)
  (send (message.diagnostics file)))

(λ notifications.textDocument/didOpen [self send {:textDocument {: languageId : text : uri}}]
  (local file (state.set-uri-contents self uri text))
  (diagnostics.check self file)
  (send (message.diagnostics file))
  (set file.open? true))

(λ notifications.textDocument/didClose [self send {:textDocument {: uri}}]
  (local file (state.get-by-uri self uri))
  (set file.open? false)
  ;; TODO only reload from disk if we didn't get a didSave, instead of always
  (state.flush-uri self uri))

(λ notifications.workspace/didChangeConfiguration [self send {: settings}]
  (state.write-configuration self settings.fennel-ls))

(λ requests.shutdown [self send]
  "The server still needs to respond to this request, so the program can't close yet. Just wait until notifications.exit"
  nil)

(λ notifications.exit [self]
  "This is the real shutdown request, we can quit now"
  (os.exit 0))

{: requests
 : notifications}
