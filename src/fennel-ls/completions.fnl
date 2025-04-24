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
      (table.insert results
                    (doto (format.completion-item-format name definition)
                      (tset :filterText name)
                      (tset :textEdit {:newText name : range}))))

    (fn add-completion-recursively [definition name]
      "add the completion. also recursively adds the fields' completions"
      (when (not (. seen definition))
        (set (. seen definition) true)
        (add-completion definition name)
        (when (= (type definition.definition) :string)
          (each [key value (pairs (-> (docs.get-global server :string) (. :fields)))]
            (add-completion-recursively value (.. name ":" key))))
        (when (fennel.table? definition.definition)
          (each [field value (pairs definition.definition)]
            (when (= (type field) :string)
              (case (analyzer.search-ast server definition.file value [] {})
                def (if (or (= :self (tostring (?. def :metadata :fnl/arglist 1)))
                            (and (fennel.list? def.definition)
                                 ;; TODO check that arg is called `self`
                                 (or (and (fennel.sym? (. def.definition 1) "fn")
                                          (fennel.sym? (. def.definition 2) "self"))
                                     (and (fennel.sym? (. def.definition 1) "λ")
                                          (fennel.sym? (. def.definition 2) "self")))))
                      (add-completion-recursively def (.. name ":" field))
                      (add-completion-recursively def (.. name "." field)))
                _ (do
                    (io.stderr:write "BAD!!!! undocumented field: " (tostring field) "\n")
                    {:label field})))))
        (when definition.fields
            (each [field value (pairs definition.fields)]
              (when (= (type field) :string)
                (if (or (= :self (tostring (?. value :metadata :fnl/arglist 1)))
                        (and (fennel.list? value.definition)
                             ;; TODO check that arg is called `self`
                             (or (and (fennel.sym? (. value.definition 1) "fn")
                                      (fennel.sym? (. value.definition 2) "self"))
                                 (and (fennel.sym? (. value.definition 1) "λ")
                                      (fennel.sym? (. value.definition 2) "self")))))
                  (add-completion-recursively value (.. name ":" field))
                  (add-completion-recursively value (.. name "." field))))))

        (set (. seen definition) false)))
    ;; end yield

    (each [_ global* (ipairs file.allowed-globals)]
      (case (analyzer.search-name-and-scope server file global* scope)
        def (if (and (= :_G (tostring global*))
                     (not (: (tostring ?symbol) :match "_G[:.]")))
              (add-completion def global*)
              (add-completion-recursively def global*))
        _ (do
            (io.stderr:write "BAD!!!! undocumented global: " (tostring global*) "\n")
            {:label global*})))
    (var scope scope)
    (while scope
      (each [mangling (pairs scope.manglings)]
        (case (analyzer.search-name-and-scope server file mangling scope)
          def (add-completion-recursively def mangling)
          _ (add-completion-recursively {} mangling)))
      (when in-call-position?
        (each [macro* (pairs scope.macros)]
          (table.insert results {:label macro* :filterText macro* :textEdit {:newText macro* : range}}))

        (each [special (pairs scope.specials)]
           (case (analyzer.search-name-and-scope server file special scope)
             def (add-completion-recursively def special)
             _ (do
                 (io.stderr:write "BAD!!!! undocumented special: " (tostring special) "\n")
                 {:label special}))))
      (set scope scope.parent))
    results))

{: textDocument/completion}
