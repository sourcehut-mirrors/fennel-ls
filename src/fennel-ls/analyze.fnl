(local fennel (require :fennel))
(local fennelutils (require :fennel.utils))
(local utils (require :fennel-ls.utils))
(local insert table.insert)

(local sym? fennel.sym?)
(local list? fennel.list?)

;; words surrounded by - are symbols,
;; because fennel doesn't allow 'require in a runtime file
(local -require- (fennel.sym :require))
(local -fn- (fennel.sym :fn))
(local -λ- (fennel.sym :λ))
(local -lambda- (fennel.sym :lambda))

(λ contains? [?ast byte]
  ;; check if an ast contains a byte
  (and (= (type ?ast) :table)
       (utils.get-ast-info ?ast :bytestart)
       (utils.get-ast-info ?ast :byteend)
       (<= (utils.get-ast-info ?ast :bytestart)
           byte
           (+ 1 (utils.get-ast-info ?ast :byteend)))))

(λ does-not-contain? [?ast byte]
  ;; check if a byte is in range of the ast
  (and (= (type ?ast) :table)
       (utils.get-ast-info ?ast :bytestart)
       (utils.get-ast-info ?ast :byteend)
       (not
         (<= (utils.get-ast-info ?ast :bytestart)
             byte
             (+ 1 (utils.get-ast-info ?ast :byteend))))))


(λ past? [?ast byte]
  ;; check if a byte is past an ast object
  (and (= (type ?ast) :table)
       (utils.get-ast-info ?ast :bytestart)
       (< byte (utils.get-ast-info ?ast :bytestart))
       false))

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

(λ analyze [file]
  "Compile the file, and record all the useful information from the compiler into the file object"

  (local references [])
  (local definitions (doto {} (setmetatable has-tables-mt)))

  (λ find-definition [name ?scope]
    (when ?scope
      (or (. definitions ?scope name)
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
    (λ recurse [binding]
      (if (fennel.sym? binding)
          (tset (. definitions scope)
                (tostring binding)
                {: binding :definition ?definition})
          (= :table (type binding))
          (each [k v (iter binding)]
           (recurse v))))
    (recurse binding))

  (λ define-function-name [ast scope]
    ;; add a function definition to the definitions
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
    ;; add the definitions of function arguments to the definitions
    (local args
      (match ast
        (where [_fn args] (fennel.sequence? args)) args
        (where [_fn _name args] (fennel.sequence? args)) args))
    (each [_ argument (ipairs args)]
      (define nil argument scope))) ;; we say function arguments are set to nil

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

  (local ast
    (icollect [ok ast (fennel.parser file.text)]
      ast))

  (local scope (fennel.scope))
  (each [_i form (ipairs ast)]
    (fennel.compile form
      {:filename file.uri
       : scope
       :plugins [plugin]}))

  ;; write things back to the file object
  (set file.references references)
  ;; (set file.definitions definitions) ;; not needed yet
  (set file.ast ast))
  ;; (set file.analyzed? true))

(var
  (search-assignment
   search-symbol
   search)
  nil)

(set search-assignment
  (λ search-assignment [self file binding ?definition stack]
    (if (= 0 (length stack))
      binding
      ;; TODO sift down the binding
      (search self file ?definition stack))))

(set search-symbol
  (λ search-symbol [self file symbol stack]
    (let [split (utils.multi-sym-split symbol)]
      (for [i (length split) 2 -1]
        (table.insert stack (. split i))))
    (match (. file.references symbol)
      to (search-assignment self file to.binding to.definition stack)
      nil nil)))

(set search
  (λ search [self file item stack]
    (if (fennelutils.table? item)
        (if (. item (. stack (length stack)))
          (search self file (. item (table.remove stack)) stack)
          nil)
        (sym? item)
        (search-symbol self file item stack)
        ;; TODO
        ;; functioncall (continue searching in body)
        ;; require call (search in the new module)
        :else (error (.. "I don't know what to do with " (fennel.view item))))))

(λ find-symbol [ast byte ?recursively-called]
  (if (not= :table (type ast))
      nil
      (does-not-contain? ast byte)
      nil
      (sym? ast)
      ast
      (or (not ?recursively-called)
          (fennel.list? ast)
          (fennel.sequence? ast))
      ;; TODO binary search
      (accumulate
        [result nil
         _ v (ipairs ast)
         &until (or result (past? v byte))]
        (find-symbol v byte true))
      :else
      (accumulate
        [result nil
         k v (pairs ast)
         &until result]
        (or
          (find-symbol k byte true)
          (find-symbol v byte true)))))

{: analyze
 : find-symbol
 : search-symbol}
