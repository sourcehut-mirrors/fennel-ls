(local {: sym? : list? : sequence? : sym : view &as fennel} (require :fennel))
(local message (require :fennel-ls.message))

;; words surrounded by - are symbols,
;; because fennel doesn't allow 'require in a runtime file
(local -require- (sym :require))
(local -fn- (sym :fn))
(local -λ- (sym :λ))
(local -lambda- (sym :lambda))


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

(λ compile [file]
  "Compile the file, and record all the useful information from the compiler into the file object"
  (let [definitions-by-scope (doto {} (setmetatable has-tables-mt))
        definitions   {}
        diagnostics   {}
        references    {}
        require-calls {}]

    (λ find-definition [name ?scope]
      (when ?scope
        (or (. definitions-by-scope ?scope name)
            (find-definition name ?scope.parent))))

    (λ reference [ast scope]
      ;; Add a reference to the references
      (assert (sym? ast))
      ;; find reference
      (let [name (string.match (tostring ast) "[^%.:]+")
            target (find-definition (tostring name) scope)]
        (tset references ast target)))

    (λ define [?definition binding scope]
      ;; Add a definition to the definitions
      ;; recursively explore the binding (which, in the general case, is a destructuring assignment)
      ;; right now I'm not keeping track of *how* the symbol was destructured: just finding all the symbols for now.
      ;; also, there's no logic for (values)
      (λ recurse [binding keys]
        (if (sym? binding)
            (let [definition
                  {: binding
                   : ?definition
                   :?keys (if (not= 0 (length keys))
                            (fcollect [i 1 (length keys)]
                              (. keys i)))}]
              (tset (. definitions-by-scope scope) (tostring binding) definition)
              (tset definitions binding definition))
            (= :table (type binding))
            (each [k v (iter binding)]
              (table.insert keys k)
              (recurse v keys)
              (table.remove keys))))
      (recurse binding []))

    (λ define-function-name [ast scope]
      ;; add a function definition to the definitions
      (match ast
        (where [_fn name args]
          (and (sym? name)
               (not (multisym? name)) ;; not dealing with multisym for now
               (sequence? args)))
        (tset (. definitions-by-scope scope) ;; !!! TODO somehow insert into child scope
              (tostring name)
              {:binding name
               :?definition ast})))

    (λ define-function-args [ast scope]
      ;; add the definitions of function arguments to the definitions
      (local args
        (match ast
          (where [_fn args] (fennel.sequence? args)) args
          (where [_fn _name args] (fennel.sequence? args)) args))
      (each [_ argument (ipairs args)]
        (define nil argument scope))) ;; we say function arguments are set to nil ;; !!! parent or child?

    (λ define-function [ast scope]
      ;; handle the definitions of a function
      (define-function-name ast scope)
      (define-function-args ast scope))

    (λ call [ast scope]
      ;; handles every function call
      ;; Most calls aren't interesting, but here's the list of the ones that are:
      (match ast
        ;; This cannot be done through the :fn feature of the compiler plugin system
        ;; because it needs to be called *before* the body of the function is processed.
        ;; TODO check if hashfn needs to be here
        [-fn-]
        (define-function ast scope)
        [-λ-]
        (define-function ast scope)
        [-lambda-]
        (define-function ast scope)
        [-require- modname]
        (tset require-calls ast true)))

    (λ on-compiler-error [_ msg ast call-me-to-reset-the-compiler]
      (let [range (message.ast->range ast file)]
        (table.insert diagnostics
          {:range range
           :message msg
           :severity 3
           :code 201
           :codeDescription "compiler error"}))
      (call-me-to-reset-the-compiler)
      (error "__NOT_AN_ERROR"))

    ;; TODO clean up this code. It's awful now that there is error handling
    (let
      [plugin
       {:name "fennel-ls"
        :versions ["1.2.0"]
        :symbol-to-expression reference
        :call call
        :destructure define
        :assert-compile on-compiler-error}]

      ;; ATTEMPT TO PARSE AST
      (match (pcall
               #(icollect [ok ast (fennel.parser file.text file.uri {:plugins [plugin]})]
                  ast))
        ;; ON SUCCESS
        (true ast)
        (let [scope (fennel.scope)]
          (each [_i form (ipairs ast)]
            ;; COMPILE
            (match (pcall fennel.compile form {:filename file.uri : scope :plugins [plugin]})
              (where (nil err) (not= err "__NOT_AN_ERROR"))
              (error err)))
          (set file.ast ast))
        ;; ON FAILURE
        (false err)
        ;; RECORD THE FAILURE
        (table.insert diagnostics
          {:range (message.pos->range 0 0 0 0)
           :message err}))


      ;; write things back to the file object
      ;; (set file.definitions-by-scope definitions-by-scope) ;; not needed yet
      (set file.definitions definitions)
      (set file.diagnostics diagnostics)
      (set file.references references)
      (set file.require-calls require-calls))))
    ;; (set file.compiled? true))
{: compile}
