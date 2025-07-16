(local faith (require :faith))
(local {: create-client
        : position-past-end-of-text} (require :test.utils))
(local {: view} (require :fennel))

(local kinds
  {:Text 1 :Method 2 :Function 3 :Constructor 4 :Field 5 :Variable 6 :Class 7
   :Interface 8 :Module 9 :Property 10 :Unit 11 :Value 12 :Enum 13 :Keyword 14
   :Snippet 15 :Color 16 :File 17 :Reference 18 :Folder 19 :EnumMember 20
   :Constant 21 :Struct 22 :Event 23 :Operator 24 :TypeParameter 25})

(fn find [client params e]
  (let [completions (or params.items params)]
    (accumulate [result nil
                 i c (ipairs completions)
                 &until result]
      (let [c (if params.itemDefaults
                (collect [k v (pairs params.itemDefaults) &into (collect [k v (pairs c)] k v)] k v)
                c)]
        (if (or (and (= (type e) :string)
                     (= c.label e))
                (and (= (type e) :table)
                     (or (= e.label nil)
                         (and (= (type e.label) :string) (= e.label c.label))
                         (and (= (type e.label) :function) (e.label c.label)))
                     (or (= e.kind nil)
                         (and (= (type e.kind) :number) (= e.kind c.kind))
                         (and (= (type e.kind) :function) (e.kind c.kind)))
                     (or (= e.filterText nil)
                         (and (= (type e.filterText) :string) (= e.filterText c.filterText))
                         (and (= (type e.filterText) :function) (e.filterText c.filterText)))
                     (or (= e.insertText nil)
                         (and (= (type e.insertText) :string) (= e.insertText c.insertText))
                         (and (= (type e.insertText) :function) (e.insertText c.insertText)))
                     (or (= e.documentation nil)
                         (let [c (if params.items (-> (client:completion-item-resolve c)
                                                      (. 1 :result))
                                                  c)]
                          (or
                            (and (= (type e.documentation) :string) (= e.documentation c.documentation))
                            (and (= (type e.documentation) :function) (e.documentation c.documentation))
                            (and (= e.documentation true) (not= nil c.documentation)))))
                     (or (= e.textEdit nil)
                         (let [c-textEdit (or c.textEdit {:range c.editRange :newText (or c.insertText c.label)})]
                           (and (= (type e.textEdit) :table)
                                (= e.textEdit.range.start.line      c-textEdit.range.start.line)
                                (= e.textEdit.range.start.character c-textEdit.range.start.character)
                                (= e.textEdit.range.end.line        c-textEdit.range.end.line)
                                (= e.textEdit.range.end.character   c-textEdit.range.end.character)
                                (= e.textEdit.newText c-textEdit.newText)))
                         (and (= (type e.textEdit) :function) (e.textEdit c.textEdit)))))
          i)))))

(fn check [file-contents expected unexpected ?bad-completions?]
  (let [{: client : uri : cursor : text} (create-client file-contents (if (not ?bad-completions?)
                                                                          {:capabilities
                                                                           {:textDocument
                                                                            {:completion
                                                                             {:completionList
                                                                              {:itemDefaults
                                                                               [:editRange :data]}}}}}))
        [{:result ?result}] (client:completion uri
                              (or cursor
                                  (position-past-end-of-text text)))
        completions (or ?result [])]

    (each [_ e (ipairs unexpected)]
      (let [i (find client completions e)]
        (faith.= nil i (.. "Got unexpected completion: " (view e) "\n"
                           "from:    " (view file-contents) "\n"
                           (view (. (or completions.items completions) i) {:escape-newlines? true})))))

    (if (= (type expected) :table)
      (each [_ e (ipairs expected)]
        (let [i (find client completions e)]
          (faith.is i (.. "Didn't get completion: " (view e) "\n"
                          "from:    " (view file-contents) "\n"
                          (if (= (type e) :table)
                            (let [candidate (find client completions {:label e.label})]
                              (if candidate
                                (.. "Candidate that didn't match:\n"
                                    (view (. (or completions.items completions) candidate)
                                          {:escape-newlines? true}))
                                ""))
                            "")))))
      (expected completions))))

(fn test-global []
  (check "(" [{:label :setmetatable :kind kinds.Function}] [])
  (check "(" [:_G :debug :table :io :getmetatable :setmetatable :_VERSION
              :ipairs :pairs :next] [:this-is-not-a-global])
  (check "#nil\n(" [:_G :debug :table :io :getmetatable :setmetatable
                    :_VERSION :ipairs :pairs :next] [])
  (check "(if ge" [:getmetatable] [])
  (check "(table.i" [:table.insert] [])
  (check "(tablei" [:table.insert] [])
  nil)

(fn test-local []
  (check "(local x 10)\n(print |)" [:x] [:+])
  (check "(local x (doto 10 or and +))\n(print |)" [:x] [])
  (check "(local x 10)\n|\n" [:x] [])
  (check "(do (local x 10))\n|" [] [:x])
  (check "(let [foo 10 bar 20]
            |)" [:foo :bar] [])
  (check "(let [foo 10]
            (let [bar 20]
              |))" [:foo :bar] [])
  (check "(let [foo 10]
            (let [bar 20]
              fo|))" [:foo :bar] [])
  (check "(let [foo 10]
            (let [bar 20]
              |" [:foo :bar] [])
  (check "(let [foo 10]
            (let [bar 20]
              fo|" [:foo :bar] [])
  (check "(local foo 10)
          (local bar (let [y foo] |" [:foo :y] [])
  (check "(let [foo 10
                bar 20
                _ |" [:foo :bar] [])
  (check "(let [foo 10
                bar 20
                _ fo|" [:foo :bar] [])
  (check "(local x {:field 100})\n(if x.fi" [:x.field] [])
  (check "(let [x 10] (let [x 10] x"
         (fn [completions]
           (faith.= 1 (accumulate [number-of-x 0 _ completion (ipairs completions.items)]
                        (if (= completion.label :x)
                          (+ number-of-x 1)
                          number-of-x))))
         [])
  ;; stretchy completions
  (check "(local x {:field 100})\n(if fi" [:x.field] [])
  (check "(local x {:field {:deep 100}})\n(if de" [:x.field.deep] [])
  (check "(local t {:field (fn [foo] nil)})\n(t|" [:t.field] [])
  (check "(local t {:field (fn [self] nil)})\n(t|" [:t:field] [])
  (check "(local t {})\n(fn t.field [foo] nil)\n(t|" [:t.field] [])
  (check "(local t {})\n(fn t.field [self] nil)\n(t|" [:t:field] [])
  nil)

(fn test-builtin []
  (check "(|)" [:do :let :fn :doto :-> :-?>> :?.] [])
  ;; it's not the language server's job to do filtering,
  ;; so there's no negative assertions here for other symbols
  (check "(d|)" [:do :doto] [])
  ;; in fact, for fuzzy-matching clients, you especially want to make sure the server isn't filtering
  (check "(t|)" [:doto :setmetatable] [])
  ;; specials only are suggested in callable positions
  (check "(do |)" [] [:do :let :fn :-> :-?>> :?.])
  (check "|\n" [] [:do :let :fn :-> :-?>> :?.])
  (check "d|\n" [] [:do :let :fn :-> :-?>> :?.])
  nil)

(fn test-macro []
  (check "(macro funny [] `nil)\n(|)" [:funny] [])
  nil)

(fn test-local-in-macro []
  (check "(local item 10)\n(doto it|)" [:item] [])
  (check "(local item 10)\n(doto |)" [:item] [])
  (check "(local item 10)\n(case 1 1 it|)" [:item] [])
  (check "(local item 10)\n(case 1 1 |)" [:item] [])
  nil)

(fn test-fn-arg []
  (check "(fn [x] (print x))\n" [] [:x])
  (check "(fn [x] (print x))\n(print " [] [:x])
  (check "(fn foo [z]\n  (let [x 10 y 20]\n    |" [:x :y :z] [])
  (check "(fn foo [arg1 arg2 arg3]\n  |)" [:arg1 :arg2 :arg3] [])
  (check "(fn foo [arg1 arg2 arg3]\n  (do (do (do |))))" [:arg1 :arg2 :arg3] [])
  nil)

(fn test-field []
  (check "(local x {:field (fn [self])})\n(x:" [:x:field] [])
  (check "(local x {:field (fn [self])})\n(x:fi|" [:x:field] [])
  ;; regression test for not crashing
  (check "(local x {:field (fn [self])})\n(x::f" [] [])
  (check
    "(let [my-table {:foo 10 :bar 20}]\n  my-table.|)))"
    [{:label :my-table.foo :kind kinds.Value}
     {:label :my-table.bar :kind kinds.Value}]
    [])
  (check
    {:main.fnl "(let [foo (require :fooo)]
                    foo.|)))"
     :fooo.fnl "(fn my-export [x] (print x))
                {: my-export :constant 10}"}
    [:foo.my-export :foo.constant]
    [])
  (check
    {:main.fnl "(let [foo (require :fooo)]
                    foo.|)))"
     :fooo.fnl "(local M {:constant 10})
                (fn M.my-export [x] (print x))
                M"}
    [:foo.my-export :foo.constant]
    [])
  nil)

(fn test-docs []
  ;; things that aren't present in lua5.4 but are in other versions, I guess??
  (local things-that-are-allowed-to-have-missing-docs
    {:lua 1 :set-forcibly! 1}) ;:unpack 1 :setfenv 1 :getfenv 1 :module 1 :newproxy 1 :gcinfo 1 :loadstring 1 :bit 1 :jit 1 :bit32 1})

  (check "(let [x (fn x [a b c]
                    \"docstring\"
                     nil)
                t {: x}]
            (t."
    [:x]
    [{:documentation #(= nil $)}
     {:kind #(= nil $)}
     {:label #(= nil $)}])

  (each [_ mode (ipairs [true false])]
    (check "(fn x [a b c]
            \"docstring\"
            nil)
          (let [str :hi]
            (|))"
      [;; builtin specials
       {:label :local
        :kind kinds.Operator
        :documentation true}
       ;; builtin macros
       {:label :-?>
        :kind kinds.Keyword
        :documentation true}
       ;; builtin globals
       {:label :table
        :kind kinds.Module
        :documentation true}
       {:label :_G
        :kind kinds.Variable
        :documentation true}
       ;; method fields
       {:label :str:gsub :kind kinds.Method :documentation true}
       {:label :str:match :kind kinds.Method :documentation true}
       {:label :str:match :kind kinds.Method :documentation true}
       {:label :str:sub :kind kinds.Method :documentation true}
       {:label :str:len :kind kinds.Method :documentation true}
       {:label :str:find :kind kinds.Method :documentation true}
       ;; things in scope
       {:label :x :kind kinds.Function :documentation true}]
      [{:documentation #(= nil $) :label #(not (. things-that-are-allowed-to-have-missing-docs $))}
       {:kind #(= nil $)          :label #(not (. things-that-are-allowed-to-have-missing-docs $))}
       {:label #(= nil $)}]
      mode))
  nil)

(fn test-module []
  (check "(coroutine.y|"
    [{:label "coroutine.yield"
      :documentation #(and $.value ($.value:find "```fnl\n(coroutine.yield ...)\n```" 1 true))}]
    [{:documentation #(= nil $)}])
  (check "(local c coroutine)
          (c.y"
    ["coroutine.yield" "c.yield"]
    [{:documentation #(= nil $)}])
  (check "(local t table)
          (t.i"
    ["table.insert" "t.insert"]
    [{:documentation #(= nil $)}])
  (check "debug.deb|"
    [{:label "debug.debug"
      :documentation #(and $.value ($.value:find "```fnl\n(debug.debug)\n```" 1 true))}]
    [])
  nil)

(fn test-destructure []
  ;; this is in a destructure location, so we don't want all the normal completions
  (check "(local |)
          (print foo)"
    [:foo]
    [:math])
  (check "(local f|)
          (print foo)"
    [:foo]
    [:math])
  (check "(let [f|]
            (print foo))"
    [:foo]
    [:math])
  (check "(let [foo |] ; cursor is in an expression so we want expressions now
            (print foo))"
    [:math]
    [])
  nil)

(fn test-no-completion []
  (check "; ("
    []
    [:math])
  (check "\" (|\n\""
    []
    [:math])
  (check "\"\n(|\""
    []
    [:math])
  nil)

;; ;; Future tests / features
;; ;; Scope Ordering Rules
;; (it "does not suggest locals past the suggestion location when a symbol is partially typed")
;; (it "does not suggest locals past the suggestion location without a symbol")
;; (it "does not suggest locals past the suggestion point at the top level")
;; (it "does not suggest items from later definitions in the same `let`")
;; (it "does suggest items from earlier definitions in the same `let`")
;; (it "does not suggest macros defined from later definitions")

  ;; (it "offers rich information about module completions")
  ;; (it "offers rich information about macro-module completions")))
;; (it "suggests known module names in `require` and `include` and `import-macros` and `require-macros` and friends")
;; (it "suggests known fn keys when using the `:` special")
;; (it "suggests known keys when using the `.` special")
;; (it "does not suggest special forms for the \"call\" position when a list isn't actually a call, ie destructuring assignment")
;; (it "suggests keys when typing out destructuring, as in `(local {: typinghere} (require :mod))`")
;; (it "only suggests tables for `ipairs` / begin work on type checking system")

{: test-global
 : test-local
 : test-builtin
 : test-macro
 : test-local-in-macro
 : test-fn-arg
 : test-field
 : test-docs
 : test-module
 : test-destructure
 : test-no-completion}
