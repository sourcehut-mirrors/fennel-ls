(local fennel (require :fennel))
(local insert table.insert)

;; words surrounded by - are symbols,
;; because fennel doesn't allow 'require in a runtime file
(local -require- (fennel.sym :require))
(local -local- (fennel.sym :local))
(local -fn- (fennel.sym :fn))

;; types of things in the file.references list
{:from "a literal range" :to "a literal range"}
{:from "a literal range" :to-other-module ["modname" "key1" "key2" "key3" "key4" "etc"]}

(fn table? [t]
  (= :table (type t)))

(fn multisym? [t]
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
         (fn [self key]
           (let [val {}]
             (tset self key val)
             val))})))

  (fn find-reference [name scope]
    (when scope
      (or (. scope-notes scope (tostring name))
          (find-reference name scope.parent))))

  (fn call [ast scope]
    "called for every function call. Most calls aren't interesting, but (require) and (local) are"
    (match ast
      [-local- name value]
      nil ;; not actually interesting, I pranked you
      (where [-require- mod] (= :string (type mod)))
      (insert file.references {:from ast :to-other-module [mod]})))
    ;; nothing

  (fn reference [ast scope]
    "called whenever a variable is referenced"
    (assert (fennel.sym? ast))
    (let [name (or (string.match (tostring ast) "[^%.:]+"))]
      (table.insert file.references {:from ast :to (find-reference name scope)})))

  (fn fn* [ast scope]
    (match ast
      (where [-fn- name args]
        (and (fennel.sym? name)
             (not (multisym? name))
             (table? args)))
      (tset (. scope-notes scope.parent) (tostring name) ast)))
    ;; (each [_ argument (ipairs args)]))

  (fn define [definition binding scope]
    "called whenever a local variable or destructure statement is introduced"
    (when (fennel.sym? binding) ;; for now, I am going to bury my head in the sand and ignore destructure logic
      (tset (. scope-notes scope) (tostring binding) binding)))

  (local plugin
    {:name "fennel-ls"
     :versions ["1.2.0"]
     :symbol-to-expression reference
     : call
     :fn fn*
     :destructure define})

  (fennel.compileString file.text
    {:filename file.uri
     :plugins [plugin]}))

{: analyze}
