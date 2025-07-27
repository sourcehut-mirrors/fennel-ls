"Completion

LSP Spec:
> * to achieve consistency across languages and to honor different clients
>   usually the client is responsible for filtering and sorting. This has also
>   the advantage that client can experiment with different filter and sorting
>   models.

Because of this, fennel-ls' job in completions is to report every single
possible completion, without being clever about filtering. To do this, we
iterate over the current scope, and recursively explore every field of every
variable.

This creates large completion messages, so we have an optimization trick:

LSP says that clients need to support resolving documentation/detail for
completion items lazily. This lazy resolution is very important because we
can skip sending the documentation for every possible completion until client
until it asks for each one. The documentation ends up being significantly more
than half of the completion response.

Although clients always support this lazy resolution, fennel-ls can only provide
it if it receives enough information in the completionItem/resolve request to
actually recover the original completion. If the client supports both
CompletionClientCapabilites.completionList.itemDefaults.editRange and
CompletionClientCapabilites.completionList.itemDefaults.data, then we can ask
the client to forward information to the resolve request by setting the `data`
to {: uri : byte}. When this capability exists, `server.can-do-good-completions?`
is set to true and we report that we support completionItem/resolve."

(local files (require :fennel-ls.files))
(local utils (require :fennel-ls.utils))
(local analyzer (require :fennel-ls.analyzer))
(local fennel (require :fennel))
(local message (require :fennel-ls.message))
(local format (require :fennel-ls.formatter))
(local navigate (require :fennel-ls.navigate))
(local compiler (require :fennel-ls.compiler))
(local {:metadata METADATA} (require :fennel.compiler))

(λ textDocument/completion [server _send {: position :textDocument {: uri}}]
  ;; get the file
  (let [file (files.get-by-uri server uri)
        ;; find where the cursor is
        byte (utils.position->byte file.text position server.position-encoding)
        ;; create a brand new file
        file {:text (.. (file.text:sub 1 (- byte 1)) "|" (file.text:sub byte)) :uri file.uri}
        _ (compiler.compile server file)
        ;; find what ast objects are under the cursor
        (symbol parents) (analyzer.find-symbol file.ast byte)
        ;; check what context I'm in
        in-call-position? (and (fennel.list? (. parents 1))
                               (= symbol (. parents 1 1)))
        ;; find the first one that contains a scope
        scope (or (accumulate [?find nil _ parent (ipairs parents) &until ?find]
                    (. file.scopes parent))
                  file.scope)
        range (case (message.ast->range server file symbol)
                r (do (set r.end.character (- r.end.character 1)) r)
                _ {:start position :end position})
        results []
        seen {}]

    (fn add-completion! [name definition ?kind]
      (when (and symbol (not= name (tostring symbol)))
        (table.insert results (format.completion-item-format server name definition range ?kind))))

    (fn add-completion-recursively! [name definition]
      "add the completion. also recursively adds the fields' completions"
      (when (not (. seen definition))
        (set (. seen definition) true)
        (add-completion! name definition)
        (each [field def ?string-method (navigate.iter-fields server definition)]
          (when (utils.valid-sym-field? field)
            (if (or (= :self (tostring (?. def :metadata :fnl/arglist 1)))
                    ?string-method
                    (and (fennel.list? def.definition)
                         (or (fennel.sym? (. def.definition 1) "fn")
                             (fennel.sym? (. def.definition 1) "λ"))
                         (or (and (fennel.table? (. def.definition 2))
                                  (fennel.sym? (. def.definition 2 1) "self"))
                             (and (fennel.sym? (. def.definition 2))
                                  (fennel.table? (. def.definition 3))
                                  (fennel.sym? (?. def.definition 3 1) "self")))))
                (add-completion-recursively! (.. name ":" field) def)
                (add-completion-recursively! (.. name "." field) def))))
        (set (. seen definition) false)))

    (fn expression-completions []
      (local seen-manglings {})
      (each [_ global* (ipairs file.allowed-globals)]
        (when (not (. seen-manglings global*))
          (set (. seen-manglings global*) true)
          (case (analyzer.search-name-and-scope server file global* scope)
            def (if (and (= :_G (tostring global*))
                         (not (: (tostring symbol) :match "_G[:.]")))
                  (add-completion! global* def)
                  (add-completion-recursively! global* def))
            _ (do
                (io.stderr:write "BAD!!!! undocumented global: " (tostring global*) "\n")
                (add-completion! global* {})))))

      (var scope scope)
      (while scope
        (each [mangling (pairs scope.manglings)]
          (when (not (. seen-manglings mangling))
            (set (. seen-manglings mangling) true)
            (case (analyzer.search-name-and-scope server file mangling scope)
              def (add-completion-recursively! mangling def)
              _ (add-completion-recursively! mangling {}))))

        (when in-call-position?
          (each [macro* macro-value (pairs scope.macros)]
            (add-completion! macro*
                             {:binding macro*
                              :metadata (. METADATA macro-value)}
                             :Keyword))

          (each [special (pairs scope.specials)]
             (case (analyzer.search-name-and-scope server file special scope)
               def (add-completion! special def :Operator)
               _ (do
                   (io.stderr:write "BAD!!!! undocumented special: " (tostring special) "\n")
                   {:label special}))))
        (set scope scope.parent)))

    (fn binding-completions []
      "completions when you're writing a destructure pattern. We suggest identifiers which are unknown"
      (each [_ {: message} (ipairs file.diagnostics)]
        (case (message:match "unknown identifier: ([a-zA-Z0-9_-]+)")
          identifier (add-completion! identifier {} :Variable))))

    (when symbol
      (if (. file.definitions symbol)
          (binding-completions)
          (expression-completions)))

    (if server.can-do-good-completions?
      {:itemDefaults {:editRange (if server.can-do-insert-replace-completions?
                                     {:insert {:start range.start :end position}
                                      :replace range}
                                     range)
                      :data {: uri : byte}}
       :items results}
      results)))

(fn completionItem/resolve [server _send completion-item]
  (let [result
        (let [{: uri : byte} completion-item.data
              file (files.get-by-uri server uri)
              (_symbol parents) (analyzer.find-symbol file.ast byte)
              scope (or (accumulate [?find nil _ parent (ipairs parents) &until ?find]
                          (. file.scopes parent))
                        file.scope)]
          (analyzer.search-name-and-scope server file completion-item.label scope))]
    (when result
      (set completion-item.documentation (format.hover-format server completion-item.label result)))
    completion-item))

{: textDocument/completion
 : completionItem/resolve}
