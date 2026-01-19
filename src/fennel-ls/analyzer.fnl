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

(local {: sym? : multi-sym? : list? : sequence? : varg?} (require :fennel))
(local {: get-ast-info &as utils} (require :fennel-ls.utils))
(local files (require :fennel-ls.files))
(local docs (require :fennel-ls.docs))
(local compiler (require :fennel-ls.compiler))

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
  (if (= 0 (length stack))
    document
    (and document.fields (. document.fields (. stack (length stack))))
    (search-document server (. document.fields (table.remove stack)) stack opts)
    {:indeterminate true
     :module-field (and document.fields
                     (not= (?. document :binding) :_G)
                     (= 1 (length stack)))}))

(λ search-val [server file ?ast stack opts]
  "searches for the definition of the ast, adjusted to 1 value"
  (search-multival server file ?ast stack 1 opts))

(λ search-definition [server file definition stack opts]
  (let [{:binding _
         :definition ?definition
         :keys ?keys
         :multival ?multival
         :fields ?fields} definition]
    (if (and (= 0 (length stack)) opts.stop-early?)
        definition ;; BASE CASE!!

        ;; :fields
        (and (not= 0 (length stack)) (?. ?fields (. stack (length stack))))
        (search-definition server file (. ?fields (table.remove stack)) stack opts)

        ;; This case is hard to explain.
        ;; Under these conditions, search-multival is planning on returning {:definition ?definition : file}
        ;; but assignment.target is more rich with information.
        ;; Specifically, it has the :fields key, which is useful in finding non-local fields.
        ;; For example, The `my-method` field of `M` in `(local M {})\n(fn M.my-method [])`
        ;; is shared using this :fields mechanism.
        (and (not (list? ?definition))
             (not (varg? ?definition))
             (= 1 (or 1 ?multival))
             (not (sym? ?definition))
             (= 0 (length stack))
             (= nil (?. ?keys 1)))
        definition

        (search-multival server file ?definition (stack-add-keys! stack ?keys) (or ?multival 1) opts))))

(λ search-reference [server file ref stack opts]
  (if ref.target.metadata
     (search-document server ref.target stack opts)
     ref.target.binding
     (search-definition server file ref.target stack opts)))

(λ search-symbol [server file symbol stack opts]
  (if (= (tostring symbol) :nil)
    (if (= 0 (length stack))
      {:definition symbol : file}
      nil)
    (. file.references symbol)
    (search-reference server file (. file.references symbol) (stack-add-multisym! stack symbol) opts)))

(λ search-table [server file tbl stack opts]
  (let [key (table.remove stack)]
    (case (. tbl key)
      ast (search-val server file ast stack opts)
      nil {:indeterminate true
           :module-field (and (= (length stack) 0)
                              (= tbl file.module))})))

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
          (when (and (= multival 1) (= :string (type mod)))
            (case (files.get-by-module server mod file.macro-file?)
              newfile (do
                        (compiler.compile server newfile)
                        (let [newitem (. newfile.ast (length newfile.ast))]
                          (search-val server newfile newitem stack opts)))
              _ {:indeterminate true})))
        "."
        (if (= multival 1)
          (let [[_ & rest] call]
            (search-val server file (. call 2) (stack-add-split! stack rest) opts)))
        ;; TODO we should probably handle everything that *evaluates to* setmetatable
        ;; not just symbols *named* setmetatable
        ;; This isn't a builtin/macro; it might be shadowed/reassigned/aliased
        :setmetatable
        (search-val server file (. call 2) stack opts)

        (where (or :fn :lambda :λ :hashfn))
        (if (and (= multival 1) (= 0 (length stack)))
          {:definition call : file}) ;; BASE CASE !!

        _
        (case (. file.macro-calls call)
          macroexpanded (search-multival server file macroexpanded stack multival opts)
          _ (case (search-val server file (. call 1) [] {})
              (where {: definition : file}
                     (list? definition)
                     (let [head (. definition 1)]
                       (or (sym? head :fn)
                           (sym? head :lambda)
                           (sym? head :λ)
                           (sym? head :hashfn))))
              (search-multival server file (. definition (length definition)) stack multival opts)
              result_ {:indeterminate true}
              _ (case (docs.get-builtin server (tostring (. call 1)))
                  ;; TODO support return types in metadata
                  {:metadata metadata_} {:indeterminate true})))))))

(set search-multival
  (λ [server file ?ast stack multival opts]
    (let [ast ?ast] ;; it was a bad idea to use λ because ast may be nil
      (if (list? ast)     (search-list server file ast stack multival opts)
          (varg? ast)     nil ;; TODO function-args
          (= 1 multival)
          (if (sym? ast)            (search-symbol server file ast stack opts)
              (= 0 (length stack))  {:definition ast : file} ;; BASE CASE !!
              (= :table (type ast)) (search-table server file ast stack opts)
              (= :string (type ast)) (search-document server (docs.get-global server nil :string) stack opts))
          nil))))


(local {:metadata METADATA} (require :fennel.compiler))
;; the options thing is getting out of hand
(λ search [server file ast opts initialization-opts]
  "Find the definition of an ast.
   the options are getting out of hand.

opts: {:stop-early? bool}
initialization-opts: {:stack ?list[ast]
                      :stack ?list[string]
                      :byte ?integer}
  "
  (assert (= (type initialization-opts) :table))
  ;; The stack is the multi-sym parts still to search
  ;; for example, if I'm searching for "foo.bar.baz", my immediate priority is to find foo,
  ;; and the stack has ["baz" "bar"]. "bar" is at the "top"/"end" of the stack as the next key to search.
  (if (sym? ast)
    ;; when your search starts as a symbol, there's lots of special interesting things to consider
    (let [stack (let [?byte initialization-opts.byte
                      split (or initialization-opts.split
                                (utils.multi-sym-split ast (if ?byte (- ?byte ast.bytestart))))]
                  (stack-add-split! (or initialization-opts.stack []) split))]
      (case (docs.get-builtin server (utils.multi-sym-base ast))
        document (search-document server document stack opts)
        _ (case (. file.macro-refs ast)
            ref {:binding ast :metadata (. METADATA ref)}
            ;; We want to traverse at least one reference, even if stop-early is set.
            ;; so we wan't just use the definitions
            _ (case (. file.references ast)
                ref (search-reference server file ref stack opts)
                _ (case (. file.definitions ast)
                    def (search-multival server file def.definition (stack-add-keys! stack def.keys) (or def.multival 1) opts))))))
    (search-val server file ast (or initialization-opts.stack []) opts)))

(λ find-local-definition [file name ?scope]
  (when ?scope
    (case (. file.definitions-by-scope ?scope name)
      definition definition
      _ (find-local-definition file name ?scope.parent))))

(λ search-name-and-scope [server file name scope ?opts]
  "find a definition just from the name of the item, and the scope it is in"
  (assert (= (type name) :string) "search-name-and-scope needs a string")
  (let [split (utils.multi-sym-split name)
        stack (stack-add-split! [] split)
        base-name (. split 1)
        opts (or ?opts {})]
    (case (docs.get-builtin server base-name)
      metadata (search-document server metadata stack opts)
      _ (case (find-local-definition file base-name scope)
          def (search-definition server file def stack opts)
          _ (case (docs.get-global server scope base-name)
              metadata (search-document server metadata stack opts))))))

(λ past? [?ast byte]
  ;; check if a byte is past an ast object
  (and (= (type ?ast) :table)
       (get-ast-info ?ast :byteend)
       (< (get-ast-info ?ast :byteend) byte)))

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

(λ find-symbol [server file byte]
  "tries to find a sym, and a list of all of its parents/grandparents"
  (compiler.compile server file)
  (local parents [file.ast])
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
                (recurse child)))
          (and (not (sym? ast)) (not (varg? ast)))
          (accumulate [(result _parent) nil
                       key value (pairs ast)
                       &until result]
            (if (contains? key byte)
                (recurse key)
                (contains? value byte)
                (recurse value)))))))
  (values
    (accumulate [result nil _ top-level-form (ipairs file.ast) &until result]
      (if (contains? top-level-form byte)
        (recurse top-level-form)))
    (fcollect [i 1 (length parents)]
      (. parents (- (length parents) i -1)))))

(λ find-document-symbols [server file]
  "Find all the symbols defined in the file

returns a sequential table of tables containing each symbol and its definition."
  (compiler.compile server file)
  (let [symbols []]
    (each [symbol definition (pairs file.definitions)]
      (when (and (or (sym? symbol) (multi-sym? symbol))
                 definition.binding
                 (. file.lexical symbol) ; exclude gensyms
                 (not (= (tostring symbol) "_")))
        (table.insert symbols {: symbol : definition}))
      ; definitions doesn't have multi-syms so we get them out of fields
      (when definition.fields
        (each [_field-name field-definition (pairs definition.fields)]
          (when (and field-definition.binding
                     (or (sym? field-definition.binding)
                         (multi-sym? field-definition.binding)))
            (table.insert symbols
              {:symbol field-definition.binding
               :definition field-definition})))))
    symbols))

(λ find-nearest-call [server file byte]
  "Find the nearest call

returns the called symbol and the number of the argument closest to byte"
  (case-try (find-symbol server file byte)
    (_symbol parents) (accumulate [result nil _ v (ipairs parents) &until result]
                        (if (. file.calls v)
                          v))
    [callee &as call] (values callee ;; TODO: special handling for binding forms so we can point to the
                                     ;; individual arguments in an each or accumulate call.
                                     ;; Also need to split them up in formatter.fnl
                                     (faccumulate [index nil
                                                   i (length call) 1 -1 &until index]
                                       (if (contains? (. call i) byte)
                                           ; -2 because this is the 3rd element of the list, but
                                           ; the 2nd argument to the call, and LSP is 0-indexed
                                           (- i 2)
                                           (past? (. call i) byte)
                                           ; this means we are either at the end of the list or
                                           ; inserting between two arguments
                                           (- i 1))))

    (catch _ nil)))

(λ find-definition [server file symbol ?byte]
  (or (. file.definitions symbol)
      (search server file symbol {:stop-early? false} {:byte ?byte})))

(λ find-nearest-definition [server file symbol ?byte]
  (or (. file.definitions symbol)
      (search server file symbol {:stop-early? true} {:byte ?byte})))

{: find-symbol
 : find-document-symbols
 : find-nearest-call
 : find-nearest-definition
 : find-definition
 : search
 : search-name-and-scope}
