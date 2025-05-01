(local files (require :fennel-ls.files))
(local utils (require :fennel-ls.utils))
(local analyzer (require :fennel-ls.analyzer))
(local docs (require :fennel-ls.docs))
(local fennel (require :fennel))
(local message (require :fennel-ls.message))
(local format (require :fennel-ls.formatter))
(local {:metadata METADATA} (require :fennel.compiler))

(λ textDocument/completion [server _send {: position :textDocument {: uri}}]
  ;; get the file
  (let [file (files.get-by-uri server uri)
        ;; find where the cursor is
        byte (utils.position->byte file.text position server.position-encoding)
        ;; find what ast objects are under the cursor
        (?symbol parents) (analyzer.find-symbol file.ast byte)
        ;; check what context I'm in
        in-call-position? (and (fennel.list? (. parents 1))
                               (= ?symbol (. parents 1 1)))
        ;; find the first one that contains a scope
        scope (or (accumulate [?find nil _ parent (ipairs parents) &until ?find]
                    (. file.scopes parent))
                  file.scope)
        range (if ?symbol (message.ast->range server file ?symbol) {:start position :end position})
        results []
        seen {}]

    (fn add-completion! [name definition ?kind]
      (table.insert results (format.completion-item-format server name definition range ?kind)))

    (fn add-completion-recursively! [name definition]
      "add the completion. also recursively adds the fields' completions"

      (fn add-field-recursively! [field def]
        "TODO name this thing"
        (if (or (= :self (tostring (?. def :metadata :fnl/arglist 1)))
                (and (fennel.list? def.definition)
                     (or (and (fennel.sym? (. def.definition 1) "fn")
                              (fennel.sym? (?. def.definition 2 1) "self"))
                         (and (fennel.sym? (. def.definition 1) "λ")
                              (fennel.sym? (?. def.definition 2 1) "self")))))
          (add-completion-recursively! (.. name ":" field) def)
          (add-completion-recursively! (.. name "." field) def)))

      (when (not (. seen definition))
        (set (. seen definition) true)
        (add-completion! name definition)
        (when (= (type definition.definition) :string)
          (each [key value (pairs (-> (docs.get-global server :string) (. :fields)))]
            (add-completion-recursively! (.. name ":" key) value)))
        (when (fennel.table? definition.definition)
          (each [field value (pairs definition.definition)]
            (when (= (type field) :string)
              (case (analyzer.search-ast server definition.file value [] {})
                def (add-field-recursively! field def)
                _ (do
                    (io.stderr:write "BAD!!!! undocumented field: " (tostring field) "\n")
                    {:label field})))))
        (when definition.fields
          (each [field def (pairs definition.fields)]
            (when (= (type field) :string)
              (add-field-recursively! field def))))

        (set (. seen definition) false)))

    (local seen-manglings {})

    (each [_ global* (ipairs file.allowed-globals)]
      (when (not (. seen-manglings global*))
        (set (. seen-manglings global*) true)
        (case (analyzer.search-name-and-scope server file global* scope)
          def (if (and (= :_G (tostring global*))
                       (not (: (tostring ?symbol) :match "_G[:.]")))
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
      (set scope scope.parent))
    (if server.can-do-good-completions?
      {:itemDefaults {:editRange range :data {: uri : byte}}
       :items results}
      results)))

(fn completionItem/resolve [server _send completion-item]
  (let [{: uri : byte} completion-item.data
        file (files.get-by-uri server uri)
        (_symbol parents) (analyzer.find-symbol file.ast byte)
        scope (or (accumulate [?find nil _ parent (ipairs parents) &until ?find]
                    (. file.scopes parent))
                  file.scope)]
    (case (analyzer.search-name-and-scope server file completion-item.label scope)
      result (doto completion-item (tset :documentation (format.hover-format result))))))

{: textDocument/completion
 : completionItem/resolve}
