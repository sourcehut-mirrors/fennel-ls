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
                              :resolveProvider server.can-do-good-completions?
                              :triggerCharacters ["(" "[" "{"]
                              :completionItem {:labelDetailsSupport false}}
         :hoverProvider {:workDoneProgress false}
         :signatureHelpProvider {:workDoneProgress false
                                 :triggerCharacters [" "]
                                 :retriggerCharacters [" "]}
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
     :serverInfo {:name "fennel-ls" :version utils.version}}))

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

(λ requests.textDocument/signatureHelp [server
                                        _send
                                        {:textDocument {: uri} : position}]
  (let [file (files.get-by-uri server uri)
        byte (utils.position->byte file.text position server.position-encoding)]
    (case-try (analyzer.find-nearest-call server file byte)
      (call active-parameter)
      (analyzer.find-definition server file call)
      {:indeterminate nil &as definition}
      (formatter.signature-help-format definition)
      signature
      (message.call->signature-help server file call
                                      signature
                                      active-parameter)
      (catch _ nil))))

(λ requests.textDocument/hover [server _send {: position :textDocument {: uri}}]
  (let [file (files.get-by-uri server uri)
        byte (utils.position->byte file.text position server.position-encoding)]
    (case-try (analyzer.find-symbol file.ast byte)
      symbol (analyzer.search-main server file symbol {} {: byte})
      {:indeterminate nil &as result} {:contents (formatter.hover-format result)
                                       :range (message.ast->range server file
                                                                  symbol)}
      (catch _ nil))))

(set {:textDocument/completion requests.textDocument/completion
      :completionItem/resolve requests.completionItem/resolve}
     (require :fennel-ls.completion))

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
      (if (overlap? diagnostic.range range)
        (message.diagnostic->code-action server file diagnostic :quickfix)))))

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
