(local fennel (require :fennel))
(local insert table.insert)

;; words surrounded by - are symbols,
;; because fennel doesn't allow 'require in a runtime file
(local -require- (fennel.sym :require))
(local -fn- (fennel.sym :fn))
(local -λ- (fennel.sym :λ))
(local -lambda- (fennel.sym :lambda))

;; types of things in the file.references list
{:from "a literal range" :to "a literal range"}
{:from "a literal range" :to-other-module ["modname" "key1" "key2" "key3" "key4" "etc"]}

(λ table? [t]
  (= :table (type t)))

(λ string? [t]
  (= :string (type t)))

(λ multisym? [t]
  (and (fennel.sym? t)
    (let [t (tostring t)]
       (or (t:find "%.")
           (t:find ":")))))

(λ iter [t]
  (if (or (fennel.list? t)
          (fennel.sequence? t))
    (ipairs t)
    (pairs t)))


(λ analyze [file]
  (assert file.text (fennel.view file))
  (assert file.uri)
  (set file.references [])

  (local definitions
    (doto {}
      (setmetatable
        {:__index
         (λ [self key]
           (let [val {}]
             (tset self key val)
             val))})))

  (λ find-variable [name ?scope]
    (when ?scope
      (or (. definitions ?scope name)
          (find-variable name ?scope.parent))))

  (λ reference [ast scope]
    "called whenever a variable is referenced"
    (assert (fennel.sym? ast))
    ;; find reference
    (let [name (string.match (tostring ast) "[^%.:]+")
          target (find-variable (tostring name) scope)]
      (tset file.references ast target)))

  (λ define [?definition binding scope]
    "called whenever a local variable or destructure statement is introduced"
    ;; right now I'm not keeping track of *how* the symbol was destructured: just finding all the symbols for now.
    (λ recurse [binding]
      (if (fennel.sym? binding)
        (tset (. definitions scope)
              (tostring binding)
              {: binding :definition ?definition})
        (table? binding)
        (each [k v (iter binding)]
         (recurse v))))
    (recurse binding))

  (λ define-function-name [ast scope]
    (match ast
      (where [_fn name args]
        (and (fennel.sym? name)
             (not (multisym? name)) ;; not dealing with multisym for now
             (fennel.sequence? args)))
      (tset (. definitions scope.parent)
            (tostring name)
            {:binding name
             :definition ast})))

  (λ define-function-args [ast scope]
    (local args
      (match ast
        (where [_fn args] (fennel.sequence? args)) args
        (where [_fn _name args] (fennel.sequence? args)) args))
    (each [_ argument (ipairs args)]
      (define nil argument scope))) ;; we say function arguments are "nil" for now

  (λ define-function [ast scope]
    "Introduces the various symbols exported by a function.
This cannot be done through the :fn feature of the compiler plugin system, because it needs to be
called *before* the body of the function is processed."
    (define-function-name ast scope)
    (define-function-args ast scope))

  (λ call [ast scope]
    "called for every function call. Most calls aren't interesting, but fn is"
    (match ast
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
     : call
     :destructure define})

  (set file.ast (icollect [ok ast (fennel.parser file.text)]
                 ast))
  (local scope (fennel.scope))
  (each [_i form (ipairs file.ast)]
    (fennel.compile form
      {:filename file.uri
       : scope
       :plugins [plugin]})))

{: analyze}
