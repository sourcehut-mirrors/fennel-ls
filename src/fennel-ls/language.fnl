(local fennel      (require :fennel))
(local fennelutils (require :fennel.utils))
(local utils (require :fennel-ls.utils))
(local state (require :fennel-ls.state))

(local get-ast-info utils.get-ast-info)

(local sym? fennel.sym?)
(local list? fennel.list?)

(local -require- (fennel.sym :require))
(local -dot- (fennel.sym :.))

(var search nil) ;; all of the search functions are mutually recursive

(λ search-assignment [self file {: binding : ?definition : ?keys &as assignment} stack]
  (if (= 0 (length stack))
    (values assignment file) ;; BASE CASE!!
    (do
      (if ?keys
        (fcollect [i (length ?keys) 1 -1 &into stack]
          (. ?keys i)))
      (search self file ?definition stack))))

(λ search-symbol [self file symbol stack]
  (let [split (utils.multi-sym-split symbol)]
    (fcollect [i (length split) 2 -1 &into stack]
      (. split i))) ;; TODO test coverage for this line
  (match (. file.references symbol)
    to (search-assignment self file to stack)))

(λ search-table [self file tbl stack]
  (if (. tbl (. stack (length stack)))
      (search self file (. tbl (table.remove stack)) stack)
      (= 0 (length stack))
      (values {:?definition tbl} file) ;; BASE CASE !!
      nil)) ;; BASE CASE Give up

(λ search-list [self file call stack]
  (match call
    [-require- mod]
    (let [newfile (state.get-by-module self mod)
          newitem (. newfile.ast (length newfile.ast))]
      (search self newfile newitem stack))
    [-dot- & split]
    (do
      (fcollect [i (length split) 2 -1 &into stack]
        (. split i))
      (search self file (. split 1) stack))))

(set search
  (λ search [self file item stack]
    (if (fennelutils.table? item) (search-table self file item stack)
        (sym? item)               (search-symbol self file item stack)
        (list? item)              (search-list self file item stack)
        (= 0 (length stack))      {:?definition item} ;; BASE CASE !!
        (error (.. "I don't know what to do with " (fennel.view item))))))

(λ search-main [self file symbol]
  ;; TODO partial byting, go to different defitition sites depending on which section of the symbol the trigger happens on

  ;; The stack is the multi-sym parts still to search
  ;; for example, if I'm searching for "foo.bar.baz", my "item" or "symbol" is foo,
  ;; and the stack has ["baz" "bar"], with "bar" at the "top"/"end" of the stack as the next key to search.
  (local stack
    (let [split (utils.multi-sym-split symbol)]
      (fcollect [i (length split) 2 -1]
        (. split i))))
  (match (values (. file.references symbol) (. file.definitions symbol))
    (ref _)
    (search-assignment self file ref stack)
    (_ def)
    (do
      (if def.?keys
        (fcollect [i (length def.?keys) 1 -1 &into stack]
          (. def.?keys i)))
      (search self file def.?definition stack))))
      ;; (search self file def.?definition stack))))

(λ past? [?ast byte]
  ;; check if a byte is past an ast object
  (and (= (type ?ast) :table)
       (get-ast-info ?ast :bytestart)
       (< byte (get-ast-info ?ast :bytestart))
       false))

(λ contains? [?ast byte]
  ;; check if an ast contains a byte
  (and (= (type ?ast) :table)
       (get-ast-info ?ast :bytestart)
       (get-ast-info ?ast :byteend)
       (<= (get-ast-info ?ast :bytestart)
           byte
           (+ 1 (utils.get-ast-info ?ast :byteend)))))

(λ does-not-contain? [?ast byte]
  ;; check if a byte is in range of the ast
  (and (= (type ?ast) :table)
       (get-ast-info ?ast :bytestart)
       (get-ast-info ?ast :byteend)
       (not
         (<= (get-ast-info ?ast :bytestart)
             byte
             (+ 1 (get-ast-info ?ast :byteend))))))

(λ find-symbol [ast byte ?recursively-called]
  (if (or (not= :table (type ast))
          (does-not-contain? ast byte))
      nil
      (and (sym? ast) (contains? ast byte))
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

{: find-symbol
 : search-main}
