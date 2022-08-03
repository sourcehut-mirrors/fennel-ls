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

(λ multisym? [t]
  (and (fennel.sym? t)
    (let [t (tostring t)]
       (or (t:find "%.")
           (t:find ":")))))


(λ analyze [file]
  (assert file.text (fennel.view file))
  (assert file.uri)
  (set file.references [])

  (local scope-notes
    (doto {}
      (setmetatable
        {:__index
         (λ [self key]
           (let [val {}]
             (tset self key val)
             val))})))

  (λ find-reference [name ?scope]
    (when ?scope
      (or (. scope-notes ?scope (tostring name))
          (find-reference name ?scope.parent))))

  (λ reference [ast scope]
    "called whenever a variable is referenced"
    (assert (fennel.sym? ast))
    (let [name (string.match (tostring ast) "[^%.:]+")]
      (table.insert file.references {:from ast :to (find-reference name scope)})))

  (λ define [?definition binding scope]
    "called whenever a local variable or destructure statement is introduced"
    (when (fennel.sym? binding) ;; for now, I am going to bury my head in the sand and ignore destructure logic
      (tset (. scope-notes scope) (tostring binding) binding)))

  (λ define-function-name [ast scope]
    (match ast
      (where [_fn name args]
        (and (fennel.sym? name)
             (not (multisym? name)) ;; not dealing with multisym for now
             (fennel.sequence? args)))
      (tset (. scope-notes scope.parent) (tostring name) ast)))

  (λ define-function-args [ast scope]
    (local args
      (match ast
        (where [_fn args] (fennel.sequence? args)) args
        (where [_fn _name args] (fennel.sequence? args)) args))
    (each [_ argument (ipairs args)]
      (define nil argument scope))) ;; we say arguments are bound to "nil" for now

  (λ define-function [ast scope]
    "Introduces the various symbols exported by a function.
This cannot be done through the :fn feature of the compiler plugin system, because it needs to be
called before the body of the function happens"
    (define-function-name ast scope)
    (define-function-args ast scope))

  (λ call [ast scope]
    "called for every function call. Most calls aren't interesting, but (require) and (local) are"
    (match ast
      (where [-require- mod] (= :string (type mod)))
      (insert file.references {:from ast :to-other-module [mod]})
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

  (pcall fennel.compileString file.text
    {:filename file.uri
     :plugins [plugin]}))

{: analyze}
