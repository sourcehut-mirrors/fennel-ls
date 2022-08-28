"Language
The high level analysis system that does deep searches following
the data provided by compiler.fnl."

(local {: sym? : list? : sequence? : sym : view} (require :fennel))
(local {: table?} (require :fennel.utils))
(local utils (require :fennel-ls.utils))
(local state (require :fennel-ls.state))

(local get-ast-info utils.get-ast-info)

(local -require- (sym :require))
(local -dot- (sym :.))
(local -do- (sym :do))

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
  (match (. file.references symbol)
    to (search-assignment self file to
         (let [split (utils.multi-sym-split symbol)]
           (fcollect [i (length split) 2 -1 &into stack]
             (. split i)))))) ;; TODO test coverage for this line

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
    ; A . form  indexes into item 1 with the other items
    [-dot- & split]
    (search self file (. split 1)
      (fcollect [i (length split) 2 -1 &into stack]
        (. split i)))

    ;; A do block returns the last form
    [-do- & body]
    (search self file (. body (length body)) stack)))

(set search
  (λ search [self file item stack]
    (if
        (sym? item)               (search-symbol self file item stack)
        (list? item)              (search-list self file item stack)
        (= :table (type item))    (search-table self file item stack)
        (= 0 (length stack))      {:?definition item} ;; BASE CASE !!
        (error (.. "I don't know what to do with " (view item))))))

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

(λ find-symbol [ast byte]
  (local parents [])
  (λ recurse [ast]
    (if
      (sym? ast)
      (values ast parents)
      (do
        (table.insert parents ast)
        (if
          (or (sequence? ast) (list? ast))
          (accumulate [(result done) nil
                       i child (ipairs ast)
                       &until result]
            (if (contains? child byte)
              (recurse child byte)))
          (table? ast)
          (accumulate [(result done) nil
                       key value (pairs ast)
                       &until done]
            (if (contains? key byte)
              (recurse key byte)
              (contains? value byte)
              (recurse value byte)))))))

  (values
    (accumulate [result nil i top-level-form (ipairs ast) &until result]
      (if (contains? top-level-form byte)
        (recurse top-level-form byte)))
    parents))


{: find-symbol
 : search-main
 : search}
