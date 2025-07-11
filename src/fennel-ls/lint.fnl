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

(local lints {:definition []
              :reference []
              :macro-call []
              :function-call []
              :special-call []})

(local all-lints [])

(fn add-lint [code lint ...]
  (table.insert all-lints lint)
  (for [i 1 (select :# lint ...)]
    (let [lint (select i lint ...)]
      (set lint.name code)
      (if (= (type lint.type) :table)
        (each [_ t (ipairs lint.type)]
          (table.insert (assert (. lints t) (.. "unknown lint type " t)) lint))
        (table.insert (assert (. lints lint.type) (.. "unknown lint type " lint.type)) lint)))))

(fn could-be-rewritten-as-sym? [str]
  (and (= :string (type str)) (not (str:find "^%d"))
       (not (str:find "[^!$%*+/0-9<=>?A-Z\\^_a-z|\128-\255-]"))))


(add-lint :unused-definition
  {:type :definition
   :impl (fn [server file symbol definition]
           "local variable that is defined but not used"
           (if (not (or (= "_" (: (tostring symbol) :sub 1 1))
                        (= "_" (: (tostring symbol) :sub -1 -1))
                        (accumulate [reference false
                                     _ ref (ipairs definition.referenced-by)
                                     &until reference]
                          (or (= ref.ref-type :read)
                              (= ref.ref-type :mutate)))))
             {:range (message.ast->range server file symbol)
              :message (.. "unused definition: " (tostring symbol))
              :severity message.severity.WARN
              :fix #{:title (.. "Replace " (tostring symbol) " with _" (tostring symbol))
                     :changes [{:range (message.ast->range server file symbol)
                                :newText (.. "_" (tostring symbol))}]}}))})

;; this is way too specific; it's also safe to do this inside an `if` or `case`
(fn in-or? [calls symbol]
  "Check if the symbol is in an expression like `(or unpack table.unpack)`, where we want to suppress the module field stuff."
  (accumulate [in? false call (pairs calls) &until in?]
    (and (sym? (. call 1) :or) (utils.find call symbol))))

(fn module-field-helper [server file symbol ?ast ?stack]
  "if ?ast is a module field that isn't known, return a diagnostic"
  (let [opts {}
        item (analyzer.search server file ?ast opts {:stack ?stack})]
    (if (and (not item)
             (not (in-or? file.calls symbol))
             ;; this doesn't necessarily have to come thru require; it works
             ;; for built-in modules too
             opts.searched-through-require-with-stack-size-1)
        {:range (message.ast->range server file symbol)
         :message (.. "unknown field: " (tostring symbol))
         :severity message.severity.WARN})))

(add-lint :unknown-module-field
  {:type :reference
   :impl (fn [server file symbol]
           (if (. (utils.multi-sym-split symbol) 2)
               (module-field-helper server file symbol symbol)))}
  {:type :definition
   :impl (fn [server file symbol definition]
           (if definition.keys
               (module-field-helper server file symbol definition.definition
                                    (fcollect [i (length definition.keys) 1 -1]
                                      (. definition.keys i)))))})

(add-lint :unnecessary-method
  {:type :special-call
   :impl (fn [server file ast]
           "a call to the : builtin that could just be a multisym"
            (let [object (. ast 2)
                  method (. ast 3)]
              (if (and (sym? (. ast 1) ":")
                       (sym? object)
                       (could-be-rewritten-as-sym? method))
                {:range (message.ast->range server file ast)
                 :message (.. "unnecessary : call: use (" (tostring object) ":" method ")")
                 :severity message.severity.WARN})))})

(add-lint :unnecessary-tset
  {:type :special-call
   :impl (fn [server file ast]
           (let [all-rewritable? (faccumulate [syms true
                                               i 3 (- (length ast) 1)
                                               &until (not syms)]
                                    (could-be-rewritten-as-sym? (. ast i)))]
             (if (and (sym? (. ast 1) "tset")
                      (sym? (. ast 2))
                      all-rewritable?)
                 {:range (message.ast->range server file ast)
                  :message "unnecessary tset"
                  :severity message.severity.WARN
                  :fix #{:title "Replace tset with set"
                         :changes [{:range (message.ast->range server file ast)
                                    :newText (string.format "(set %s.%s %s)"
                                                            (tostring (. ast 2))
                                                            (table.concat ast "." 3 (- (length ast) 1))
                                                            (view (. ast (length ast))))}]}})))})

(local redundant-wrappers
  {:do true :values true :+ true :* true :and true :or true :band true :bor true ".." true})

(add-lint :unnecessary-unary
  {:type :special-call
   :impl (fn [server file ast]
           (if (and (sym? (. ast 1))
                    (. redundant-wrappers (tostring (. ast 1)))
                    (= (length ast) 2))
               {:range (message.ast->range server file ast)
                :message (.. "unnecessary " (tostring (. ast 1)))
                :severity message.severity.WARN
                :fix #{:title "Unwrap the expression"
                       :changes [{:range (message.ast->range server file ast)
                                  :newText (view (. ast 2))}]}}))})

(local implicit-do-forms (collect [form {: body-form?} (pairs (fennel.syntax))]
                           (values form body-form?)))

(add-lint :redundant-do
  {:type :special-call
   :impl (fn [server file ast]
           (let [last-body (. ast (length ast))]
             (if (and (. implicit-do-forms (tostring (. ast 1)))
                      (list? last-body)
                      (sym? (. last-body 1) :do))
                 {:range (message.ast->range server file last-body)
                  :message "redundant do"
                  :severity message.severity.WARN
                  :fix #{:title "Unwrap the expression"
                         :changes [{:range (message.ast->range server file last-body)
                                    :newText (table.concat
                                              (fcollect [i 2 (length last-body)]
                                                (view (. last-body i)))
                                              " ")}]}})))})

(add-lint :bad-unpack
  {:type :special-call
   :impl (fn [server file call]
           "an unpack call leading into an operator"
           (let [op (. call 1)
                 last (. call (length call))]
             (if (and (op? op)
                      ;; last item is an unpack call
                      (list? last)
                      (or (sym? (. last 1) :unpack)
                          (sym? (. last 1) :_G.unpack)
                          (sym? (. last 1) :table.unpack)))
                 {:range (message.ast->range server file last)
                  :message (.. "faulty unpack call: " (tostring op)
                               " isn't variadic at runtime."
                               (if (sym? op "..")
                                 (let [unpackme (view (. last 2))]
                                   (.. " Use (table.concat " unpackme
                                       ") instead of (.. (unpack " unpackme "))"))
                                 (.. " Use a loop when you have a dynamic number of "
                                     "arguments to (" (tostring op) ")")))
                  :severity message.severity.WARN
                  :fix (if (and (= (length last) 2)
                                (sym? op ".."))
                           #{:title "Replace with a call to table.concat"
                             :changes [{:range (message.ast->range server file (if (= 2 (length call)) call last))
                                        :newText (.. "(table.concat " (view (. last 2)) ")")}]})})))})

(add-lint :var-never-set
  {:type :definition
   :impl (fn [server file symbol definition]
           (if (and definition.var? (not definition.var-set))
               ;; we can't provide a quickfix for this because the hooks don't give us
               ;; the full AST of the call to var; just the LHS/RHS
               {:range (message.ast->range server file symbol)
                :message (.. "var is never set: " (tostring symbol)
                             " Consider using (local) instead of (var)")
                :severity message.severity.WARN}))})

(local op-identity-value {:+ 0 :* 1 :and true :or false :band -1 :bor 0 :.. ""})

(add-lint :op-with-no-arguments
  {:type :special-call
   :impl (fn [server file ast]
           "A call like (+) that could be replaced with a literal"
           (let [op (. ast 1)
                 identity (. op-identity-value (tostring op))]
             (if (and (op? op)
                      (= 1 (length ast))
                      (not= nil identity))
                 {:range  (message.ast->range server file ast)
                  :message (.. "write " (view identity) " instead of (" (tostring op) ")")
                  :severity message.severity.WARN
                  :fix #{:title (.. "Replace (" (tostring op) ") with " (view identity))
                         :changes [{:range (message.ast->range server file ast)
                                    :newText (view identity)}]}})))})

(add-lint :no-decreasing-comparison
  {:type :special-call
   :disabled true
   :impl (fn [server file ast]
           (let [op (. ast 1)]
             (if (or (sym? op :>) (sym? op :>=))
                 {:range  (message.ast->range server file ast)
                  :message "Use increasing operator instead of decreasing"
                  :severity message.severity.WARN
                  :fix #{:title "Reverse the comparison"
                         :changes [{:range (message.ast->range server file ast)
                                    :newText (let [new (if (sym? op :>=) (fennel.sym :<=) (fennel.sym :<))
                                                   reversed (fcollect [i (length ast) 2 -1
                                                                       &into (list (sym new))]
                                                              (. ast i))]
                                               (view reversed))}]}})))})

(λ match-reference? [ast references]
  (if (sym? ast) (?. references ast :target)
      (or (table? ast) (list? ast))
      (accumulate [ref false _ subast (pairs ast) &until ref]
        (match-reference? subast references))))

(add-lint :match-should-case
  {:type :macro-call
   :impl (fn [server {: references &as file} ast]
           (when (and (list? ast)
                      (sym? (. ast 1) :match)
                      (not (faccumulate [ref false i 3 (length ast) 2 &until ref]
                             (match-reference? (. ast i) references))))
             {:range (message.ast->range server file (. ast 1))
              :message "no pinned patterns; use case instead of match"
              :severity message.severity.WARN
              :fix #{:title "Replace match with case"
                     :changes [{:range (message.ast->range server file (. ast 1))
                                :newText "case"}]}}))})

(add-lint :inline-unpack
  {:type [:function-call :special-call]
   :impl (fn [server file call]
           "generally, values and unpack are signs that the user is trying to do
            something with multiple values. However, multiple values will get
            \"adjusted\" to one value if they don't come at the end of the call."
           (faccumulate [f nil index 2 (length call) &until f]
             (let [arg (. call index)]
               (if (and (or (op? (. call 1)) (not (special? (. call 1))))
                        (not= index (length call))
                        (list? arg)
                        (or (sym? (. arg 1) :values)
                            (sym? (. arg 1) :unpack)
                            (sym? (. arg 1) :_G.unpack)
                            (sym? (. arg 1) :table.unpack)))
                 {:range (message.ast->range server file arg)
                  :message (.. "bad " (tostring (. arg 1))
                               " call: only the first value of the multival will be used")
                  :severity message.severity.WARN}))))})

(add-lint :empty-let
  {:type :special-call
   :impl (fn [server file call]
           (case call
             (where [let* binding]
                    (sym? let* :let)
                    (fennel.sequence? binding)
                    (= 0 (length binding)))
             {:range (message.ast->range server file binding)
              :message "use do instead of let with no bindings"
              :severity message.severity.WARN
              :fix #{:title "Replace (let [] ...) with (do ...)"
                     :changes [(let [{: start} (message.ast->range server file let*)
                                     {: end} (message.ast->range server file binding)]
                                 {:range {: start : end}
                                  :newText "do"})]}}))})

(local lint-mt {:__tojson (fn [{: self} state] (dkjson.encode self state))
                :__index #(. $1 :self $2)})

(fn wrap [self]
  ;; hide `fix` field from the client
  (let [fix self.fix]
    (set self.fix nil)
    (setmetatable {: self : fix} lint-mt)))

(λ add-lint-diagnostics [server file]
  (fn run [lints ...]
    (each [_ lint (ipairs lints)]
      (when (. server.configuration.lints lint.name)
        (case (lint.impl ...)
          diagnostic
          (table.insert file.diagnostics
            (wrap (doto diagnostic
                        (tset :code lint.name))))))))

  (each [symbol definition (pairs file.definitions)]
    (when (. file.lexical symbol)
      (run lints.definition server file symbol definition)))
  (each [symbol (pairs file.references)]
    (when (. file.lexical symbol)
      (run lints.reference server file symbol)))
  (each [[head &as ast] (pairs file.calls)]
    (when (and (. file.lexical ast) (not= nil head))
      (run (if (special? head) lints.special-call lints.function-call)
          server file ast)))
  (each [ast macroexpanded (pairs file.macro-calls)]
    (when (. file.lexical ast)
      (run lints.macro-call
           server file ast macroexpanded))))

{: add-lint-diagnostics
 :list all-lints}
