"Diagnostics
Provides the function (check self file), which goes through a file and mutates
the `file.diagnostics` field, filling it with diagnostics."

(local {: sym? : list? : view} (require :fennel))
(local language (require :fennel-ls.language))
(local message (require :fennel-ls.message))
(local utils (require :fennel-ls.utils))
(local {:scopes {:global {: specials}}}
  (require :fennel.compiler))

(local ops {"+" 1 "-" 1 "*" 1 "/" 1 "//" 1 "%" 1 "^" 1 ">" 1 "<" 1 ">=" 1 "<=" 1 "=" 1 "not=" 1 ".." 1 "." 1 "and" 1 "or" 1 "band" 1 "bor" 1 "bxor" 1 "bnot" 1 "lshift" 1 "rshift" 1})
(fn special? [item]
  (and (sym? item)
       (. specials (tostring item))
       item))

(fn op? [item]
  (and (sym? item)
       (. ops (tostring item))
       item))

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

(λ bad-unpack [self file op call]
  "an unpack call leading into an operator"
  (let [last-item (. call (length call))]
    (if (and (op? op)
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
  "A call like (+) that could be replaced with a literal"
  (if (and (op? op)
           (not (. call 2))
           (. file.lexical call)
           (not= nil (. op-identity-value (tostring op))))
    {:range  (message.ast->range self file call)
     :message (.. "write " (view (. op-identity-value (tostring op))) " instead of (" (tostring op) ")")
     :severity message.severity.WARN
     :code 306
     :codeDescription "op-with-no-arguments"}))

(λ multival-in-middle-of-call [self file fun call arg index]
  "generally, values and unpack are signs that the user is trying to do
  something with multiple values. However, multiple values will get
  \"adjusted\" to one value if they don't come at the end of the call."
  (if (and (not (and (special? fun) (not (op? fun))))
           (not= index (length call))
           (list? arg)
           (or (sym? (. arg 1) :values)
               (sym? (. arg 1) :unpack)
               (sym? (. arg 1) :_G.unpack)
               (sym? (. arg 1) :table.unpack)))
    {:range (message.ast->range self file arg)
     :message (.. "bad " (tostring (. arg 1)) " call: only the first value of the multival will be used")
     :severity message.severity.WARN
     :code 307
     :codeDescription "bad-unpack"}))

(λ check [self file]
  "fill up the file.diagnostics table with linting things"
  (let [checks self.configuration.checks
        diagnostics file.diagnostics]

    ;; definition lints
    (each [symbol definition (pairs file.definitions)]
      (if checks.unused-definition (table.insert diagnostics (unused-definition self file symbol definition)))
      (if checks.var-never-set     (table.insert diagnostics (var-never-set     self file symbol definition))))

    ;; call lints
    ;; all non-macro calls. This only covers specials and function calls.
    (each [[head &as call] (pairs file.calls)]
      (when head
        (if checks.bad-unpack           (table.insert diagnostics (bad-unpack           self file head call)))
        (if checks.unnecessary-method   (table.insert diagnostics (unnecessary-method   self file head call)))
        (if checks.op-with-no-arguments (table.insert diagnostics (op-with-no-arguments self file head call)))

        ;; argument lints
        ;; every argument to a special or a function call
        ;; TODO: This may be changed to run for function calls, but not special calls.
        ;; I'll wait till we have more lints in here to see if it needs to change.
        (for [index 2 (length call)]
          (let [arg (. call index)]
            (if checks.multival-in-middle-of-call (table.insert diagnostics (multival-in-middle-of-call self file head call arg index)))))))

    (if checks.unknown-module-field
      (unknown-module-field self file))))
    ;; (if checks.unnecessary-values
    ;;   (unnecessary-values file)))
    ;; (if checks.unnecessary-do)
    ;;   (unnecessary-do file)))
    ;; (if checks.unnecessary-unary-op))
    ;;   (unnecessary-values file)))

{: check}
