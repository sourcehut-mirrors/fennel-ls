"Analyzer
This module is for searching through the data provided by compiler.fnl.
It searches through a file to find information about symbols that appear
in the file.

Imagine you have the following code.
```fnl
(local x 10)
(local y x)
(local z y)
z
```
Fennel-ls needs to know that x and y and z are 10. To do this, fennel-ls
doesn't forward propagate the \"type\" of x and y and z on compile, as you
might expect. Instead, any time information about x or y or z is needed, it
recursively traverses the definitions backward, until it finds the definition.

As of now, there's no caching, but that could be a way to improve performance.

The type of the result of search will be:
# A failure: `nil`
The search failed, and encountered something that isn't implemented.

# A definition: `{:definition _ :file _}`
The search succeeded and found a file with a user definition of a value.

# A document: `{:metadata {:fnl/docstring _ :fnl/arglist ?_} :fields ?{<key> <document>}}`
A document is a definition that doesn't come from user code. For example,
searching `table.insert` will find a document, but that info does not come from
a user-written file.

# A binding (if opts.stop-early?): `{:definition _ :file _ :binding _ :multival ?_ :keys ?_ :referenced-by ?_ :var? ?true :fields ?extra_fields}`
If you set the option `opts.stop-early?`, search may stop at a binding instead
of a true definition. A binding is a place where an identifier gets introduced.

In the code example above, a search on the final symbol `z` would normally
find the definition `10`, but if `opts.stop-early?` is set, it would find
{:binding z :definition y}, referring to the `(local z y)` binding.
"

(local {: sym? : list? : sequence? : varg?} (require :fennel))
(local utils (require :fennel-ls.utils))
(local files (require :fennel-ls.files))
(local docs (require :fennel-ls.docs))

(local get-ast-info utils.get-ast-info)

(var search-multival nil) ;; all of the search functions are mutually recursive

(λ stack-add-keys! [stack ?keys]
  "add the keys to the end of the stack in reverse order"
  (when ?keys
    (fcollect [i (length ?keys) 1 -1 &into stack]
      (. ?keys i)))
  stack)

(λ stack-add-split! [stack split]
  "add the split values to the end of the stack in reverse order"
  (fcollect [i (length split) 2 -1 &into stack]
    (. split i))
  stack)

(λ stack-add-multisym! [stack symbol]
  "add the multisy values to the end of the stack in reverse order"
  (stack-add-split! stack (utils.multi-sym-split symbol)))

(λ search-document [server document stack opts]
  (when (not= (tostring (?. document :binding)) :_G)
    (set opts.searched-through-require-with-stack-size-1 true))
  (if (= 0 (length stack))
    document
    (and document.fields
         (. document.fields (. stack (length stack))))
    (search-document server (. document.fields (table.remove stack)) stack opts)
    (not document.fields)
    (do
      (set opts.searched-through-require-indeterminate true))))

(λ search-val [server file ?ast stack opts]
  "searches for the definition of the ast, adjusted to 1 value"
  (search-multival server file ?ast stack 1 opts))

(λ search-assignment [server file assignment stack opts]
  (let [{:target {:binding _
                  :definition ?definition
                  :keys ?keys
                  :multival ?multival
                  :fields ?fields}} assignment]
    (when (and (= 0 (length stack))
               opts.save-last-binding)
      (tset opts.save-last-binding 1 assignment.target))
    (if (and (= 0 (length stack)) opts.stop-early?)
        assignment.target ;; BASE CASE!!
        ;; search a virtual field from :fields
        (and (not= 0 (length stack)) (?. ?fields (. stack (length stack))))
        (search-assignment server file {:target (. ?fields (table.remove stack))} stack opts)
        (search-multival server file ?definition (stack-add-keys! stack ?keys) (or ?multival 1) opts))))

(λ search-reference [server file ref stack opts]
  (if ref.target.metadata
     (search-document server ref.target stack opts)
     ref.target.binding
     (search-assignment server file ref stack opts)))

(λ search-symbol [server file symbol stack opts]
  (if (= (tostring symbol) :nil)
    (if (= 0 (length stack))
      {:definition symbol : file}
      nil)
    (if (. file.references symbol)
      (search-reference server file (. file.references symbol) (stack-add-multisym! stack symbol) opts))))

(λ search-table [server file tbl stack opts]
  (if (. tbl (. stack (length stack)))
      (search-val server file (. tbl (table.remove stack)) stack opts)
      nil)) ;; BASE CASE Give up

(λ search-list [server file call stack multival opts]
  (let [head (. call 1)]
    (if (sym? head)
      (case (tostring head)
        (where (or :do :let))
        (search-multival server file (. call (length call)) stack multival opts)
        :values
        (let [len (- (length call) 1)]
          (if (< multival len)
            (search-val server file (. call (+ 1 multival)) stack opts)
            (search-multival server file (. call (+ len 1)) stack (+ multival (- len) 1) opts)))
        (where (or :require :include))
        (let [mod (. call 2)]
          (if (= multival 1)
            (when (= :string (type mod))
              (let [newfile (files.get-by-module server mod)]
                (when newfile
                  (let [newitem (. newfile.ast (length newfile.ast))]
                    (when (= (length stack) 1)
                      (set opts.searched-through-require-with-stack-size-1 true))
                    (search-val server newfile newitem stack opts)))))))
        "."
        (if (= multival 1)
          (let [[_ & rest] call]
            (search-val server file (. call 2) (stack-add-split! stack rest) opts)))
        ;; TODO assume-function-name analyze-metatable
        :setmetatable
        (search-val server file (. call 2) stack opts)

        (where (or :fn :lambda :λ))
        (if (and (= multival 1) (= 0 (length stack)))
          {:definition call : file}) ;; BASE CASE !!
        ;; TODO expand-macros

        _
        (if (and (= multival 1) (= 0 (length stack)))
          {:definition call : file}))))) ;; BASE CASE!!

(set search-multival
  (λ [server file ?ast stack multival opts]
    (let [ast ?ast] ;; it was a bad idea to use λ because ast may be nil
      (if (list? ast)     (search-list server file ast stack multival opts)
          (varg? ast)     nil ;; TODO function-args
          (= 1 multival)
          (if (sym? ast)            (search-symbol server file ast stack opts)
              (= 0 (length stack))  {:definition ast : file} ;; BASE CASE !!
              (= :table (type ast)) (search-table server file ast stack opts)
              (= :string (type ast)) (search-document server (docs.get-global server :string) stack opts))
          nil))))


(local {:metadata METADATA} (require :fennel.compiler))
;; the options thing is getting out of hand
(λ search-main [server file symbol opts initialization-opts]
  "Find the definition of a symbol"

  (assert (= (type initialization-opts) :table))
  ;; The stack is the multi-sym parts still to search
  ;; for example, if I'm searching for "foo.bar.baz", my immediate priority is to find foo,
  ;; and the stack has ["baz" "bar"]. "bar" is at the "top"/"end" of the stack as the next key to search.
  (if (sym? symbol)
    (let [stack
          (if initialization-opts.stack
              initialization-opts.stack
              (let [?byte initialization-opts.byte
                    split (utils.multi-sym-split symbol (if ?byte (- ?byte symbol.bytestart)))]
                (stack-add-split! [] split)))]
      (case (docs.get-builtin server (utils.multi-sym-base symbol))
        document (search-document server document stack opts)
        _ (case (. file.references symbol)
            ref (search-reference server file ref stack opts)
            _ (case (. file.definitions symbol)
                def (search-multival server file def.definition (stack-add-keys! stack def.keys) (or def.multival 1) opts)
                _ (case (. file.macro-refs symbol)
                    ref {:binding symbol :metadata (. METADATA ref)})))))))

(λ find-local-definition [file name ?scope]
  (when ?scope
    (case (. file.definitions-by-scope ?scope name)
      definition definition
      _ (find-local-definition file name ?scope.parent))))

(λ search-name-and-scope [server file name scope ?opts]
  "find a definition just from the name of the item, and the scope it is in"
  (assert (= (type name) :string))
  (let [split (utils.multi-sym-split name)
        stack (stack-add-split! [] split)
        opts (or ?opts {})]
    (case (docs.get-builtin server (. split 1))
      metadata (search-document server metadata stack opts)
      _ (case (docs.get-global server (. split 1))
          metadata (search-document server metadata stack opts)
          _ (case (find-local-definition file name scope)
              def (search-val server file def.definition (stack-add-keys! stack def.keys) opts))))))

(λ _past? [?ast byte]
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

(λ _does-not-contain? [?ast byte]
  ;; check if a byte is in range of the ast
  (and (= (type ?ast) :table)
       (get-ast-info ?ast :bytestart)
       (get-ast-info ?ast :byteend)
       (not
         (<= (get-ast-info ?ast :bytestart)
             byte
             (+ 1 (get-ast-info ?ast :byteend))))))

(λ find-symbol [ast byte]
  "tries to find a sym, and a list of all of its parents/grandparents"
  (local parents [ast])
  (λ recurse [ast]
    (if
      (sym? ast)
      (values ast parents)
      (do
        (table.insert parents ast)
        (if
          (or (sequence? ast) (list? ast))
          (accumulate [(result _parent) nil
                       _ child (ipairs ast)
                       &until result]
            (if (contains? child byte)
              (recurse child byte)))
          (and (not (sym? ast)) (not (varg? ast)))
          (accumulate [(result _parent) nil
                       key value (pairs ast)
                       &until result]
            (if (contains? key byte)
              (recurse key byte)
              (contains? value byte)
              (recurse value byte)))))))
  (values
    (accumulate [result nil _ top-level-form (ipairs ast) &until result]
      (if (contains? top-level-form byte)
        (recurse top-level-form byte)))
    (fcollect [i 1 (length parents)]
      (. parents (- (length parents) i -1)))))

(λ find-nearest-definition [server file symbol ?byte]
  (if (. file.definitions symbol)
    (. file.definitions symbol)
    (search-main server file symbol {:stop-early? true} {:byte ?byte})))

{: find-symbol
 : find-nearest-definition
 : search-main
 : search-name-and-scope
 :search-ast search-val}
