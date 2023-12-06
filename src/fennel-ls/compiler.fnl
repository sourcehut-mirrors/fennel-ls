"Compiler
This file is responsible for the low level tasks of analysis. Its main job
is to recieve a file object and run all of the basic analysis that will be used
later by fennel-ls.language to answer requests from the client."

(local {: sym? : list? : sequence? : table? : sym &as fennel} (require :fennel))
(local message (require :fennel-ls.message))
(local utils (require :fennel-ls.utils))
(local searcher (require :fennel-ls.searcher))

;; words surrounded by - are symbols,
;; because fennel doesn't allow 'require in a runtime file
(local -require- (sym :require))
(local -fn- (sym :fn))
(local -lambda- (sym :lambda))
(local -λ- (sym :λ))

(λ ast->macro-ast [ast]
  [(fennel.list (sym :eval-compiler)
                ((or table.unpack _G.unpack) ast))])

(λ multisym? [t]
  ;; check if t is a symbol with multiple parts, eg. foo.bar.baz
  (and (sym? t)
    (let [t (tostring t)]
       (or (t:find "%.")
           (t:find ":")))))

(λ iter [t]
  ;; iterate through a list, sequence, or table
  (if (or (list? t)
          (sequence? t))
    (ipairs t)
    (pairs t)))

(local has-tables-mt
  {:__index
   (λ [self key]
     (let [val {}]
       (tset self key val)
       val))})

(λ line+byte->range [self file line byte]
  (let [line (- line 1)
        ;; TODO think about this further when upstream bug #180 is fixed
        byte (math.max 0 byte)
        position (utils.pos->position file.text line byte self.position-encoding)]
    {:start position :end position}))


(λ is-values? [?ast]
  (and (list? ?ast) (= (sym :values) (. ?ast 1))))

(λ compile [{:configuration {: macro-path} : root-uri &as self} file]
  "Compile the file, and record all the useful information from the compiler into the file object"
  ;; The useful information being recorded:
  (let [definitions-by-scope (doto {} (setmetatable has-tables-mt))
        definitions   {} ; symbol -> definition
        diagnostics   {} ; [diagnostic]
        references    {} ; symbol -> references
        scopes        {} ; ast -> scope
        calls         {} ; all calls in the macro-expanded code -> true
        lexical       {} ; all lists and tables in the original source
        require-calls {}] ; the keys are all the calls that start with `require

    (λ find-definition [name ?scope]
      (when ?scope
        (or (. definitions-by-scope ?scope name)
            (find-definition name ?scope.parent))))

    (λ reference [ast scope]
      ;; Add a reference to the references
      (assert (sym? ast))
      ;; find reference
      (let [name (string.match (tostring ast) "[^%.:]+")]
        (case (find-definition (tostring name) scope)
          target
          (do
            (tset references ast target)
            (table.insert target.referenced-by ast)))))

    (λ symbol-to-expression [ast scope ?reference?]
      (when (or ?reference? (fennel.multi-sym? ast))
        (reference ast scope)))

    (λ define [?definition binding scope ?opts]
      ;; Add a definition to the definitions
      ;; recursively explore the binding (which, in the general case, is a destructuring assignment)
      ;; right now I'm not keeping track of *how* the symbol was destructured: just finding all the symbols for now.
      ;; also, there's no logic for (values)
      (λ recurse [binding keys]
        (if (sym? binding)
            (let [definition
                  {: binding
                   :definition ?definition
                   :referenced-by (or (?. definitions binding :referenced-by) [])
                   :keys (if (< 0 (length keys))
                           (fcollect [i 1 (length keys)]
                             (. keys i)))
                   :var? (?. ?opts :isvar)}]
              (tset (. definitions-by-scope scope) (tostring binding) definition)
              (tset definitions binding definition))
            (list? binding)
            (if (and (is-values? ?definition)
                     (= (length binding)
                        (- (length ?definition) 1)))
              (for [i 1 (length binding)]
                (define (. ?definition (+ i 1)) (. binding i) scope ?opts))
              (recurse (. binding 1) keys))
            (table? binding)
            (accumulate [prev nil
                         k v (iter binding)]
              (if (or (sym? k :&as) (sym? prev :&as))
                  (recurse v keys)
                  (or (sym? k :&) (sym? prev :&))
                  ;; currently the "rest" isn't counted as a binding
                  nil
                  (or (sym? v :&as) (sym? v :&))
                  v
                  (do
                    (table.insert keys k)
                    (recurse v keys)
                    (table.remove keys))))))
      (recurse binding []))

    (λ mutate [_?definition binding scope]
      ;; for now, mutating a field counts as a reference I guess
      (λ recurse [binding keys]
        (if (sym? binding)
            (let [
                  ;; ;; future work may need to care about mutations
                  ;; _mutation
                  ;; {: binding
                  ;;  :new-definition ?definition
                  ;;  :keys (if (< 0 (length keys))
                  ;;          (fcollect [i 1 (length keys)]
                  ;;            (. keys i)))}
                  name (string.match (tostring binding) "[^%.:]+")]
              (case (find-definition (tostring name) scope)
                target (if (multisym? binding)
                           (table.insert target.referenced-by binding)
                           (set target.var-set true))))
            (= :table (type binding))
            (each [k v (iter binding)]
              (table.insert keys k)
              (recurse v keys)
              (table.remove keys))))
      (recurse binding []))

    (λ destructure [to from scope {:declaration ?declaration? &as opts}]
      ;; I really don't understand symtype
      ;; I think I need an explanation
      (if ?declaration?
        (define to from scope opts)
        (mutate to from scope)))

    (λ add-field [ast multisym scope]
      "the multisym has the main name and the root name"
      (case-try (utils.multi-sym-split multisym)
        [ref field nil] ;; TODO more powerful function name metadata
        (find-definition ref scope)
        target
        (do
          (set target.fields (or target.fields {}))
          (tset target.fields field
            {:binding multisym
             :definition ast
             ;; referenced-by inherits from all other symbols
             :referenced-by (or (?. definitions multisym :referenced-by) [])}))))

    (λ define-function-name [ast scope]
      ;; add a function definition to the definitions
      (case ast
        (where [_fn name args]
          (and (sym? name)
               (sequence? args)))
        (if (multisym? name)
          (add-field ast name scope)
          (define ast name scope))))

    (λ define-function-args [ast scope]
      ;; add the definitions of function arguments to the definitions
      (local args
        (case ast
          (where [_fn args] (fennel.sequence? args)) args
          (where [_fn _name args] (fennel.sequence? args)) args
          _ []))
      (each [_ argument (ipairs args)]
        (if (not (sym? argument :&))
          (define (sym :nil) argument scope)))) ;; TODO  for now, function arguments are set to nil

    (λ define-function [ast scope]
      ;; handle the definitions of a function
      (define-function-name ast scope))

    (λ compile-for [ast scope binding]
       (define (sym :nil) binding scope))

    (λ compile-each [ast scope bindings]
      (each [_ binding (ipairs bindings)]
        (define (sym :nil) binding scope)))

    (λ compile-fn [ast scope]
      (tset scopes ast scope)
      (define-function-args ast scope))

    (λ compile-do [ast scope]
      (tset scopes ast scope))

    (λ call [ast scope]
      (tset calls ast true)
      (tset scopes ast scope)
      ;; Most calls aren't interesting, but here's the list of the ones that are:
      (case ast
        ;; This cannot be done through the :fn feature of the compiler plugin system
        ;; because it needs to be called *before* the body of the function is processed.
        ;; TODO check if hashfn needs to be here
        (where (or [(= -fn-)] [(= -lambda-)] [(= -λ-)]))
        (define-function ast scope)
        (where [(= -require-) _modname])
        (tset require-calls ast true)
        ;; fennel expands multisym calls into the `:` special, so we need to reference the symbol while we still can
        (where [sym] (multisym? sym) (: (tostring sym) :find ":"))
        (reference sym scope)))

    (λ recoverable? [msg]
      (or (= 1 (msg:find "unknown identifier"))
          (= 1 (msg:find "expected closing delimiter"))
          (= 1 (msg:find "expected body expression"))
          (= 1 (msg:find "expected whitespace before opening delimiter"))
          (= 1 (msg:find "malformed multisym"))
          (= 1 (msg:find "expected at least one pattern/body pair"))))

    (λ on-compile-error [_ msg ast call-me-to-reset-the-compiler]
      (let [range (or (message.ast->range self file ast)
                      (line+byte->range self file 1 1))]
        (table.insert diagnostics
          {:range range
           :message msg
           :severity message.severity.ERROR
           :code 201
           :codeDescription "compiler error"}))
      (if (recoverable? msg)
        true
        (do
          (call-me-to-reset-the-compiler)
          (error "__NOT_AN_ERROR"))))

    (λ on-parse-error [msg filename line byte _source call-me-to-reset-the-compiler]
      (let [line (if (= line "?") 1 line)
            range (line+byte->range self file line byte)]
        (table.insert diagnostics
          {:range range
           :message msg
           :severity message.severity.ERROR
           :code 101
           :codeDescription "parse error"}))
      (if (recoverable? msg)
        true
        (do
          (call-me-to-reset-the-compiler)
          (error "__NOT_AN_ERROR"))))

    (local allowed-globals
      (icollect [k _ (pairs _G)]
        k))
    (each [_ v (ipairs (utils.split-spaces self.configuration.extra-globals))]
      (table.insert allowed-globals v))

    ;; TODO clean up this code. It's awful now that there is error handling
    (let [macro-file? (= (file.text:sub 1 24) ";; fennel-ls: macro-file")
          plugin
          {:name "fennel-ls"
           :versions ["1.4.1"]
           : symbol-to-expression
           : call
           : destructure
           ;; :fn    fn-hook
           ;; :do    there's a do hook
           ;; :chunk I don't know what this one is
           :assert-compile on-compile-error
           :parse-error on-parse-error
           :pre-for compile-for
           :pre-each compile-each
           :pre-fn compile-fn
           :pre-do compile-do}
          scope (fennel.scope)
          opts {:filename file.uri
                :plugins [plugin]
                :allowedGlobals allowed-globals
                :requireAsInclude false
                : scope}
          filter-errors (fn _filter-errors [component ...]
                          (case ...
                            (true ?item1 ?item2) (values ?item1 ?item2)
                            (where (or (nil err) (false err)) (not (err:find "^[^\n]-__NOT_AN_ERROR\n")))
                            (if (os.getenv :TESTING)
                              (error (.. "\nYou have crashed fennel-ls (or the fennel " component ") with the following message\n:" err
                                         "\n\n^^^ the error message above here is the root problem\n\n"))
                              (table.insert diagnostics
                                {:range (line+byte->range self file 1 1)
                                 :message (.. "unrecoverable " component " error: " err)}))))

          parser (let [p (fennel.parser file.text file.uri opts)]
                   (fn _p1 [p2 p3]
                     (filter-errors :parser (xpcall #(p p2 p3) fennel.traceback))))

          ast (icollect [ok ast parser &until (not ok)] ast)]

      (λ collect-everything [ast result]
        (when (or (table? ast) (list? ast))
          (tset result ast true)
          (each [k v (iter ast)]
            (collect-everything k result)
            (collect-everything v result))))

      (collect-everything ast lexical)



      ;; This is bad; we mutate fennel.macro-path
      (let [old-macro-path fennel.macro-path]
        (set fennel.macro-path
             (searcher.add-workspaces-to-path macro-path [root-uri]))

        ;; compile
        (each [_i form (ipairs (if macro-file? (ast->macro-ast ast) ast))]
          (filter-errors :compiler (xpcall #(fennel.compile form opts) fennel.traceback)))

        (set fennel.macro-path old-macro-path))

      (set file.ast ast)
      (set file.calls calls)
      (set file.lexical lexical)
      (set file.scope scope)
      (set file.scopes scopes)
      (set file.definitions definitions)
      (set file.definitions-by-scope definitions-by-scope)
      (set file.diagnostics diagnostics)
      (set file.references references)
      (set file.require-calls require-calls)
      (set file.allowed-globals allowed-globals))))

{: compile}
