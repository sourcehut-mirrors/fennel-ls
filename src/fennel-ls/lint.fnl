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

(fn diagnostic [self]
  (let [fix self.fix]
    (set self.fix nil)
    (setmetatable {: self : fix} diagnostic-mt)))

(local lints {:definition []
              :reference []
              :macro-call []
              :function-call []
              :special-call []
              :file []})

(local all-lints [])

(fn add-lint [code lint]
  (set lint.name code)
  (table.insert all-lints lint)
  (if (= (type lint.type) :table)
    (each [_ t (ipairs lint.type)]
      (table.insert (. lints t) lint))
    (table.insert (. lints lint.type) lint)))

(fn could-be-rewritten-as-sym? [str]
  (and (= :string (type str)) (not (str:find "^%d"))
       (not (str:find "[^!$%*+/0-9<=>?A-Z\\^_a-z|\128-\255-]"))))


(add-lint :unused-definition
  {:type :definition
   :enabled true
   :impl (λ [server file symbol definition]
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
                :code :unused-definition
                :fix #{:title (.. "Replace " (tostring symbol) " with _" (tostring symbol))
                       :changes [{:range (message.ast->range server file symbol)
                                  :newText (.. "_" (tostring symbol))}]}})))})

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

(add-lint :unknown-module-field
  {:type :file
   :enabled true
   :impl (λ [server file]
           "any multisym whose definition can't be found through a (require) call"
           (icollect [symbol (pairs file.references) &into file.diagnostics]
             (if (. (utils.multi-sym-split symbol) 2)
                 (module-field-helper server file symbol symbol)))

           (icollect [symbol binding (pairs file.definitions) &into file.diagnostics]
             (if binding.keys
                 (module-field-helper server file symbol binding.definition
                                      (fcollect [i (length binding.keys) 1 -1]
                                        (. binding.keys i))))))})

(add-lint :unnecessary-method
  {:type :special-call
   :enabled true
   :impl (λ [server file colon call]
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
                  :code :unnecessary-method}))))})

(add-lint :unnecessary-tset
  {:type :special-call
   :enabled true
   :impl (λ [server file head call]
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
                            :code :unnecessary-tset
                            :fix #{:title "Replace tset with set"
                                   :changes [{:range (message.ast->range server file call)
                                              :newText (make-new-text call)}]}})))})

(add-lint :unnecessary-do-values
  {:type :special-call
   :enabled true
   :impl (λ [server file head call]
           (if (and (or (sym? head :do) (sym? head :values))
                    (= nil (. call 3)) (. file.lexical call))
               (diagnostic {:range (message.ast->range server file call)
                            :message (.. "unnecessary " (tostring head))
                            :severity message.severity.WARN
                            :code :unnecessary-do-values
                            :fix #{:title "Unwrap the expression"
                                   :changes [{:range (message.ast->range server file call)
                                              :newText (view (. call 2))}]}})))})

(local implicit-do-forms (collect [form {: body-form?} (pairs (fennel.syntax))]
                           (values form body-form?)))

(add-lint :redundant-do
  {:type :special-call
   :enabled true
   :impl (λ [server file head call]
           (let [last-body (. call (length call))]
             (if (and (. implicit-do-forms (tostring head))
                      (. file.lexical call)
                      (list? last-body)
                      (sym? (. last-body 1) :do)
                      (not (and (sym? head :do) (= 3 (length call))))) ;; we don't want two lints to trigger for same call
                 (diagnostic {:range (message.ast->range server file last-body)
                              :message "redundant do"
                              :severity message.severity.WARN
                              :code :redundant-do
                              :fix #{:title "Unwrap the expression"
                                     :changes [{:range (message.ast->range server file last-body)
                                                :newText (table.concat
                                                          (fcollect [i 2 (length last-body)]
                                                            (view (. last-body i)))
                                                          " ")}]}}))))})

(add-lint :bad-unpack
  {:type :special-call
   :enabled true
   :impl (λ [server file op call]
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
                  :code :bad-unpack
                  :fix (if (and (= (length last-item) 2)
                                (sym? op ".."))
                           #{:title "Replace with a call to table.concat"
                             :changes [{:range (message.ast->range server file (if (= 2 (length call)) call last-item))
                                        :newText (.. "(table.concat " (view (. last-item 2)) ")")}]})}))))})

(add-lint :var-not-set
  {:type :definition
   :enabled true
   :impl (λ [server file symbol definition]
           (if (and definition.var? (not definition.var-set) (. file.lexical symbol))
               ;; we can't provide a quickfix for this because the hooks don't give us
               ;; the full AST of the call to var; just the LHS/RHS
               (diagnostic {:range (message.ast->range server file symbol)
                            :message (.. "var is never set: " (tostring symbol)
                                         " Consider using (local) instead of (var)")
                            :severity message.severity.WARN
                            :code :var-never-set})))})

(local op-identity-value {:+ 0 :* 1 :and true :or false :band -1 :bor 0 :.. ""})

(add-lint :op-with-no-arguments
  {:type :special-call
   :enabled true
   :impl (λ [server file op call]
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
                  :code :op-with-no-arguments
                  :fix #{:title (.. "Replace (" (tostring op) ") with " (view identity))
                         :changes [{:range (message.ast->range server file call)
                                    :newText (view identity)}]}}))))})

(add-lint :no-decreasing-comparison
  {:type :special-call
   :enabled false
   :impl (λ [server file op call]
           (if (or (sym? op :>) (sym? op :>=))
               (diagnostic
                {:range  (message.ast->range server file call)
                 :message "Use increasing operator instead of decreasing"
                 :severity message.severity.WARN
                 :code :no-decreasing-comparison
                 :fix #{:title "Reverse the comparison"
                        :changes [{:range (message.ast->range server file call)
                                   :newText (let [new (if (sym? op :>=) (fennel.sym :<=) (fennel.sym :<))
                                                  reversed (fcollect [i (length call) 2 -1
                                                                      &into (list (sym new))]
                                                             (. call i))]
                                              (view reversed))}]}})))})

(λ match-reference? [ast references]
  (if (sym? ast) (?. references ast :target)
      (or (table? ast) (list? ast))
      (accumulate [ref false _ subast (pairs ast) &until ref]
        (match-reference? subast references))))

(add-lint :match-should-case
  {:type :macro-call
   :enabled true
   :impl (λ [server {: references &as file} ast]
           (when (and (list? ast)
                      (sym? (. ast 1) :match)
                      (not (faccumulate [ref false i 3 (length ast) 2 &until ref]
                             (match-reference? (. ast i) references))))
             (diagnostic {:range (message.ast->range server file (. ast 1))
                          :message "no pinned patterns; use case instead of match"
                          :severity message.severity.WARN
                          :code :match-should-case
                          :fix #{:title "Replace match with case"
                                 :changes [{:range (message.ast->range server file (. ast 1))
                                            :newText "case"}]}})))})

(add-lint :inline-unpack
  {:type [:function-call :special-call]
   :enabled true
   :impl (λ [server file fun call]
           "generally, values and unpack are signs that the user is trying to do
            something with multiple values. However, multiple values will get
            \"adjusted\" to one value if they don't come at the end of the call."
           (faccumulate [f nil index 2 (length call) &until f]
             (let [arg (. call index)]
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
                  :code :inline-unpack}))))})

(add-lint :empty-let
  {:type :special-call
   :enabled true
   :impl (λ [server file _ call]
           (case call
             (where [let* binding]
                    (. file.lexical call)
                    (sym? let* :let)
                    (fennel.sequence? binding)
                    (= 0 (length binding)))
             (diagnostic {:range (message.ast->range server file binding)
                          :message "use do instead of let with no bindings"
                          :severity message.severity.WARN
                          :code :empty-let
                          :fix #{:title "Replace (let [] ...) with (do ...)"
                                 :changes [(let [{: start} (message.ast->range server file let*)
                                                 {: end} (message.ast->range server file binding)]
                                             {:range {: start : end}
                                              :newText "do"})]}})))})

(λ add-lint-diagnostics [server file]
  (each [_ lint (ipairs lints.file)]
    (when (. server.configuration.lints lint.name)
      (lint.impl server file)))
  (each [symbol definition (pairs file.definitions)]
    (when (. file.lexical symbol)
      (each [_ lint (ipairs lints.definition)]
        (when (. server.configuration.lints lint.name)
          (table.insert file.diagnostics (lint.impl server file symbol definition))))))
  (each [symbol (pairs file.references)]
    (when (. file.lexical symbol)
      (each [_ lint (ipairs lints.reference)]
        (when (. server.configuration.lints lint.name)
          (table.insert file.diagnostics (lint.impl server file symbol))))))
  (each [[head &as ast] (pairs file.calls)]
    (when (and (. file.lexical ast) (not= nil head))
      (each [_ lint (ipairs (if (special? head)
                                lints.special-call
                                lints.function-call))]
        (when (and (. server.configuration.lints lint.name)
                   (or (not lint.target) (sym? head lint.target)))
          (table.insert file.diagnostics (lint.impl server file head ast))))))
  (each [[head &as ast] macroexpanded (pairs file.macro-calls)]
    (when (. file.lexical ast)
      (each [_ lint (ipairs lints.macro-call)]
        (when (and (. server.configuration.lints lint.name)
                   (or (not lint.target) (sym? head lint.target)))
          (table.insert file.diagnostics (lint.impl server file ast macroexpanded)))))))

{: add-lint-diagnostics
 :list all-lints}
