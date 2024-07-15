"Diagnostics
Provides the function (check server file), which goes through a file and mutates
the `file.diagnostics` field, filling it with diagnostics."

(local {: sym? : list? : view} (require :fennel))
(local analyzer (require :fennel-ls.analyzer))
(local message (require :fennel-ls.message))
(local utils (require :fennel-ls.utils))
(local {:scopes {:global {: specials}}}
  (require :fennel.compiler))

(local dkjson (require :dkjson))
(local diagnostic-mt {:__tojson (fn [self state] (dkjson.encode (. self :self) state)) :__index #(. $1 :self $2)})
(fn diagnostic [self quickfix]
  (setmetatable {: self : quickfix} diagnostic-mt))

(local ops {"+" 1 "-" 1 "*" 1 "/" 1 "//" 1 "%" 1 "^" 1 ">" 1 "<" 1 ">=" 1 "<=" 1 "=" 1 "not=" 1 ".." 1 "." 1 "and" 1 "or" 1 "band" 1 "bor" 1 "bxor" 1 "bnot" 1 "lshift" 1 "rshift" 1})
(fn special? [item]
  (and (sym? item)
       (. specials (tostring item))
       item))

(fn op? [item]
  (and (sym? item)
       (. ops (tostring item))
       item))

(λ unused-definition [server file symbol definition]
  "local variable that is defined but not used"
  (if (not (or (= "_" (: (tostring symbol) :sub 1 1))
               (accumulate [reference false
                            _ ref (ipairs definition.referenced-by)
                            &until reference]
                 (or (= ref.ref-type :read)
                     (= ref.ref-type :mutate)))))
    (diagnostic
      {:range (message.ast->range server file symbol)
       :message (.. "unused definition: " (tostring symbol))
       :severity message.severity.WARN
       :code 301
       :codeDescription "unused-definition"}
      #[{:range (message.ast->range server file symbol)
         :newText (.. "_" (tostring symbol))}])))

(fn module-field-helper [server file symbol ?ast stack]
  "if ?ast is a module field that isn't known, return a diagnostic"
  (let [opts {}
        item (analyzer.search-ast server file ?ast stack opts)]
    (if (and (not item)
             opts.searched-through-require-with-stack-size-1
             (not opts.searched-through-require-indeterminate))
      {:range (message.ast->range server file symbol)
       :message (.. "unknown field: " (tostring symbol))
       :severity message.severity.WARN
       :code 302
       :codeDescription "unknown-module-field"})))

(λ unknown-module-field [server file]
  "any multisym whose definition can't be found through a (require) call"
  (icollect [symbol (pairs file.references) &into file.diagnostics]
    (if (. (utils.multi-sym-split symbol) 2)
      (module-field-helper server file symbol symbol [])))

  (icollect [symbol binding (pairs file.definitions) &into file.diagnostics]
    (if binding.keys
      (module-field-helper server file symbol binding.definition (fcollect [i (length binding.keys) 1 -1]
                                                                   (. binding.keys i))))))

(λ unnecessary-method [server file colon call]
  "a call to the : builtin that could just be a multisym"
  (if (and (sym? colon ":")
           (sym? (. call 2))
           (. file.lexical call))
    (let [method (. call 3)]
      (if (and (= :string (type method))
               (not (method:find "^[0-9]"))
               (not (method:find "[^!$%*+-/0-9<=>?A-Z\\^_a-z|\128-\255]")))
        {:range (message.ast->range server file call)
         :message (.. "unnecessary : call: use (" (tostring (. call 2)) ":" method ")")
         :severity message.severity.WARN
         :code 303
         :codeDescription "unnecessary-method"}))))

(λ bad-unpack [server file op call]
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
      (diagnostic
        {:range (message.ast->range server file last-item)
         :message (.. "faulty unpack call: " (tostring op) " isn't variadic at runtime."
                      (if (sym? op "..")
                        (let [unpackme (view (. last-item 2))]
                          (.. " Use (table.concat " unpackme ") instead of (.. (unpack " unpackme "))"))
                        (.. " Use a loop when you have a dynamic number of arguments to (" (tostring op) ")")))
         :severity message.severity.WARN
         :code 304
         :codeDescription "bad-unpack"}
        (if (and (= (length call) 2)
                 (= (length (. call 2)) 2)
                 (sym? op ".."))
          #[{:range (message.ast->range server file call)
             :newText (.. "(table.concat " (view (. call 2 2)) ")")}])))))

(λ var-never-set [server file symbol definition]
  (if (and definition.var? (not definition.var-set) (. file.lexical symbol))
    {:range (message.ast->range server file symbol)
     :message (.. "var is never set: " (tostring symbol) " Consider using (local) instead of (var)")
     :severity message.severity.WARN
     :code 305
     :codeDescription "var-never-set"}))

(local op-identity-value {:+ 0 :* 1 :and true :or false :band -1 :bor 0 :.. ""})
(λ op-with-no-arguments [server file op call]
  "A call like (+) that could be replaced with a literal"
  (let [identity (. op-identity-value (tostring op))]
    (if (and (op? op)
             (not (. call 2))
             (. file.lexical call)
             (not= nil identity))
      (diagnostic
        {:range  (message.ast->range server file call)
         :message (.. "write " (view identity) " instead of (" (tostring op) ")")
         :severity message.severity.WARN
         :code 306
         :codeDescription "op-with-no-arguments"}
        #[{:range (message.ast->range server file call)
           :newText (view identity)}]))))

(λ multival-in-middle-of-call [server file fun call arg index]
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
    {:range (message.ast->range server file arg)
     :message (.. "bad " (tostring (. arg 1)) " call: only the first value of the multival will be used")
     :severity message.severity.WARN
     :code 307
     :codeDescription "bad-unpack"}))

(λ check [server file]
  "fill up the file.diagnostics table with linting things"
  (let [lints server.configuration.lints
        diagnostics file.diagnostics]

    ;; definition lints
    (each [symbol definition (pairs file.definitions)]
      (if lints.unused-definition (table.insert diagnostics (unused-definition server file symbol definition)))
      (if lints.var-never-set     (table.insert diagnostics (var-never-set     server file symbol definition))))

    ;; call lints
    ;; all non-macro calls. This only covers specials and function calls.
    (each [[head &as call] (pairs file.calls)]
      (when head
        (if lints.bad-unpack           (table.insert diagnostics (bad-unpack           server file head call)))
        (if lints.unnecessary-method   (table.insert diagnostics (unnecessary-method   server file head call)))
        (if lints.op-with-no-arguments (table.insert diagnostics (op-with-no-arguments server file head call)))

        ;; argument lints
        ;; every argument to a special or a function call
        ;; TODO: This may be changed to run for function calls, but not special calls.
        ;; I'll wait till we have more lints in here to see if it needs to change.
        (for [index 2 (length call)]
          (let [arg (. call index)]
            (if lints.multival-in-middle-of-call (table.insert diagnostics (multival-in-middle-of-call server file head call arg index)))))))

    (if lints.unknown-module-field
      (unknown-module-field server file))))
    ;; (if lints.unnecessary-values
    ;;   (unnecessary-values file)))
    ;; (if lints.unnecessary-do)
    ;;   (unnecessary-do file)))
    ;; (if lints.unnecessary-unary-op))
    ;;   (unnecessary-values file)))

{: check}
