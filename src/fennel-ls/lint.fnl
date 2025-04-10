"Diagnostics
Provides the function (check server file), which goes through a file and mutates
the `file.diagnostics` field, filling it with diagnostics."

(local {: sym? : list? : table? : view
        : sym : list &as fennel} (require :fennel))
(local {: special? : op?} (require :fennel-ls.compiler))
(local analyzer (require :fennel-ls.analyzer))
(local message (require :fennel-ls.message))
(local utils (require :fennel-ls.utils))
(local dkjson (require :dkjson))

(local diagnostic-mt {:__tojson (fn [{: self} state] (dkjson.encode self state))
                      :__index #(. $1 :self $2)})

(fn diagnostic [self quickfix]
  (setmetatable {: self : quickfix} diagnostic-mt))

(fn could-be-rewritten-as-sym? [str]
  (and (= :string (type str)) (not (str:find "^%d"))
       (not (str:find "[^!$%*+/0-9<=>?A-Z\\^_a-z|\128-\255-]"))))

(λ unused-definition [server file symbol definition]
  "local variable that is defined but not used"
  (if (not (or (= "_" (: (tostring symbol) :sub 1 1))
               (= "_" (: (tostring symbol) :sub -1 -1))
               (accumulate [reference false
                            _ ref (ipairs definition.referenced-by)
                            &until reference]
                 (or (= ref.ref-type :read)
                     (= ref.ref-type :mutate)))))
    (diagnostic
      {:range (message.ast->range server file symbol)
       :message (.. "unused definition: " (tostring symbol))
       :severity message.severity.WARN
       :code :unused-definition}
      #[{:range (message.ast->range server file symbol)
         :newText (.. "_" (tostring symbol))}])))

;; this is way too specific; it's also safe to do this inside an `if` or `case`
(fn in-or? [calls symbol]
  "Check if the symbol is in an expression like `(or unpack table.unpack)`, where we want to suppress the module field stuff."
  (accumulate [in? false call (pairs calls) &until in?]
    (and (sym? (. call 1) :or) (utils.find call symbol))))

(fn module-field-helper [server file symbol ?ast stack]
  "if ?ast is a module field that isn't known, return a diagnostic"
  (let [opts {}
        item (analyzer.search-ast server file ?ast stack opts)]
    (if (and (not item)
             (. file.lexical symbol)
             (not (in-or? file.calls symbol))
             ;; this doesn't necessarily have to come thru require; it works
             ;; for built-in modules too
             opts.searched-through-require-with-stack-size-1)
        (diagnostic
         {:range (message.ast->range server file symbol)
          :message (.. "unknown field: " (tostring symbol))
          :severity message.severity.WARN
          :code :unknown-module-field}))))

(λ unknown-module-field [server file]
  "any multisym whose definition can't be found through a (require) call"
  (icollect [symbol (pairs file.references) &into file.diagnostics]
    (if (. (utils.multi-sym-split symbol) 2)
        (module-field-helper server file symbol symbol [])))

  (icollect [symbol binding (pairs file.definitions) &into file.diagnostics]
    (if binding.keys
        (module-field-helper server file symbol binding.definition
                             (fcollect [i (length binding.keys) 1 -1]
                               (. binding.keys i))))))

(λ unnecessary-method [server file colon call]
  "a call to the : builtin that could just be a multisym"
  (if (and (sym? colon ":")
           (sym? (. call 2))
           (. file.lexical call))
    (let [method (. call 3)]
      (if (could-be-rewritten-as-sym? method)
        {:range (message.ast->range server file call)
         :message (.. "unnecessary : call: use (" (tostring (. call 2))
                      ":" method ")")
         :severity message.severity.WARN
         :code :unnecessary-method}))))

(λ unnecessary-tset [server file head call]
  (λ all-syms? [call start end]
    (faccumulate [syms true
                  i start end]
      (and syms
           (could-be-rewritten-as-sym? (. call i)))))

  (λ make-new-text [call]
    (.. (faccumulate [text "(set "
                      i 2 (- (length call) 2)]
          (.. text (tostring (. call i)) "."))
        (tostring (. call (- (length call) 1)))
        " "
        (view (. call (length call)))
        ")"))

  (if (and (sym? head :tset)
           (sym? (. call 2))
           (all-syms? call 3 (- (length call) 1))
           (. file.lexical call))
      (diagnostic {:range (message.ast->range server file call)
                   :message (.. "unnecessary " (tostring head))
                   :severity message.severity.WARN
                   :code :unnecessary-tset}
                  #[{:range (message.ast->range server file call)
                     :newText (make-new-text call)}])))

(λ unnecessary-do-values [server file head call]
  (if (and (or (sym? head :do) (sym? head :values))
           (= nil (. call 3)) (. file.lexical call))
      (diagnostic {:range (message.ast->range server file call)
                   :message (.. "unnecessary " (tostring head))
                   :severity message.severity.WARN
                   :code :unnecessary-do-values}
                  #[{:range (message.ast->range server file call)
                     :newText (view (. call 2))}])))

(local implicit-do-forms (collect [form {: body-form?} (pairs (fennel.syntax))]
                           (values form body-form?)))

(λ redundant-do [server file head call]
  (let [last-body (. call (length call))]
    (if (and (. implicit-do-forms (tostring head)) (. file.lexical call)
             (list? last-body) (sym? (. last-body 1) :do))
        (diagnostic {:range (message.ast->range server file last-body)
                     :message "redundant do"
                     :severity message.severity.WARN
                     :code :redundant-do}
                    #[{:range (message.ast->range server file last-body)
                       :newText (table.concat
                                 (fcollect [i 2 (length last-body)]
                                   (view (. last-body i)))
                                 " ")}]))))

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
         :message (.. "faulty unpack call: " (tostring op)
                      " isn't variadic at runtime."
                      (if (sym? op "..")
                        (let [unpackme (view (. last-item 2))]
                          (.. " Use (table.concat " unpackme
                              ") instead of (.. (unpack " unpackme "))"))
                        (.. " Use a loop when you have a dynamic number of "
                            "arguments to (" (tostring op) ")")))
         :severity message.severity.WARN
         :code :bad-unpack}
        (if (and (= (length call) 2)
                 (= (length (. call 2)) 2)
                 (sym? op ".."))
          #[{:range (message.ast->range server file call)
             :newText (.. "(table.concat " (view (. call 2 2)) ")")}])))))

(λ var-never-set [server file symbol definition]
  (if (and definition.var? (not definition.var-set) (. file.lexical symbol))
      ;; we can't provide a quickfix for this because the hooks don't give us
      ;; the full AST of the call to var; just the LHS/RHS
      (diagnostic {:range (message.ast->range server file symbol)
                   :message (.. "var is never set: " (tostring symbol)
                                " Consider using (local) instead of (var)")
                   :severity message.severity.WARN
                   :code :var-never-set})))

(local op-identity-value {:+ 0 :* 1 :and true :or false :band -1 :bor 0 :.. ""})
(λ op-with-no-arguments [server file op call]
  "A call like (+) that could be replaced with a literal"
  (let [identity (. op-identity-value (tostring op))]
    (if (and (op? op)
             (= 1 (length call))
             (. file.lexical call)
             (not= nil identity))
      (diagnostic
        {:range  (message.ast->range server file call)
         :message (.. "write " (view identity) " instead of (" (tostring op) ")")
         :severity message.severity.WARN
         :code :op-with-no-arguments}
        #[{:range (message.ast->range server file call)
           :newText (view identity)}]))))

(λ no-decreasing-comparison [server file op call]
  (if (or (sym? op :>) (sym? op :>=))
      (diagnostic
       {:range  (message.ast->range server file call)
        :message "Use increasing operator instead of decreasing"
        :severity message.severity.WARN
        :code :no-decreasing-comparison}
       #[{:range (message.ast->range server file call)
          :newText (let [new (if (sym? op :>=) (fennel.sym :<=) (fennel.sym :<))
                         reversed (fcollect [i (length call) 2 -1
                                             &into (list (sym new))]
                                    (. call i))]
                     (view reversed))}])))

(λ match-reference? [ast references]
  (if (sym? ast) (?. references ast :target)
      (or (table? ast) (list? ast))
      (accumulate [ref false _ subast (pairs ast) &until ref]
        (match-reference? subast references))))

(λ match-should-case [server {: references &as file} ast]
  (when (and (list? ast)
             (sym? (. ast 1) :match)
             (not (faccumulate [ref false i 3 (length ast) 2 &until ref]
                    (match-reference? (. ast i) references))))
    (diagnostic {:range (message.ast->range server file (. ast 1))
                 :message "no pinned patterns; use case instead of match"
                 :severity message.severity.WARN
                 :code :match-should-case}
                #[{:range (message.ast->range server file (. ast 1))
                   :newText "case"}])))

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
     :message (.. "bad " (tostring (. arg 1))
                  " call: only the first value of the multival will be used")
     :severity message.severity.WARN
     :code :inline-unpack}))

(λ add-lint-diagnostics [server file]
  "fill up the file.diagnostics table with linting things"
  (let [lints server.configuration.lints
        diagnostics file.diagnostics]

    ;; definition lints
    (each [symbol definition (pairs file.definitions)]
      (when lints.unused-definition
        (table.insert diagnostics (unused-definition server file symbol definition)))
      (when lints.var-never-set
        (table.insert diagnostics (var-never-set     server file symbol definition))))

    ;; call lints
    ;; all non-macro calls. This only covers specials and function calls.
    (each [[head &as call] (pairs file.calls)]
      (when head
        (when (or lints.bad-unpack lints.inline-unpack)
          (table.insert diagnostics (bad-unpack server file head call)))
        (when lints.unnecessary-method
          (table.insert diagnostics (unnecessary-method server file head call)))
        (when lints.unnecessary-do
          (table.insert diagnostics (unnecessary-do-values server file head call)))
        (when lints.unnecessary-tset
          (table.insert diagnostics (unnecessary-tset server file head call)))
        (when lints.redundant-do
          (table.insert diagnostics (redundant-do server file head call)))
        (when lints.op-with-no-arguments
          (table.insert diagnostics (op-with-no-arguments server file head call)))
        (when lints.no-decreasing-comparison
          (table.insert diagnostics (no-decreasing-comparison server file head call)))

        ;; argument lints
        ;; every argument to a special or a function call
        ;; TODO: This may be changed to run for function calls, but not special calls.
        ;; I'll wait till we have more lints in here to see if it needs to change.
        (for [index 2 (length call)]
          (let [arg (. call index)]
            (when lints.multival-in-middle-of-call
              (table.insert diagnostics
                            (multival-in-middle-of-call server file head call
                                                        arg index)))))))

    (each [ast (pairs file.lexical)]
      (when lints.match-should-case
        (table.insert diagnostics (match-should-case server file ast))))

    (when lints.unknown-module-field
      (unknown-module-field server file))))

{: add-lint-diagnostics}
