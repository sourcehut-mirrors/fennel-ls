(local fennel (require :fennel))

;; words surrounded by - are symbols,
;; because fennel doesn't allow 'require in a runtime file
(local -require- (fennel.sym :require))
(local -fn- (fennel.sym :fn))
(local -λ- (fennel.sym :λ))
(local -lambda- (fennel.sym :lambda))


(λ multisym? [t]
  ;; check if t is a symbol with multiple parts, eg. foo.bar.baz
  (and (fennel.sym? t)
    (let [t (tostring t)]
       (or (t:find "%.")
           (t:find ":")))))

(λ iter [t]
  ;; iterate through a list, sequence, or table
  (if (or (fennel.list? t)
          (fennel.sequence? t))
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

  (local references {})
  (local definitions-by-scope (doto {} (setmetatable has-tables-mt)))
  (local definitions {})

  (λ find-definition [name ?scope]
    (when ?scope
      (or (. definitions-by-scope ?scope name)
          (find-definition name ?scope.parent))))

  (λ reference [ast scope]
    ;; Add a reference to the references
    (assert (fennel.sym? ast))
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
      (if (fennel.sym? binding)
          (let [definition
                {: binding
                 : ?definition
                 :?keys (fcollect [i 1 (length keys)]
                          (. keys i))}]
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
        (and (fennel.sym? name)
             (not (multisym? name)) ;; not dealing with multisym for now
             (fennel.sequence? args)))
      (tset (. definitions-by-scope scope) ;; !!! parent or child?
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
      (define-function ast scope)))

  (local plugin
    {:name "fennel-ls"
     :versions ["1.2.0"]
     :symbol-to-expression reference
     :call call
     :destructure define})

  (local filename file.uri)
  (local ast
    (icollect [ok ast (fennel.parser file.text filename)]
      ast))

  (local scope (fennel.scope))
  (each [_i form (ipairs ast)]
    (fennel.compile form
      {: filename
       : scope
       :plugins [plugin]}))

  ;; write things back to the file object
  (set file.references references)
  (set file.definitions definitions)
  ;; (set file.definitions-by-scope definitions-by-scope) ;; not needed yet
  (set file.ast ast))
  ;; (set file.compiled? true))
{: compile}
