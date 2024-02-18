"Diagnostics
Provides the function (check self file), which goes through a file and mutates
the `file.diagnostics` field, filling it with diagnostics."

(local {: sym? : list? : view} (require :fennel))
(local language (require :fennel-ls.language))
(local message (require :fennel-ls.message))
(local utils (require :fennel-ls.utils))

(λ unused-definition [self file symbol definition]
  "local variable that is defined but not used"
  (if (not (or (= "_" (: (tostring symbol) :sub 1 1))
               (accumulate [reference false
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
  (if (and (sym? colon ":")
           (sym? (. call 2))
           (. file.lexical call))
    (let [method (. call 3)]
      (if (and (= :string (type method))
               (not (method:find "^[0-9]"))
               (not (method:find "[^!$%*+-/0-9<=>?A-Z\\^_a-z|\128-\255]")))
        {:range (message.ast->range self file call)
         :message (.. "unnecessary : call: use (" (tostring (. call 2)) ":" method ")")
         :severity message.severity.WARN
         :code 303
         :codeDescription "unnecessary-method"}))))

(local ops {"+" 1 "-" 1 "*" 1 "/" 1 "//" 1 "%" 1 ".." 1 "and" 1 "or" 1 "band" 1 "bor" 1 "bxor" 1 "bnot" 1})
(λ bad-unpack [self file op call]
  "an unpack call leading into an operator"
  (let [last-item (. call (length call))]
    (if (and (sym? op)
             (. ops (tostring op))
             ;; last item is an unpack call
             (list? last-item)
             (or (sym? (. last-item 1) :unpack)
                 (sym? (. last-item 1) :_G.unpack)
                 (sym? (. last-item 1) :table.unpack))
             (. file.lexical last-item)
             (. file.lexical call))
     {:range (message.ast->range self file last-item)
      :message (.. "faulty unpack call: " (tostring op) " isn't variadic at runtime."
                   (if (sym? op "..")
                     (let [unpackme (view (. last-item 2))]
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

(local op-identity-value {:+ 0 :* 1 :and true :or false :band -1 :bor 0 :.. ""})
(λ op-with-no-arguments [self file op call]
  (if (and (sym? op)
           (. ops (tostring op))
           (not (. call 2))
           (. file.lexical call)
           (not= nil (. op-identity-value (tostring op))))
    {:range  (message.ast->range self file call)
     :message (.. "write " (view (. op-identity-value (tostring op))) " instead of (" (tostring op) ")")
     :severity message.severity.WARN
     :code 306
     :codeDescription "op-with-no-arguments"}))

(λ check [self file]
  "fill up the file.diagnostics table with linting things"
  (let [checks self.configuration.checks
        diagnostics file.diagnostics]
    ;; definition diagnostics
    (each [symbol definition (pairs file.definitions)]
      (if checks.unused-definition (table.insert diagnostics (unused-definition self file symbol definition)))
      (if checks.var-never-set     (table.insert diagnostics (var-never-set     self file symbol definition))))

    ;; call diagnostics
    ;; all non-macro calls. This only covers the macroexpanded world
    (each [[head &as call] (pairs file.calls)]
      (when head
        (if checks.bad-unpack           (table.insert diagnostics (bad-unpack           self file head call)))
        (if checks.unnecessary-method   (table.insert diagnostics (unnecessary-method   self file head call)))
        (if checks.op-with-no-arguments (table.insert diagnostics (op-with-no-arguments self file head call)))))

    (if checks.unknown-module-field
      (unknown-module-field self file))))
    ;; (if checks.unnecessary-values
    ;;   (unnecessary-values file)))
    ;; (if checks.unnecessary-do)
    ;;   (unnecessary-do file)))
    ;; (if checks.unnecessary-unary-op))
    ;;   (unnecessary-values file)))

{: check}
