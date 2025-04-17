(local files (require :fennel-ls.files))
(local utils (require :fennel-ls.utils))
(local analyzer (require :fennel-ls.analyzer))
(local docs (require :fennel-ls.docs))
(local fennel (require :fennel))
(local message (require :fennel-ls.message))
(local format (require :fennel-ls.formatter))

;; CompletionItemKind
(local _kinds
 {:Text 1 :Method 2 :Function 3 :Constructor 4 :Field 5 :Variable 6 :Class 7
  :Interface 8 :Module 9 :Property 10 :Unit 11 :Value 12 :Enum 13 :Keyword 14
  :Snippet 15 :Color 16 :File 17 :Reference 18 :Folder 19 :EnumMember 20
  :Constant 21 :Struct 22 :Event 23 :Operator 24 :TypeParameter 25})

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
        seen []]

    (fn add-completion [definition name]
      "add the completion. also recursively adds the fields' completions"
      (when (not (. seen definition))
        (set (. seen definition) true)
        (table.insert results
                      (doto (format.completion-item-format name definition)
                        (tset :filterText name)
                        (tset :textEdit {:newText name : range})))

        (when (= (type definition.definition) :string)
          (each [key value (pairs (-> (docs.get-global server :string) (. :fields)))]
            (add-completion value (.. name ":" key))))
        (when (fennel.table? definition.definition)
          (each [field value (pairs definition.definition)]
            (when (= (type field) :string)
              (case (analyzer.search-ast server definition.file value [] {})
                def (do
                      (when (or (?. def :metadata :fnl/arglist)
                                (and (fennel.list? def.definition)
                                     (or (fennel.sym? (. def.definition 1) "fn"))
                                     (or (fennel.sym? (. def.definition 1) "λ"))))
                        (add-completion def (.. name ":" field)))
                      (add-completion def (.. name "." field)))
                _ (do
                    (io.stderr:write "BAD!!!! undocumented field: " (tostring field) "\n")
                    {:label field})))))
        (when definition.fields
            (each [field value (pairs definition.fields)]
              (when (= (type field) :string)
                (add-completion value (.. name "." field)))))

        (set (. seen definition) false)))
    ;; end yield

    (each [_ global* (ipairs file.allowed-globals)]
      (case (analyzer.search-name-and-scope server file global* scope)
        def (add-completion def global*)
        _ (do
            (io.stderr:write "BAD!!!! undocumented global: " (tostring global*) "\n")
            {:label global*})))
    (var scope scope)
    (while scope
      (each [mangling (pairs scope.manglings)]
        (case (analyzer.search-name-and-scope server file mangling scope)
          def (add-completion def mangling)
          _ (do
              (io.stderr:write "BAD!!!! undocumented mangling: " (tostring mangling) "\n")
              {:label mangling})))
      (when in-call-position?
        (each [macro* (pairs scope.macros)]
          ;; TODO make it work like the other ones
          (table.insert results {:label macro* :filterText macro* :textEdit {:newText macro* : range}}))

        (each [special (pairs scope.specials)]
           (case (analyzer.search-name-and-scope server file special scope)
             def (add-completion def special)
             _ (do
                 (io.stderr:write "BAD!!!! undocumented special: " (tostring special) "\n")
                 {:label special}))))
      (set scope scope.parent))
    results))

{: textDocument/completion}
