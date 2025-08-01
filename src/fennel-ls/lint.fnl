"Lint
Provides the function (add-lint-diagnostics server file), which goes through
a file and fills the `file.diagnostics` field with diagnostics.

You can read more about how to add lints in docs/linting.md"

(local {: sym? : list? : table? : varg? : view
        : sym : list &as fennel} (require :fennel))
(local {:scopes {:global {:specials SPECIALS}}} (require :fennel.compiler))

(local analyzer (require :fennel-ls.analyzer))
(local message (require :fennel-ls.message))
(local utils (require :fennel-ls.utils))
(local navigate (require :fennel-ls.navigate))
(local docs (require :fennel-ls.docs))
(local dkjson (require :dkjson))
(local compiler (require :fennel-ls.compiler))


(fn special? [item]
  (and (sym? item)
       (. SPECIALS (tostring item))
       item))

(local ops {"+" 1 "-" 1 "*" 1 "/" 1 "//" 1 "%" 1 "^" 1 ">" 1 "<" 1 ">=" 1
            "<=" 1 "=" 1 "not=" 1 ".." 1 "." 1 "and" 1 "or" 1 "band" 1
            "bor" 1 "bxor" 1 "bnot" 1 "lshift" 1 "rshift" 1})

(fn op? [item]
  (and (sym? item)
       (. ops (tostring item))
       item))

(local op-identity-value {:+ 0 :* 1 :and true :or false :band -1 :bor 0 :.. ""})
(local associative-ops {:+ true :* true :and true :or true :band true :bor true :.. true})
(local redundant-wrappers {:+ true :* true :and true :or true :band true :bor true :.. true :do true :values true})
(local implicit-do-forms (collect [form {: body-form?} (pairs (fennel.syntax))]
                           form body-form?))


(local lints {:definition []
              :reference []
              :macro-call []
              :function-call []
              :special-call []
              :other []})

(local all-lints [])

(fn add-lint [name lint ...]
  (when (= nil lint.type) (error (.. name " needs a type. available types: " (view (icollect [k (pairs lints)] k)))))
  (table.insert all-lints lint)
  (for [i 1 (select :# lint ...)]
    (let [lint (select i lint ...)]
      (set lint.name name)
      (if (= (type lint.type) :table)
        (each [_ t (ipairs lint.type)]
          (table.insert (assert (. lints t) (.. "unknown lint type " t)) lint))
        (table.insert (assert (. lints lint.type) (.. "unknown lint type " lint.type)) lint)))))

(add-lint :unused-definition
  {:what-it-does
   "Marks bindings that aren't read. Completely overwriting a value doesn't count
    as reading it. A variable that starts or ends with an `_` will not trigger this
    lint. Use this to suppress the lint."
   :why-care?
   "Unused definitions can lead to bugs and make code harder to understand. Either
    remove the binding, or add an `_` to the variable name."
   :example
   "```fnl
    (var value 100)
    (set value 10)
    ```
    Instead, use the value, remove it, or add `_` to the variable name.
    ```fnl
    (var value 100)
    (set value 10)
    ;; use the value
    (print value)
    ```"
   :limitations
   "Fennel's pattern matching macros also check for leading `_` in symbols.
    This means that adding `_` can change the semantics of the code. In this
    situation, the user needs to add the `_` to the **end** of the symbol
    to disable only the lint, without changing the pattern's meaning.
    Only use a trailing underscore when it's required to prevent code from
    changing meaning.
    ```fnl
    ;; Original. Works, but `b` is flagged by the lint
    (match [10 nil]
      [a b] (print a \"unintended\")
      _ (print \"we want this one\")) ;; Prints this one!

    ;; Suppressing lint normally causes problems
    (match [10 nil]
      [a _b] (print a \"unintended\") ;; Uh oh, we're printing \"unintended\" now!
      _ (print \"we want this one\"))

    ;; Solution! Underscore at the end
    (match [10 nil]
      [a b_] (print a \"unintended\")
      _ (print \"we want this one\")) ;; Prints the right one
    ```

    Think of the trailing underscore as the fourth possible sigil:
    `?identifier` - must be used, and can be `nil`
    `identifier` - must be used, and should be non-`nil`
    `_identifier` - may be unused, and can be `nil`
    `identifer_` - may be unused, but should be non-`nil`"
   :since "0.1.0"
   :type :definition
   :impl (fn [server file symbol definition]
           "local variable that is defined but not used"
           (let [symname (tostring symbol)]
             (if (not (or (and (= "_" (symname:sub 1 1))
                               (not= "__" (symname:sub 1 2)))
                          (= "_" (symname:sub -1 -1))
                          (accumulate [reference false
                                       _ ref (ipairs definition.referenced-by)
                                       &until reference]
                            (or (= ref.ref-type :read)
                                (= ref.ref-type :mutate)))))
               {:range (message.ast->range server file symbol)
                :message (.. "unused definition: " symname)
                :severity message.severity.WARN
                :fix #{:title (.. "Replace " symname " with _" symname)
                       :changes [{:range (message.ast->range server file symbol)
                                  :newText (.. "_" symname)}]}})))})

;; this is way too specific; it's also safe to do this inside an `if` or `case`
(fn in-or? [calls symbol]
  "Check if the symbol is in an expression like `(or unpack table.unpack)`, where we want to suppress the module field stuff."
  (accumulate [in? false call (pairs calls) &until in?]
    (and (sym? (. call 1) :or) (utils.find call symbol))))

(fn unknown-module-field [server file symbol ?ast ?stack]
  "if ?ast is a module field that isn't known, return a diagnostic"
  (let [opts {}
        item (analyzer.search server file ?ast opts {:stack ?stack})]
    (if (and (not item)
             (not (in-or? file.calls symbol))
             ;; this doesn't necessarily have to come thru require; it works
             ;; for built-in modules too
             opts.searched-through-require-with-stack-size-1)
        {:range (message.ast->range server file symbol)
         :message (.. "unknown field: " (tostring symbol))
         :severity message.severity.WARN})))

(add-lint :unknown-module-field
  {:what-it-does
   "Looks for module fields that can't be statically determined to exist. This only
    triggers if the module is found, but there's no definition of the field inside
    of the module."
   :why-care?
   "This is probably a typo, or a missing function in the module."
   :example
   "```fnl
    ;;; in `a.fnl`
    {: print}

    ;;; in `b.fnl`
    (local a (require :a))
    (a.printtt 100)
    ```
    Instead, use:
    ```fnl
    ;;; in `b.fnl`
    (local a (require :a))
    (a.print 100) ; typo fixed
    ```"
   :limitations
   "Fennel-ls doesn't have a full type system, so we're not able to check every
    multisym statically, but as a heuristic, usually modules are able to be
    evaluated statically. If you have a module that can't be figured out, please
    let us know on the bug tracker."
   :since "0.1.0"
   :type :reference
   :impl (fn [server file symbol]
           ;; only multisyms, like `my-module.field`
           (if (. (utils.multi-sym-split symbol) 2)
               (unknown-module-field server file symbol symbol)))}
  {:type :definition
   :impl (fn [server file symbol definition]
           ;; definitions, like `(local {: field} (require :my-module))`
           (if definition.keys
               (unknown-module-field server file symbol definition.definition
                                    (fcollect [i (length definition.keys) 1 -1]
                                      (. definition.keys i)))))})

(add-lint :unnecessary-method
  {:what-it-does
   "Checks for unnecessary uses of the `:` method call syntax when a simple multisym
    would work."
   :why-care?
   "Using the method call syntax unnecessarily adds complexity and can make code
    harder to understand."
   :example
   "```fnl
    (: alien :shoot-laser {:x 10 :y 20})
    ```

    Instead, use:
    ```fnl
    (alien:shoot-laser {:x 10 :y 20})
    ```"
   :since "0.1.0"
   :type :special-call
   :impl (fn [server file ast]
           "a call to the : builtin that could just be a multisym"
            (let [object (. ast 2)
                  method (. ast 3)]
              (if (and (sym? (. ast 1) ":")
                       (sym? object)
                       (utils.valid-sym-field? method))
                {:range (message.ast->range server file ast)
                 :message (.. "unnecessary : call: use (" (tostring object) ":" method ")")
                 :severity message.severity.WARN})))})

(add-lint :unnecessary-tset
  {:what-it-does
   "Identifies unnecessary uses of `tset` when a `set` with a multisym would be clearer."
   :why-care?
   "Using `tset` makes the code more verbose and harder to read when a simpler
    alternative exists."
   :example
   "```fnl
    (tset alien :health 1337)
    ```

    Instead, use:
    ```fnl
    (set alien.health 1337)
    ```"
   :since "0.2.0"
   :type :special-call
   :impl (fn [server file ast]
           (let [all-rewritable? (faccumulate [syms true
                                               i 3 (- (length ast) 1)
                                               &until (not syms)]
                                    (utils.valid-sym-field? (. ast i)))]
             (if (and (sym? (. ast 1) "tset")
                      (sym? (. ast 2))
                      all-rewritable?)
                 {:range (message.ast->range server file ast)
                  :message "unnecessary tset"
                  :severity message.severity.WARN
                  :fix #{:title "Replace tset with set"
                         :changes [{:range (message.ast->range server file ast)
                                    :newText (string.format "(set %s.%s %s)"
                                                            (tostring (. ast 2))
                                                            (table.concat ast "." 3 (- (length ast) 1))
                                                            (view (. ast (length ast))))}]}})))})

(add-lint :unnecessary-unary
  {:what-it-does
   "Warns about unnecessary `do` or `values` forms that only contain a single expression."
   :why-care?
   "Extra forms that don't do anything add syntactic noise."
   :example
   "```fnl
    (do (print \"hello\"))

    (values (+ 1 2))
    ```

    Instead, use:
    ```fnl
    (print \"hello\")

    (+ 1 2)
    ```"
   :since "0.2.0"
   :type :special-call
   :impl (fn [server file ast]
           (if (and (sym? (. ast 1))
                    (. redundant-wrappers (tostring (. ast 1)))
                    (= (length ast) 2))
               {:range (message.ast->range server file ast)
                :message (.. "unnecessary unary " (tostring (. ast 1)))
                :severity message.severity.WARN
                :fix #{:title "Unwrap the expression"
                       :changes [{:range (message.ast->range server file ast)
                                  :newText (view (. ast 2))}]}}))})

(add-lint :redundant-do
  {:what-it-does
   "Identifies redundant `do` blocks within implicit do forms like `fn`, `let`, etc."
   :why-care?
   "Redundant `do` blocks add unnecessary nesting and make code harder to read."
   :example
   "```fnl
    (fn [] (do
      (print \"first\")
      (print \"second\")))
    ```

    Instead, use:
    ```fnl
    (fn []
      (print \"first\")
      (print \"second\"))
    ```"
   :since "0.2.0"
   :type :special-call
   :impl (fn [server file ast]
           (let [last-body (. ast (length ast))]
             (if (and (. implicit-do-forms (tostring (. ast 1)))
                      (list? last-body)
                      (sym? (. last-body 1) :do))
                 {:range (message.ast->range server file last-body)
                  :message "redundant do"
                  :severity message.severity.WARN
                  :fix #{:title "Unwrap the expression"
                         :changes [{:range (message.ast->range server file last-body)
                                    :newText (table.concat
                                              (fcollect [i 2 (length last-body)]
                                                (view (. last-body i)))
                                              " ")}]}})))})

(add-lint :bad-unpack
  {:what-it-does
   "Warns when `unpack` or `table.unpack` is used with operators that aren't
    variadic at runtime."
   :why-care?
   "Fennel operators like `+`, `*`, etc. look like they should work with `unpack`,
    but they don't actually accept a variable number of arguments at runtime."
   :example
   "```fnl
    (+ 1 (unpack [2 3 4]))  ; Only adds 1 and 2
    (.. (unpack [\"a\" \"b\" \"c\"]))  ; Only concatenates \"a\"
    ```

    Instead, use:
    ```fnl
    ;; For concatenation:
    (table.concat [\"a\" \"b\" \"c\"])

    ;; For other operators, use a loop:
    (accumulate [sum 0 _ n (ipairs [1 2 3 4])]
      (+ sum n))
    ```"
   :since "0.1.0"
   :type :special-call
   :impl (fn [server file call]
           "an unpack call leading into an operator"
           (let [op (. call 1)
                 last (. call (length call))]
             (if (and (op? op)
                      ;; last item is an unpack call
                      (list? last)
                      (or (sym? (. last 1) :unpack)
                          (sym? (. last 1) :_G.unpack)
                          (sym? (. last 1) :table.unpack)))
                 {:range (message.ast->range server file last)
                  :message (.. "faulty unpack call: " (tostring op)
                               " isn't variadic at runtime."
                               (if (sym? op "..")
                                 (let [unpackme (view (. last 2))]
                                   (.. " Use (table.concat " unpackme
                                       ") instead of (.. (unpack " unpackme "))"))
                                 (.. " Use a loop when you have a dynamic number of "
                                     "arguments to (" (tostring op) ")")))
                  :severity message.severity.WARN
                  :fix (if (and (= (length last) 2)
                                (sym? op ".."))
                           #{:title "Replace with a call to table.concat"
                             :changes [{:range (message.ast->range server file (if (= 2 (length call)) call last))
                                        :newText (.. "(table.concat " (view (. last 2)) ")")}]})})))})

(add-lint :var-never-set
  {:what-it-does
   "Identifies variables declared with `var` that are never modified with `set`."
   :why-care?
   "If a `var` is never modified, it should be declared with `local` or `let` instead
    for clarity."
   :example
   "```fnl
    (var x 10)
    (print x)
    ```

    Instead, use:
    ```fnl
    (let [x 10]
      (print x))
    ```"
   :since "0.1.0"
   :type :definition
   :impl (fn [server file symbol definition]
           (if (and definition.var? (not definition.var-set))
               ;; we can't provide a quickfix for this because the hooks don't give us
               ;; the full AST of the call to var; just the LHS/RHS
               {:range (message.ast->range server file symbol)
                :message (.. "var is never set: " (tostring symbol)
                             " Consider using (local) instead of (var)")
                :severity message.severity.WARN}))})

(add-lint :op-with-no-arguments
  {:what-it-does
   "Warns when an operator is called with no arguments, which can be replaced with
    an identity value."
   :why-care?
   "Calling operators with no arguments is less clear than using the identity value
    directly."
   :example
   "```fnl
    (+)  ; Returns 0
    (*)  ; Returns 1
    (..)  ; Returns \"\"
    ```

    Instead, use:
    ```fnl
    0
    1
    \"\"
    ```"
   :limitations
   "This lint isn't actually very useful."
   :since "0.1.1"
   :type :special-call
   :impl (fn [server file ast]
           "A call like (+) that could be replaced with a literal"
           (let [op (. ast 1)
                 identity (. op-identity-value (tostring op))]
             (if (and (op? op)
                      (= 1 (length ast))
                      (not= nil identity))
                 {:range (message.ast->range server file ast)
                  :message (.. "write " (view identity) " instead of (" (tostring op) ")")
                  :severity message.severity.WARN
                  :fix #{:title (.. "Replace (" (tostring op) ") with " (view identity))
                         :changes [{:range (message.ast->range server file ast)
                                    :newText (view identity)}]}})))})

(add-lint :no-decreasing-comparison
  {:what-it-does
   "Suggests using increasing comparison operators (`<`, `<=`) instead of decreasing ones (`>`, `>=`)."
   :why-care?
   "Consistency in comparison direction makes code more readable and maintainable,
    especially in languages with lisp syntax. You can think of `<` as a function that
    tests if the arguments are in sorted order."
   :example
   "```fnl
    (> a b)
    (>= x y z)
    ```

    Instead, use:
    ```fnl
    (< b a)
    (<= z y x)
    ```"
   :since "0.2.0"
   :type :special-call
   :disabled true
   :impl (fn [server file ast]
           (let [op (. ast 1)]
             (if (or (sym? op :>) (sym? op :>=))
                 {:range (message.ast->range server file ast)
                  :message "Use increasing operator instead of decreasing"
                  :severity message.severity.WARN
                  :fix #{:title "Reverse the comparison"
                         :changes [{:range (message.ast->range server file ast)
                                    :newText (let [new (if (sym? op :>=) (sym :<=) (sym :<))
                                                   reversed (fcollect [i (length ast) 2 -1
                                                                       &into (list new)]
                                                              (. ast i))]
                                               (view reversed))}]}})))})

(λ match-reference? [ast references]
  (if (sym? ast) (?. references ast :target)
      (or (table? ast) (list? ast))
      (accumulate [ref false _ subast (pairs ast) &until ref]
        (match-reference? subast references))))

(add-lint :match-should-case
  {:what-it-does
   "Suggests using `case` instead of `match` when the meaning would not be altered."
   :why-care?
   "The `match` macro's meaning depends on the local variables in scope. When a
    `match` call doesn't use the local variables, it can be replaced with the
    `case` form."
   :example
   "```fnl
    (match value
      10 \"ten\"
      20 \"twenty\"
      _ \"other\")
    ```

    Instead, use:
    ```fnl
    (case value
      10 \"ten\"
      20 \"twenty\"
      _ \"other\")
    ```"
   :since "0.2.0"
   :type :macro-call
   :impl (fn [server {: references &as file} ast]
           (when (and (list? ast)
                      (sym? (. ast 1) :match)
                      (not (faccumulate [ref false i 3 (length ast) 2 &until ref]
                             (match-reference? (. ast i) references))))
             {:range (message.ast->range server file (. ast 1))
              :message "no pinned patterns; use case instead of match"
              :severity message.severity.WARN
              :fix #{:title "Replace match with case"
                     :changes [{:range (message.ast->range server file (. ast 1))
                                :newText "case"}]}}))})

(add-lint :inline-unpack
  {:what-it-does
   "Warns when multiple values from `values` or `unpack` are used in a non-final
    position of a function call, where only the first value will be used."
   :why-care?
   "In Fennel (and Lua), multiple values are only preserved when they appear in the
    final position of a function call. Using them elsewhere results in only the
    first value being used. This is likely not what was intended, since the use of
    `values` or `unpack` seems to imply that the code is interested in handling
    multivals instead of discarding them."
   :example
   "```fnl
    (print (values 1 2 3) 4)  ; confusingly prints \"1   4\"
    ```

    Instead, use:
    ```fnl
    ;; Try putting the multival at the end:
    (print 4 (values 1 2 3))

    ;; Try writing the logic out manually instead of using multival
    (let [(a b c) (values 1 2 3)]
      (print a b c 4)
    ```"
   :limitations
   "It doesn't make sense to flag *all* places where a multival is discarded, because
    discarding extra values is common in Lua. For example, in the standard library
    of Lua, `string.gsub` and `require` actually return two results, even though
    most of the time, only the first one is what's wanted.

    This lint specifically flags discarding multivals from `values` and `unpack`,
    instead of flagging all discards, because these forms indicate that the user
    *intends* for something to happen with multivals.

    You find more information about Lua's multivals in [Benaiah's excellent post explaining Lua's multivals](https://benaiah.me/posts/everything-you-didnt-want-to-know-about-lua-multivals),
    or by searching the word \"adjust\" in the [Lua Manual](https://www.lua.org/manual/5.4/manual.html#3.4.12)."
   :since "0.1.2"
   :type [:function-call :special-call]
   :impl (fn [server file ast]
           "generally, values and unpack are signs that the user is trying to do
            something with multiple values. However, multiple values will get
            \"adjusted\" to one value if they don't come at the end of the call."
           (faccumulate [f nil index 2 (length ast) &until f]
             (let [arg (. ast index)]
               (if (and (or (op? (. ast 1)) (not (special? (. ast 1))))
                        (not= index (length ast))
                        (list? arg)
                        (or (sym? (. arg 1) :values)
                            (sym? (. arg 1) :unpack)
                            (sym? (. arg 1) :_G.unpack)
                            (sym? (. arg 1) :table.unpack)))
                 {:range (message.ast->range server file arg)
                  :message (.. "bad " (tostring (. arg 1))
                               " call: only the first value of the multival will be used")
                  :severity message.severity.WARN}))))})

(add-lint :empty-let
  {:what-it-does
   "Warns about `(let [] ...)` that should be `(do ...)`."
   :why-care?
   "Using `let` with no bindings is unnecessarily verbose when `do` serves the same purpose more clearly."
   :example
   "```fnl
    (let []
      (print \"hello\")
      (print \"world\"))
    ```

    Instead, use:
    ```fnl
    (do
      (print \"hello\")
      (print \"world\"))
    ```"
   :since "0.2.2-dev"
   :type :special-call
   :impl (fn [server file ast]
           (case ast
             (where [let* binding]
                    (sym? let* :let)
                    (fennel.sequence? binding)
                    (= 0 (length binding)))
             {:range (message.ast->range server file binding)
              :message "use do instead of let with no bindings"
              :severity message.severity.WARN
              :fix #{:title "Replace (let [] ...) with (do ...)"
                     :changes [(let [{: start} (message.ast->range server file let*)
                                     {: end} (message.ast->range server file binding)]
                                 {:range {: start : end}
                                  :newText "do"})]}}))})

(fn possibly-multival? [ast]
  ;; operators all adjust to 1 value
  (or (and (list? ast) (not (op? (. ast 1))) (not (sym? (. ast 1) :not)))
      (varg? ast)))

(add-lint :not-enough-arguments
  {:what-it-does
   "Checks if function calls have enough number of arguments based on the function's signature."
   :why-care?
   "Calling functions without all the arguments fills in the extra arguments with `nil` which
    can cause unexpected behavior. This lint helps catch these issues early."
   :example
   "```fnl
    (string.sub \"hello\")  ; missing required arguments
    ```

    Instead, use:
    ```fnl
    (string.sub \"hello\" 1)  ; provide all required arguments
    ```"
   :limitations
   "This lint is disabled by default because it can produce false positives.
    It assumes that all optional arguments are reliably annotated with a ? sigil,
    and any other arguments can be assumed to be required. This is reasonably
    accurate if the code follows Fennel conventions. Also this lint is very new and
    may have issues, so I'd like to let people try it on their own terms before
    enabling it by default."
   :since "0.2.2-dev"
   :type [:function-call :special-call :macro-call]
   :disabled true
   :impl (fn [server file ast]
             (case (analyzer.search server file (. ast 1) {} {})
               {:indeterminate nil &as result}
               (case (?. (navigate.getmetadata server result) :fnl/arglist)
                 signature
                 (let [number-of-args (- (length ast) 1)
                       passes-extra-args (and (not= 1 (length ast))
                                              (not (special? (. ast 1)))
                                              (not (. file.macro-calls ast))
                                              (possibly-multival? (. ast (length ast))))
                       ;; exception: (- a b) only needs 1 argument
                       ;; exception: (/ a b) only needs 1 argument
                       min-params (if (= result (docs.get-builtin server :-)) 1
                                      (= result (docs.get-builtin server :/)) 1
                                      ;; TODO Fennel 1.5.4+ has `fn`'s arglist fixed
                                      ;; exception: fn only needs one argument
                                      (= result (docs.get-builtin server :fn)) 1
                                      (= result (docs.get-builtin server :collect)) 2
                                      (or (accumulate [last-required-param nil
                                                       i arg (ipairs signature)
                                                       &until (let [s (tostring arg)]
                                                                (or (= s "...")
                                                                    (= s "&")))]
                                            (let [first-char (string.sub (tostring arg) 1 1)]
                                              (if (and (not= first-char "?") (not= first-char "_"))
                                                  i
                                                  last-required-param)))
                                          0))
                       method-call? (and (sym? (. ast 1))
                                         (string.find (tostring (. ast 1)) ".:"))
                       min-params (- min-params (if method-call? 1 0))]
                   (if (and (< number-of-args min-params)
                            (not passes-extra-args))
                       {:range (message.ast->range server file ast)
                        :message (.. (view (. ast 1)) " expects at least " min-params " argument(s); found " number-of-args)
                        :severity message.severity.WARN})))))})

(add-lint :too-many-arguments
  {:what-it-does
   "Checks if function calls have the correct number of arguments based on the function's signature."
   :why-care?
   "Calling functions with the wrong number of arguments can lead to runtime errors
    or unexpected behavior. This lint helps catch these issues early."
   :example
   "```fnl
    (string.sub \"hello\" 1 2 3) ; too many arguments

    (assert (< x y)
            (.. \"x=\"
                (tostring x)) ; mismatched parens can cause too many arguments to a function
                \" is less than y=\"
                (tostring y))
    ```

    Instead, use:
    ```fnl
    (string.sub \"hello\" 1 2) ; remove extra arguments

    (assert (< x y)
            (.. \"x=\"
                (tostring x)
                \" is less than y=\"
                (tostring y))) ; fixed parens
    ```"
   :since "0.2.2-dev"
   :type [:function-call :special-call :macro-call]
   :impl (fn [server file ast]
             (case (analyzer.search server file (. ast 1) {} {})
               {:indeterminate nil &as result}
               (case (?. (navigate.getmetadata server result) :fnl/arglist)
                 signature
                 (let [number-of-args (- (length ast) 1)
                       infinite-params? (accumulate [vararg nil
                                                      _ arg (ipairs signature)
                                                      &until vararg]
                                          (let [s (tostring arg)]
                                            (or (= s "...") (= s "&"))))
                       ;; exception: (table.insert table item) can take a third argument
                       max-params (if (= result (. (docs.get-global server nil :table) :fields :insert))
                                      3
                                      (length signature))
                       method-call? (and (sym? (. ast 1))
                                         (string.find (tostring (. ast 1)) ".:"))
                       max-params (- max-params (if method-call? 1 0))]

                   (if (and (< max-params number-of-args)
                            (not infinite-params?))
                     (let [range-of-call (message.ast->range server file ast)
                           first-bad-argument (. ast (+ 2 max-params))
                           ?range-of-first-bad-argument (message.ast->range server file first-bad-argument)
                           range {:start (or (?. ?range-of-first-bad-argument :start) range-of-call.start)
                                  :end range-of-call.end}]
                       {: range
                        :message (if (= max-params -1)
                                     ;; this is when you call a 0 argument function using a `:`
                                     (.. (: (view (. ast 1)) :gsub ":" ".") " expects 0 arguments; found 1")
                                     (.. (view (. ast 1)) " expects at most " max-params " argument(s); found " number-of-args))
                        :severity message.severity.WARN}))))))})

(add-lint :duplicate-table-keys
  {:what-it-does
   "Detects when the same key appears multiple times in a table literal."
   :why-care?
   "Duplicate keys in a table are usually a mistake and the later value will
    overwrite the earlier one, which can lead to bugs."
   :example
   "```fnl
    {:name \"Alice\"
     :age 25
     :name \"Bob\"}  ; \"Alice\" gets overwritten by \"Bob\"
    ```

    Instead, use:
    ```fnl
    {:name \"Bob\"
     :age 25}
    ```"
   :since :0.2.2-dev
   :type :other
   :impl (fn [server file]
           (let [seen []]
             (each [ast (pairs file.lexical)]
               (when (table? ast)
                 (case (getmetatable ast)
                   {: keys}
                   (let [dkey (accumulate [_ 1
                                           i v (ipairs keys)
                                           &until (. seen v)]
                                (do (set (. seen v) i)
                                  (+ i 1)))]
                     (when (. keys dkey)
                       (coroutine.yield
                         {:code :duplicate-table-keys ; TODO we should fix `other` type lints so the code isn't necessary
                          :range (message.ast->range server file ast)
                          :message (.. "key " (tostring (. keys dkey)) " appears more than once")
                          :severity message.severity.WARN}))
                     (each [k (pairs seen)]
                       (set (. seen k) nil))))))))})

(fn zero-indexed [server file [callee tbl key &as ast]]
  (if (and (sym? callee ".") (= 0 key) (not (sym? tbl :arg)))
      {:range (message.ast->range server file ast)
       :message "indexing a table with 0; did you forget that Lua is 1-indexed?"
       :severity message.severity.WARN}))

(add-lint :zero-indexed
  {:what-it-does "Checks for accidentally treating tables as zero-indexed."
   :why-care? "For new Fennel learners, this is a common mistake."
   :example
   "```fnl
    (print (. inputs 0))
    ```"
   :since "0.2.2-dev"
   :type :special-call
   :impl zero-indexed})

(add-lint :invalid-flsproject-settings
  {:what-it-does
   "Checks if the flsproject file's settings are valid."
   :why-care?
   "Invalid settings in flsproject.fnl won't configuree fennel-ls."
   :example
   "```fnl
    {:fennel-macro-path \"macros/?.mfnl\"}
    ```
    Instead, use:
    ```fnl
    {:macro-path \"macros/?.mfnl\"}
    ```"
   :since :0.2.2-dev
   :type :other
   :impl (fn [server file]
           (let [config-module :fennel-ls.config
                 config (require config-module)]
             (when (and (= file.uri (config.flsproject-path server))
                        (not (. file.diagnostics 1)))
               ;; circular dependency! don't tell anyone ^_^
               (config.make-configuration (. file.ast 1)
                                          #(coroutine.yield {:code :invalid-flsproject-settings
                                                             :range (or (message.ast->range server file $2)
                                                                        (message.ast->range server file $3)
                                                                        message.unknown-range)
                                                             :message $
                                                             :severity message.severity.WARN}))))
           nil)})

(add-lint :nested-associative-operator
  {:what-it-does
   "Identifies forms that could be written in a flatter way, like `(and foo (and bar baz))`."
   :why-care?
   "Collapsing nested forms reduces unnecessary nesting and makes code more readable and idiomatic."
   :example
   "```fnl
    (and foo bar (and baz buzz) xyz)
    (+ a (+ b c) d)
    (or x (or y z))
    ```

    Instead, use:
    ```fnl
    ;; Flattened forms:
    (and foo bar baz buzz xyz)
    (+ a b c d)
    (or x y z)
    ```"
   :since "0.2.2-dev"
   :type :special-call
   :impl (fn [server file ast]
           (let [op (. ast 1)]
             (when (and (sym? op)
                        (. associative-ops (tostring op)))
               (faccumulate [diagnostic nil
                             i 2 (length ast)
                             &until diagnostic]
                 (let [arg (. ast i)
                       op-str (tostring op)]
                   (when (and (list? arg) (= op (. arg 1)))
                     {:range (message.ast->range server file arg)
                      :message (.. "nested " op-str " can be collapsed")
                      :severity message.severity.WARN
                      :fix #(let [new-form (list (. ast 1))]
                              (for [j 2 (length ast)]
                                (let [item (. ast j)]
                                  (if (and (list? item)
                                           (sym? (. item 1) op-str))
                                      (fcollect [k 2 (length item) &into new-form]
                                        (. item k))
                                      (table.insert new-form item))))
                              {:title (.. "Collapse all nested " op-str)
                               :changes [{:range (message.ast->range server file ast)
                                          :newText (view new-form)}]})}))))))})

(local lint-mt {:__tojson (fn [{: self} state] (dkjson.encode self state))
                :__index #(. $1 :self $2)})

(fn wrap [self]
  ;; hide `fix` field from the client
  (let [fix self.fix]
    (set self.fix nil)
    (setmetatable {: self : fix} lint-mt)))

(λ add-lint-diagnostics [server file]
  (when (not file.diagnostics)
    (compiler.compile server file)
    (set file.diagnostics file.compile-errors)
    (fn run [lints ...]
      (each [_ lint (ipairs lints)]
        (when (. server.configuration.lints lint.name)
          (case (lint.impl ...)
            diagnostic
            (table.insert file.diagnostics
              (wrap (doto diagnostic
                          (tset :code lint.name))))))))
    (icollect [diagnostic (coroutine.wrap #(run lints.other server file)) &into file.diagnostics]
      (wrap diagnostic))
    (each [symbol definition (pairs file.definitions)]
      (when (. file.lexical symbol)
        (run lints.definition server file symbol definition)))
    (each [symbol (pairs file.references)]
      (when (. file.lexical symbol)
        (run lints.reference server file symbol)))
    (each [[head &as ast] (pairs file.calls)]
      (when (and (. file.lexical ast) (not= nil head))
        (run (if (special? head) lints.special-call lints.function-call)
            server file ast)))
    (each [ast macroexpanded (pairs file.macro-calls)]
      (when (. file.lexical ast)
        (run lints.macro-call
             server file ast macroexpanded)))))

{: add-lint-diagnostics
 :list all-lints}
