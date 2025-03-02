"Handlers
You finally made it. Here is the main code that implements the language server protocol

Every time the client sends a message, it gets handled by a function in the corresponding table type.
(ie, a textDocument/didChange notification will call notifications.textDocument/didChange
 and a textDocument/defintion request will call requests.textDocument/definition)"

(local lint      (require :fennel-ls.lint))
(local message   (require :fennel-ls.message))
(local files     (require :fennel-ls.files))
(local config    (require :fennel-ls.config))
(local analyzer  (require :fennel-ls.analyzer))
(local formatter (require :fennel-ls.formatter))
(local utils     (require :fennel-ls.utils))
(local docs      (require :fennel-ls.docs))
(local fennel    (require :fennel))

(local requests [])
(local notifications [])

(fn validate-config [server]
  (set server.queue (or server.queue []))
  ;; according to the spec it is valid to send showMessage during initialization
  ;; but eglot will only flash the message briefly before replacing it with
  ;; another message, and probably other clients will do similarly. so queue
  ;; up the warnings to send *after* the initialization is complete. cheesy, eh?
  (config.validate server #(table.insert server.queue
                                         (message.show-message
                                          $ (or $2 :ERROR)))))

(λ requests.initialize [server _send params]
  (config.initialize server params)
  (validate-config server)
  (let [capabilities
        {:positionEncoding server.position-encoding
         :textDocumentSync {:openClose true :change 2}
         ;; :notebookDocumentSync nil
         :completionProvider {:workDoneProgress false
                              :resolveProvider false
                              :triggerCharacters ["(" "[" "{" "." ":" "\""]
                              :completionItem {:labelDetailsSupport false}}
         :hoverProvider {:workDoneProgress false}
         ;; :signatureHelpProvider nil
         ;; :declarationProvider nil
         :definitionProvider {:workDoneProgress false}
         ;; :typeDefinitionProvider nil
         ;; :implementationProvider nil
         :referencesProvider {:workDoneProgress false}
         :documentHighlightProvider {:workDoneProgress false}
         ;; :documentSymbolProvider nil
         :codeActionProvider {:workDoneProgress false}
         ;; :codeLensProvider nil
         ;; :documentLinkProvider nil
         ;; :colorProvider nil
         ;; :documentFormattingProvider {:workDoneProgress false}
         ;; :documentRangeFormattingProvider nil
         ;; :documentOnTypeFormattingProvider nil
         :renameProvider {:workDoneProgress false}}]
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
         ;;             :fileOperations {:didCreate nil
         ;;                              :willCreate nil
         ;;                              :didRename nil
         ;;                              :willRename nil
         ;;                              :didDelete nil
         ;;                              :willDelete nil}}
         ;; :experimental nil)
    {: capabilities
     :serverInfo {:name "fennel-ls" :version "0.1.0"}}))

(λ requests.textDocument/definition [server _send {: position :textDocument {: uri}}]
  (let [file (files.get-by-uri server uri)
        byte (utils.position->byte file.text position server.position-encoding)]
    (case-try (analyzer.find-symbol file.ast byte)
      (symbol [parent])
      (if
        ;; require call
        (. file.require-calls parent)
        (analyzer.search-ast server file parent [] {:stop-early? true})
        ;; regular symbol
        (analyzer.search-main server file symbol {:stop-early? true} {: byte}))
      result
      (if result.file
        (message.range-and-uri server result.file (or result.binding result.definition)))
      (catch _ nil))))

;; DocumentHighlightKind
(local documentHighlightKind {:Text 1 :Read 2 :Write 3})

(λ requests.textDocument/documentHighlight [server _send {: position
                                                          :textDocument {: uri}}]
  (let [this-file (files.get-by-uri server uri)
        byte (utils.position->byte this-file.text position server.position-encoding)]
    (match-try (analyzer.find-symbol this-file.ast byte)
      symbol
      (analyzer.find-nearest-definition server this-file symbol byte)
      {: referenced-by :file {:uri this-file.uri &as file} : binding}
      (let [result (icollect [_ {:symbol reference} (ipairs referenced-by)]
                     {:range (message.ast->range server file reference)
                      :kind documentHighlightKind.Read})]
        (table.insert result {:range (message.ast->range server file binding)
                              :kind documentHighlightKind.Write})
        result)
      (catch _ nil))))

(λ requests.textDocument/references [server _send {: position
                                                   :textDocument {: uri}
                                                   :context {:includeDeclaration
                                                             include-declaration?}}]
  (let [file (files.get-by-uri server uri)
        byte (utils.position->byte file.text position server.position-encoding)]
    (case-try (analyzer.find-symbol file.ast byte)
      symbol
      (analyzer.find-nearest-definition server file symbol byte)
      {: referenced-by : file : binding}
      (let [result (icollect [_ {: symbol} (ipairs referenced-by)]
                     (message.range-and-uri server file symbol))]
        (when include-declaration?
          (table.insert result
            (message.range-and-uri server file binding)))

        ;; TODO don't include duplicates
        result)
      (catch _ nil))))

(λ requests.textDocument/hover [server _send {: position :textDocument {: uri}}]
  (let [file (files.get-by-uri server uri)
        byte (utils.position->byte file.text position server.position-encoding)]
    (case-try (analyzer.find-symbol file.ast byte)
      symbol (analyzer.search-main server file symbol {} {: byte})
      result {:contents (formatter.hover-format result)
              :range (message.ast->range server file symbol)}
      (catch _ nil))))

(λ make-completion-item [server file name scope]
  (case (analyzer.search-name-and-scope server file name scope)
    def (formatter.completion-item-format name def)
    _ {:label name}))

;; All of the helper functions for textDocument/completion are here until I
;; finish refactoring them, and then they can find a home in analyzer.fnl
(λ collect-scope [scope typ server file ?target ?default-kind]
  (let [result (or ?target [])]
    (var scope scope)
    (while scope
      (icollect [name (pairs (. scope typ)) &into result]
        (let [item (make-completion-item server file name scope)]
          (when (= nil item.kind)
            (set item.kind ?default-kind))
          item))
      (set scope scope.parent))
    result))

;; CompletionItemKind
(local kinds
 {:Text 1 :Method 2 :Function 3 :Constructor 4 :Field 5 :Variable 6 :Class 7
  :Interface 8 :Module 9 :Property 10 :Unit 11 :Value 12 :Enum 13 :Keyword 14
  :Snippet 15 :Color 16 :File 17 :Reference 18 :Folder 19 :EnumMember 20
  :Constant 21 :Struct 22 :Event 23 :Operator 24 :TypeParameter 25})

(λ scope-completion [server file _byte ?symbol parents]
  (let [scope (or (accumulate [result nil
                               _ parent (ipairs parents)
                               &until result]
                    (. file.scopes parent))
                  file.scope)
        ?parent (. parents 1)
        result []
        in-call-position? (and (fennel.list? ?parent)
                               (= ?symbol (. ?parent 1)))]
    (collect-scope scope :manglings server file result kinds.Variable)

    (when in-call-position?
      (collect-scope scope :macros server file result kinds.Keyword)
      (collect-scope scope :specials server file result kinds.Operator))
    (icollect [_ k (ipairs file.allowed-globals) &into result]
      (make-completion-item server file k scope))))

(λ field-completion [server file symbol split]
  (let [stack (fcollect [i (- (length split) 1) 2 -1]
                (. split i))
        last-found-binding []
        result (analyzer.search-main server file symbol {:save-last-binding last-found-binding} {: stack})]
    (case result
      {: definition : file}
      (case (values definition (type definition))
        ;; fields of a string are hardcoded to "string"
        (_str :string) (icollect [label info (pairs (. (docs.get-global server :string) :fields))]
                         (formatter.completion-item-format label info))
        ;; fields of a table
        (tbl :table) (let [keys []]
                       (icollect [label _ (pairs tbl) &into keys]
                         label)
                       (when (?. last-found-binding 1 :fields)
                         (icollect [label _ (pairs (. last-found-binding 1 :fields)) &into keys]
                           label))
                       (icollect [_ label (pairs keys)]
                         (if (= (type label) :string)
                           (case (analyzer.search-ast server file tbl [label] {})
                             def (formatter.completion-item-format label def)
                             _ {: label :kind kinds.Field})))))
      {: metadata : fields}
      (let [_metadata metadata]
        (icollect [label info (pairs fields)]
          (formatter.completion-item-format label info)))
      _ nil)))

(λ requests.textDocument/completion [server _send {: position :textDocument {: uri}}]
  (let [file (files.get-by-uri server uri)
        byte (utils.position->byte file.text position server.position-encoding)
        (?symbol parents) (analyzer.find-symbol file.ast byte)]
    (case (-?> ?symbol utils.multi-sym-split)

      ;; completion from current scope
      (where (or nil [_ nil]))
      (let [input-range (if ?symbol (message.multisym->range server file ?symbol -1) {:start position :end position})
            ?completions (scope-completion server file byte ?symbol parents)]
        (if ?completions
          (let [?completions (utils.uniq-by ?completions #$.label)]
            (each [_ completion (ipairs ?completions)]
              (set completion.textEdit {:newText completion.label :range input-range}))
            ?completions)))

      ;; completion from field
      [_a _b &as split]
      (let [input-range (message.multisym->range server file ?symbol -1)
            ?completions (field-completion server file ?symbol split)]
        (if ?completions
          (if server.EGLOT_COMPLETION_QUIRK_MODE
            (let [prefix (string.gsub (tostring ?symbol) "[^.:]*$" "")]
              (each [_ completion (ipairs ?completions)]
                (set completion.filterText (.. prefix completion.label))
                (set completion.insertText (.. prefix completion.label))))
            (each [_ completion (ipairs ?completions)]
              (set completion.textEdit {:newText completion.label :range input-range}))))
        ?completions))))



(λ requests.textDocument/rename [server _send {: position :textDocument {: uri} :newName new-name}]
  (let [file (files.get-by-uri server uri)
        byte (utils.position->byte file.text position server.position-encoding)]
    (case-try (analyzer.find-symbol file.ast byte)
      symbol
      (analyzer.find-nearest-definition server file symbol symbol.bytestart)
      ;; TODO we are assuming that every reference is in the same file
      {: referenced-by : file : binding}
      (let [usages (icollect [_ {: symbol} (ipairs referenced-by)
                              &into [{:range (message.multisym->range
                                              server file binding 1)
                                      :newText new-name}]]
                     (if (and (. file.lexical symbol)
                              (not (rawequal symbol binding)))
                       {:newText new-name
                        :range (message.multisym->range server file symbol 1)}))]

        ;; NOTE: I don't care about encoding here because we just need the relative positions
        (table.sort usages
          #(> (utils.position->byte file.text $1.range.start :utf-8)
              (utils.position->byte file.text $2.range.start :utf-8)))
        (var prev {})
        (let [usages-dedup (icollect [_ edit (ipairs usages)]
                             (when (or (not= edit.range.start.line prev.line)
                                       (not= edit.range.start.character prev.character))
                               (set prev edit.range.start)
                               edit))]
          {:changes {file.uri usages-dedup}}))
      (catch _ nil))))

(fn pos<= [pos-1 pos-2]
  (or (< pos-1.line pos-2.line)
      (and (= pos-1.line pos-2.line)
           (<= pos-1.character pos-2.character))))

(fn overlap? [range-1 range-2]
  (and (pos<= range-1.start range-2.end)
       (pos<= range-2.start range-1.end)))

(λ requests.textDocument/codeAction [server _send {: range :textDocument {: uri}}]
  (let [file (files.get-by-uri server uri)]
    (icollect [_ diagnostic (ipairs file.diagnostics)]
      (if (and (overlap? diagnostic.range range)
               diagnostic.quickfix)
        {:title diagnostic.codeDescription
         :edit {:changes {uri (diagnostic.quickfix)}}}))))

(λ notifications.textDocument/didChange [server send {: contentChanges :textDocument {: uri}}]
  (local file (files.get-by-uri server uri))
  (files.set-uri-contents server uri (utils.apply-changes file.text contentChanges server.position-encoding))
  (lint.add-lint-diagnostics server file)
  (send (message.diagnostics file)))

(λ notifications.textDocument/didOpen [server send {:textDocument {: text : uri}}]
  (local file (files.set-uri-contents server uri text))
  (lint.add-lint-diagnostics server file)
  (send (message.diagnostics file))
  (set file.open? true))

(λ notifications.textDocument/didSave [server _send {:textDocument {: uri}}]
  (when (utils.endswith uri "flsproject.fnl")
    (config.reload server)
    (validate-config server))

  ;; TODO recompute for files when macro is changed
  (set fennel.macro-loaded []))

(λ notifications.textDocument/didClose [server _send {:textDocument {: uri}}]
  (local file (files.get-by-uri server uri))
  (set file.open? false)
  (set fennel.macro-loaded [])
  ;; TODO only reload from disk if we didn't get a didSave, instead of always
  (files.flush-uri server uri))

(λ requests.shutdown [_server _send]
  "The server still needs to respond to this request, so the program can't close yet. Just wait until notifications.exit"
  nil)

(λ notifications.exit [_server]
  "This is the real shutdown request, we can quit now"
  (os.exit 0))

{: requests
 : notifications}
