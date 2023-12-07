"Handlers
You finally made it. Here is the main code that implements the language server protocol

Every time the client sends a message, it gets handled by a function in the corresponding table type.
(ie, a textDocument/didChange notification will call notifications.textDocument/didChange
 and a textDocument/defintion request will call requests.textDocument/definition)"

(local diagnostics (require :fennel-ls.diagnostics))
(local message (require :fennel-ls.message))
(local state (require :fennel-ls.state))
(local language (require :fennel-ls.language))
(local formatter (require :fennel-ls.formatter))
(local utils (require :fennel-ls.utils))

(local requests [])
(local notifications [])

(local capabilities
  {:textDocumentSync {:openClose true :change 2}
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
   :renameProvider {:workDoneProgress false}})
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
   ;; ;; this is for PULL diagnostics, but fennel-ls currently does PUSH diagnostics
   ;; :diagnosticProvider {:workDoneProgress false}})
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
   :positionEncoding self.position-encoding
   :serverInfo {:name "fennel-ls" :version "0.1.0"}})

(λ requests.textDocument/definition [self send {: position :textDocument {: uri}}]
  (let [file (state.get-by-uri self uri)
        byte (utils.position->byte file.text position self.position-encoding)]
    (case-try (language.find-symbol file.ast byte)
      (symbol [parent])
      (if
        ;; require call
        (. file.require-calls parent)
        (language.search self file parent [] {:stop-early? true})
        ;; regular symbol
        (language.search-main self file symbol {:stop-early? true} byte))
      (result result-file)
      (message.range-and-uri self result-file (or result.binding result.definition))
      (catch _ nil))))

(λ requests.textDocument/references [self send {: position
                                                :textDocument {: uri}
                                                :context {:includeDeclaration ?include-declaration?}}]
  (let [file (state.get-by-uri self uri)
        byte (utils.position->byte file.text position self.position-encoding)]
    (case-try (language.find-symbol file.ast byte)
      symbol
      (language.find-nearest-definition self file symbol byte)
      (where (definition def-file) (not= definition.referenced-by nil))
      (let [result (icollect [_ symbol (ipairs definition.referenced-by)]
                     (message.range-and-uri self def-file symbol))]
        (if ?include-declaration?
          (table.insert result
            (message.range-and-uri self def-file definition.binding)))

        ;; TODO don't include duplicates
        result)
      (catch _ nil))))

(λ requests.textDocument/hover [self send {: position :textDocument {: uri}}]
  (let [file (state.get-by-uri self uri)
        byte (utils.position->byte file.text position self.position-encoding)]
    (case-try (language.find-symbol file.ast byte)
      symbol (language.search-main self file symbol {} byte)
      result {:contents (formatter.hover-format result)
              :range (message.ast->range self file symbol)}
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
    def (formatter.completion-item-format name def)
    _ {:label name}))

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
      (collect-scope scope :macros #(doto (make-completion-item self file $ scope) (tset :kind kinds.Keyword)) result)
      (collect-scope scope :specials #(doto (make-completion-item self file $ scope) (tset :kind kinds.Operator)) result))
    (icollect [_ k (ipairs file.allowed-globals) &into result]
      (make-completion-item self file k scope))))

(λ field-completion [self file symbol split]
  (case (. file.references symbol)
    ref
    (let [stack (fcollect [i (- (length split) 1) 2 -1]
                  (. split i))]
      (case (language.search-assignment self file ref stack {})
        ({: definition} file)
        (case (values definition (type definition))
          (_str :string) (icollect [label _ (pairs string)]
                           {: label :kind kinds.Field})
          (tbl :table) (icollect [label _ (pairs tbl)]
                         (if (= (type label) :string)
                           (case (language.search self file tbl [label] {})
                             def (formatter.completion-item-format label def)
                             _ {: label :kind kinds.Field}))))
        _ nil))))

(λ _create-completion-item [self file name scope]
  (let [result (language.search-name-and-scope self file name scope)]
    {:label result.label :kind result.kind}))

(λ requests.textDocument/completion [self send {: position :textDocument {: uri}}]
  (let [file (state.get-by-uri self uri)
        byte (utils.position->byte file.text position self.position-encoding)
        (?symbol parents) (language.find-symbol file.ast byte)]
    (case (-?> ?symbol utils.multi-sym-split)
      (where (or nil [_ nil])) (scope-completion self file byte ?symbol parents)
      [_a _b &as split] (field-completion self file ?symbol split))))

(λ requests.textDocument/rename [self send {: position :textDocument {: uri} :newName new-name}]
  (let [file (state.get-by-uri self uri)
        byte (utils.position->byte file.text position self.position-encoding)]
    (case-try (language.find-symbol file.ast byte)
      symbol
      (language.find-nearest-definition self file symbol symbol.bytestart)
      ;; TODO we are assuming that every reference is in the same file
      (where (definition def-file) (not= definition.referenced-by nil))
      (let [usages (icollect [_ symbol (ipairs definition.referenced-by)
                              &into [{:range (message.multisym->range self def-file definition.binding 1)
                                      :newText new-name}]]
                     (if (not (rawequal symbol definition.binding))
                       {:newText new-name
                        :range (message.multisym->range self def-file symbol 1)}))]

        ;; NOTE: I don't care about encoding here because we just need the relative positions
        (table.sort usages
          #(> (utils.position->byte def-file.text $1.range.start :utf-8)
              (utils.position->byte def-file.text $2.range.start :utf-8)))
        {:changes {def-file.uri usages}})
      (catch _ nil))))

(λ notifications.textDocument/didChange [self send {: contentChanges :textDocument {: uri}}]
  (local file (state.get-by-uri self uri))
  (state.set-uri-contents self uri (utils.apply-changes file.text contentChanges self.position-encoding))
  (diagnostics.check self file)
  (send (message.diagnostics file)))

(λ notifications.textDocument/didOpen [self send {:textDocument {: languageId : text : uri}}]
  (local file (state.set-uri-contents self uri text))
  (diagnostics.check self file)
  (send (message.diagnostics file))
  (set file.open? true))

(λ notifications.textDocument/didSave [self send {:textDocument {: uri}}]
  ;; TODO be careful about which modules need to be recomputed, and also eagerly flush existing files
  (tset (require :fennel) :macro-loaded []))

(λ notifications.textDocument/didClose [self send {:textDocument {: uri}}]
  (local file (state.get-by-uri self uri))
  (set file.open? false)
  (tset (require :fennel) :macro-loaded [])
  ;; TODO only reload from disk if we didn't get a didSave, instead of always
  (state.flush-uri self uri))

(λ notifications.workspace/didChangeConfiguration [self send {: settings}]
  (state.write-configuration self (?. settings :fennel-ls)))

(λ requests.shutdown [self send]
  "The server still needs to respond to this request, so the program can't close yet. Just wait until notifications.exit"
  nil)

(λ notifications.exit [self]
  "This is the real shutdown request, we can quit now"
  (os.exit 0))

{: requests
 : notifications}
