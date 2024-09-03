"Compiler
This module is responsible for calling the actual fennel parser and compiler,
and turning it into a \"fennel-ls file object\". It creates a plugin to the
fennel compiler, and then tries to store into it gets from the fennel
compiler's plugin hook callbacks. It stores lexical info about which
identifiers are declared / referenced in which places."

(local {: sym? : list? : sequence? : table? : sym : view &as fennel} (require :fennel))
(local docs (require :fennel-ls.docs))
(local message (require :fennel-ls.message))
(local searcher (require :fennel-ls.searcher))
(local utils (require :fennel-ls.utils))

(local nil* (sym :nil))

(fn scope? [candidate]
  ;; just checking a couple of the fields
  (and
    (= (type candidate) :table)
    (= (type candidate.includes) :table)
    (= (type candidate.macros) :table)
    (= (type candidate.manglings) :table)
    (= (type candidate.specials) :table)
    (= (type candidate.gensyms) :table)))

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

(λ line+byte->range [server file line byte]
  (let [line (- line 1)
        ;; some errors in fennel erroneously say column -1
        ;; try compiling "(do\n" to see what I mean
        byte (math.max 0 byte)
        position (utils.pos->position file.text line byte server.position-encoding)]
    {:start position :end position}))

(λ compile [{:configuration {: macro-path} :root-uri ?root-uri &as server} file]
  "Compile the file, and record all the useful information from the compiler into the file object"
  ;; The useful information being recorded:
  (let [definitions-by-scope (doto {} (setmetatable has-tables-mt))
        definitions   {} ; symbol -> binding
        diagnostics   {} ; [diagnostic]
        references    {} ; symbol -> references
        macro-refs    {} ; symbol -> macro
        scopes        {} ; ast -> scope
        calls         {} ; all calls in the macro-expanded code -> true
        lexical       {} ; all lists, tables, and symbols in the original source
        require-calls {}] ; the keys are all the calls that start with `require

    (local defer [])

    (λ find-definition [name ?scope]
      (if ?scope
        (or (. definitions-by-scope ?scope name)
            (find-definition name ?scope.parent))))

    (λ reference [symbol scope ref-type]
      (assert (or (= ref-type :read) (= ref-type :write) (= ref-type :mutate)) "wrong ref-type")
      (assert (sym? symbol) :not-a-symbol)
      (assert (scope? scope) :not-a-scope)
      ;; find reference
      (let [name (string.match (tostring symbol) "[^%.:]+")]
        (case (or (find-definition (tostring name) scope)
                  (docs.get-global server name))
          target (let [ref {: symbol : target : ref-type}]
                   (tset references symbol ref)
                   (when target.referenced-by
                     (table.insert target.referenced-by ref))))))

    (λ symbol-to-expression [ast scope ?reference?]
      (assert (sym? ast) "symbols only")
      (reference ast scope (if ?reference?
                             :read
                             (not (multisym? ast))
                             :write
                             :mutate)))

    (λ for-each-binding-in [binding ?definition action]
      (λ recurse [binding keys depth]
        (if (sym? binding)
            (action binding ?definition keys keys.multival)
            (list? binding)
            (let [set-target? (sym? (. binding 1) ".")]
              (if set-target?
                  (action binding ?definition keys keys.multival)
                  (not= depth 0)
                  (error (.. "I didn't expect to find a nested multival destructure in " (view binding) " at " (view keys)))
                  (each [i child (ipairs binding)]
                    (set keys.multival i)
                    (recurse child keys (+ depth 1))
                    (set keys.multival nil))))
            (table? binding)
            (accumulate [prev nil
                         key child (iter binding)]
              (if (or (sym? key :&as) (sym? prev :&as))
                  ;; if its &as, just keep the keys the same
                  (recurse child keys (+ depth 1))
                  (or (sym? key :&) (sym? prev :&))
                  ;; currently the "rest" param is defined to []
                  (for-each-binding-in child [] action)
                  (or (sym? child :&as) (sym? child :&))
                  child
                  (do
                    (table.insert keys key)
                    (recurse child keys (+ depth 1))
                    (table.remove keys))))))
      (recurse binding [] 0))

    (λ define [?definition binding scope ?opts]
      (for-each-binding-in binding ?definition
        (fn [symbol ?definition keys ?multival]
          (when (not (or (list? symbol) (multisym? symbol)))
            (let [definition
                  {:binding symbol
                   :definition ?definition
                   :referenced-by (or (?. definitions symbol :referenced-by) [])
                   :keys (if (. keys 1)
                           (icollect [_ v (ipairs keys)] v))
                   :multival ?multival
                   :var? (?. ?opts :isvar)
                   : file}]
              (tset (. definitions-by-scope scope) (tostring symbol) definition)
              (tset definitions symbol definition))))))

    (λ mutate [?definition binding scope]
      (for-each-binding-in binding ?definition
        (fn [symbol _?definition _keys]
          (when (not (or (list? symbol) (multisym? symbol)))
            (reference symbol scope :write)
            (if (. references symbol)
              (tset (. references symbol :target) :var-set true))))))

    (λ destructure [to from scope {:declaration ?declaration? : symtype &as opts}]
      ;; I really don't understand symtype
      ;; I think I need an explanation
      (when (not= symtype :pv)
        (if ?declaration?
          (define to from scope opts)
          (mutate to from scope))))

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
             :file file}))))
             ;; ;; referenced-by inherits from all other symbols
             ;; :referenced-by (or (?. definitions multisym :referenced-by) [])}))))

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
          (define nil* argument scope)))) ;; TODO  for now, function arguments are set to nil

    (λ define-function [ast scope]
      ;; handle the definitions of a function
      (define-function-name ast scope))

    (λ compile-for [_ast scope binding]
       (define nil* binding scope))

    (λ compile-each [_ast scope bindings]
      (each [_ binding (ipairs bindings)]
        (define nil* binding scope)))

    (λ compile-fn [ast scope]
      (tset scopes ast scope)
      (define-function-args ast scope))

    (λ compile-do [ast scope]
      (tset scopes ast scope))

    (λ call [ast scope]
      "every list that is a call to a special or function"
      (tset calls ast true)
      (tset scopes ast scope)
      ;; Most calls aren't interesting, but here's the list of the ones that are:
      (let [head (. ast 1)]
        (case (and (sym? head) (tostring head))
          ;; This cannot be done through the :fn feature of the compiler plugin system
          ;; because it needs to be called *before* the body of the function is processed.
          (where :fn)
          (define-function ast scope)
          (where (or :require :include))
          (tset require-calls ast true)
          ;; fennel expands multisym calls into the `:` special, so we need to reference the symbol while we still can
          (where method-call (= (type method-call) :string) (method-call:find ":"))
          (reference head scope :read)
          ;; NOTE this should be removed once fennel makes if statements work like normal
          (where :if)
          (let [len (length ast)]
            (table.insert defer #(tset ast (+ len 1) nil))))))

    (fn macroexpand [ast _transformed scope]
      "every list that is a call to a macro"
      (let [macro-id (. ast 1)
            macro-fn (accumulate [t scope.macros
                                  _ part (ipairs (utils.multi-sym-split macro-id))]
                             (if (= (type t) :table)
                               (. t part)))]
        (when (= (type macro-fn) :function)
          (assert (sym? macro-id) "macros should be syms")
          (tset macro-refs macro-id macro-fn))))

    (λ attempt-to-recover! [msg ?ast]
      (or (= 1 (msg:find "unknown identifier"))
          (= 1 (msg:find "local %S+ was overshadowed by a special form or macro"))
          (= 1 (msg:find "expected var "))
          (= 1 (msg:find "expected local "))
          (= 1 (msg:find "cannot call literal value"))
          (= 1 (msg:find "unexpected vararg"))
          (= 1 (msg:find "expected closing delimiter"))
          (= 1 (msg:find "expected body expression"))
          (= 1 (msg:find ".*fennel/macros.fnl:%d+: expected body"))
          (= 1 (msg:find "expected condition and body"))
          (= 1 (msg:find "expected whitespace before opening delimiter"))
          (= 1 (msg:find "malformed multisym"))
          (= 1 (msg:find "expected at least one pattern/body pair"))
          (= 1 (msg:find "module not found"))
          (= 1 (msg:find "expected even number of values in table literal"))
          (= 1 (msg:find "use $%.%.%. in hashfn"))
          (when (and (= 1 (msg:find "expected even number of name/value bindings"))
                     (sequence? ?ast)
                     (= 1 (% (length ?ast) 2)))
            (table.insert ?ast nil*)
            (table.insert defer #(table.remove ?ast))
            true)
          (when (and (= 1 (msg:find "expected a function, macro, or special to call"))
                     (list? ?ast)
                     (= (length ?ast) 0))
            (table.insert ?ast (sym :do))
            (table.insert defer #(table.remove ?ast))
            true)
          (when (= 1 (msg:find "unexpected multi symbol"))
            (let [old (tostring ?ast)]
              (tset ?ast 1 "!!invalid-multi-symbol!!")
              (table.insert defer #(tset ?ast 1 old))
              true))))

    (λ on-compile-error [_ msg ast call-me-to-reset-the-compiler]
      (let [range (or (message.ast->range server file ast)
                      (line+byte->range server file 1 1))]
        (table.insert diagnostics
          {:range range
           :message msg
           :severity message.severity.ERROR
           :code 201
           :codeDescription "compiler error"}))
      (if (attempt-to-recover! msg ast)
        true
        (do
          (call-me-to-reset-the-compiler)
          (error "__NOT_AN_ERROR"))))

    (λ on-parse-error [msg _filename line byte _source call-me-to-reset-the-compiler]
      (let [line (if (= line "?") 1 line)
            range (line+byte->range server file line byte)]
        (table.insert diagnostics
          {:range range
           :message msg
           :severity message.severity.ERROR
           :code 101
           :codeDescription "parse error"}))
      (if (attempt-to-recover! msg)
        true
        (do
          (call-me-to-reset-the-compiler)
          (error "__NOT_AN_ERROR"))))

    (local allowed-globals (docs.get-all-globals server))
    (icollect [extra-global (server.configuration.extra-globals:gmatch "[^ ]+")
               &into allowed-globals]
      extra-global)

    (fn parse-ast [parser]
      (icollect [ok ast parser &until (not ok)] ast))

    ;; TODO clean up this code. It's awful now that there is error handling
    (let [macro-file? (= (file.text:sub 1 24) ";; fennel-ls: macro-file")
          plugin
          {:name "fennel-ls"
           :versions ["1.4.1" "1.4.2" "1.5.0" "1.5.1"]
           : symbol-to-expression
           : call
           : destructure
           : macroexpand
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
                :useMetadata true
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
                                {:range (line+byte->range server file 1 1)
                                 :message (.. "unrecoverable " component " error: " err)}))))

          parser (let [p (fennel.parser file.text file.uri opts)]
                   (fn _p1 [p2 p3]
                     (filter-errors :parser (xpcall #(p p2 p3) fennel.traceback))))

          ast (parse-ast parser)]

      (λ parsed [ast]
        "runs on every ast tree that was parsed"
        ;; TODO in fennel 1.5+, bug fennel#221 will be fixed, and all syms in the ast should have a bytestart
        ;; the extra check can be removed
        (if (and (sym? ast) ast.bytestart)
          (case (values (tostring ast) (file.text:sub ast.bytestart ast.bytestart))
            (where (:hashfn "#"))
            (table.insert defer #(set ast.byteend ast.bytestart))
            (where (or (:quote "'") (:quote "`")))
            (table.insert defer #(set ast.byteend ast.bytestart))
            (where (:unquote ","))
            (table.insert defer #(set ast.byteend ast.bytestart))))
        (when (or (table? ast) (list? ast) (sym? ast))
          (tset lexical ast true))
        ;; recursive call
        (when (or (table? ast) (list? ast))
          (each [k v (iter ast)]
            (parsed k)
            (parsed v)))
        (when (and (list? ast)
                   (or (sym? (. ast 1) :λ)
                       (sym? (. ast 1) :lambda)))
          (let [old-sym (. ast 1)]
            (tset ast 1 (sym :fn))
            (table.insert defer #(tset ast 1 old-sym)))))

      (parsed ast lexical)

      ;; This is bad; we have to mutate fennel.macro-path to use fennel's native macro loader
      (let [old-macro-path fennel.macro-path]
        (when ?root-uri
          (set fennel.macro-path
               (searcher.add-workspaces-to-path macro-path [?root-uri])))

        ;; compile
        (each [_i form (ipairs (if macro-file? (ast->macro-ast ast) ast))]
          (filter-errors :compiler (xpcall #(fennel.compile form opts) fennel.traceback)))

        (when ?root-uri
          (set fennel.macro-path old-macro-path)))

      (each [_ cmd (ipairs defer)]
        (cmd))

      ;; TODO make this construct an object instead of mutating the file
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
      (set file.allowed-globals allowed-globals)
      (set file.macro-refs macro-refs))))

{: compile}
