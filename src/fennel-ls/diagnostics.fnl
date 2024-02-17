"Diagnostics
Provides the function (check self file), which goes through a file and mutates
the `file.diagnostics` field, filling it with diagnostics."

(local {: sym? : list? : view} (require :fennel))
(local language (require :fennel-ls.language))
(local message (require :fennel-ls.message))
(local utils (require :fennel-ls.utils))

(λ unused-definition [self file symbol definition]
  "local variable that is defined but not used"
    (if (and (not= "_" (: (tostring symbol) :sub 1 1))
             (not (accumulate [reference false
                               _ ref (ipairs definition.referenced-by)
                               &until reference]
                    (or (= ref.ref-type :read)
                        (= ref.ref-type :mutate)))))
      {:range (message.ast->range self file symbol)
       :message (.. "unused definition: " (tostring symbol))
       :severity message.severity.WARN
       :code 301
       :codeDescription "unused-definition"}))

(λ unknown-module-field [self file]
  "any multisym whose definition can't be found through a (require) call"
  (icollect [symbol (pairs file.references) &into file.diagnostics]
    (if (. (utils.multi-sym-split symbol) 2)
      (let [opts {}
            item (language.search-ast self file symbol [] opts)]
        (if (and (not item) opts.searched-through-require)
          {:range (message.ast->range self file symbol)
           :message (.. "unknown field: " (tostring symbol))
           :severity message.severity.WARN
           :code 302
           :codeDescription "unknown-module-field"})))))

(λ unnecessary-method [self file colon call]
  "a call to the : builtin that could just be a multisym"
  (if (sym? colon ":")
   (let [receiver (. call 2)
         method (. call 3)]
    (if (and (sym? receiver)
             (. file.lexical call)
             (= :string (type method))
             (not (method:find "^[0-9]"))
             (not (method:find "[^!$%*+-/0-9<=>?A-Z\\^_a-z|\128-\255]")))
        (case (message.ast->range self file call)
          range {: range
                 :message (.. "unnecessary : call: use (" (tostring receiver) ":" method ")")
                 :severity message.severity.WARN
                 :code 303
                 :codeDescription "unnecessary-method"})))))

(local ops {"+" 1 "-" 1 "*" 1 "/" 1 "//" 1 "%" 1 ".." 1 "and" 1 "or" 1})
(λ bad-unpack [self file op call]
  "an unpack call leading into an operator"
    (if (and (sym? op)
             (. ops (tostring op))
             ;; last item is an unpack call
             (list? (. call (length call)))
             (or (sym? (. call (length call) 1) :unpack)
                 (sym? (. call (length call) 1) :_G.unpack)
                 (sym? (. call (length call) 1) :table.unpack))
             ;; Only the unpack call needs to be present in the original file.
             (. file.lexical (. call (length call))))
        (case (message.ast->range self file (. call (length call)))
          range {: range
                 :message (.. "faulty unpack call: " (tostring op) " isn't variadic at runtime."
                              (if (sym? op "..")
                                (let [unpackme (view (. call (length call) 2))]
                                  (.. " Use (table.concat " unpackme ") instead of (.. (unpack " unpackme "))"))
                                (.. " Use a loop when you have a dynamic number of arguments to (" (tostring op) ")")))
                 :severity message.severity.WARN
                 :code 304
                 :codeDescription "bad-unpack"})))

(λ var-never-set [self file symbol definition]
    (if (and definition.var? (not definition.var-set))
        {:range (message.ast->range self file symbol)
         :message (.. "var is never set: " (tostring symbol) " Consider using (local) instead of (var)")
         :severity message.severity.WARN
         :code 305
         :codeDescription "var-never-set"}))

(λ check [self file]
  "fill up the file.diagnostics table with linting things"
  (let [checks self.configuration.checks
        d file.diagnostics]
    ;; definition diagnostics
    (each [symbol definition (pairs file.definitions)]
      (if checks.unused-definition
        (tset d (+ 1 (length d)) (unused-definition self file symbol definition)))
      (if checks.var-never-set
        (tset d (+ 1 (length d)) (var-never-set self file symbol definition))))

    ;; call diagnostics
    (each [[head &as call] (pairs file.calls)]
      (when head
        (if checks.bad-unpack
          (tset d (+ 1 (length d)) (bad-unpack self file head call)))
        (if checks.unnecessary-method
          (tset d (+ 1 (length d)) (unnecessary-method self file head call)))))

    (if checks.unknown-module-field
      (unknown-module-field self file))))
    ;; (if checks.unnecessary-values
    ;;   (unnecessary-values file)))
    ;; (if checks.unnecessary-do)
    ;;   (unnecessary-do file)))
    ;; (if checks.unnecessary-unary-op))
    ;;   (unnecessary-values file)))

{: check}
