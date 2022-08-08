(local fennel      (require :fennel))
(local fennelutils (require :fennel.utils))
(local utils (require :fennel-ls.utils))
(local state (require :fennel-ls.state))

(local get-ast-info utils.get-ast-info)

(local sym? fennel.sym?)
(local list? fennel.list?)

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
    (if
      (fennelutils.table? item)
      (if (. item (. stack (length stack)))
        (search self file (. item (table.remove stack)) stack)
        nil)
      (sym? item)
      (search-symbol self file item stack)
      ;; TODO
      ;; functioncall (continue searching in body with parameters bound)
      (match item
        [-require- mod]
        (let [newfile (state.get-by-module self mod)
              newitem (. newfile.ast (length newfile.ast))]
          (print newfile.uri mod)
          (search self newfile newitem stack))
        _ (error (.. "I don't know what to do with " (fennel.view item)))))))

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
  (if (not= :table (type ast))
      nil
      (does-not-contain? ast byte)
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
 : search-symbol}
