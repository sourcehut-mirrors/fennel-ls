"Formatter
This module is for formatting code that needs to be shown to the client
in tooltips and other notification messages. It is NOT for formatting
user code. Fennel-ls doesn't support user-code formatting as of now."

(local {: sym?
        : view} (require :fennel))

(λ code-block [str]
  (.. "```fnl\n" str "\n```"))

(fn fn-format [special name args docstring]
  (.. (code-block (.. "("
                      (tostring special)
                      (if name (.. " " (tostring name)) "")
                      (.. " "
                          (: (view args
                               {:empty-as-sequence? true
                                :one-line? true
                                :prefer-colon? true})
                             :gsub ":([%w?_-]+) ([%w?]+)([ }])"
                             #(if (= $1 $2)
                                (.. ": " $2 $3))))
                      " ...)"))
      (if docstring (.. "\n" docstring) "")))

(fn metadata-format [{: binding : metadata}]
  "formats a special using its builtin metadata magic"
  (..
    (code-block
      (if (not metadata.fnl/arglist)
        (tostring binding)
        (= 0 (length metadata.fnl/arglist))
        (.. "(" (tostring binding) ")")
        (.. "(" (tostring binding) " " (table.concat metadata.fnl/arglist " ") ")")))
    "\n"
    (or metadata.fnl/docstring "")))

(λ fn? [symbol]
  (if (sym? symbol)
    (let [name (tostring symbol)]
      (or (= name "fn")
          (= name "λ")
          (= name "lambda")))))

(λ analyze-fn [?ast]
  "if ast is a function definition, try to fill out as much of this as possible:
{: name
 : arglist
 : docstring
 : fntype}
fntype is one of fn or λ or lambda"
  (case ?ast
    ;; name + docstring
    (where [fntype name arglist docstring body]
      body
      (fn? fntype)
      (sym? name)
      (= (type arglist) :table)
      (= (type docstring) :string))
    {: fntype : name : arglist : docstring}
    ;; docstring
    (where [fntype arglist docstring body]
      body
      (fn? fntype)
      (= (type arglist) :table)
      (= (type docstring) :string))
    {: fntype : arglist : docstring}
    ;; name
    (where [fntype name arglist]
      (fn? fntype)
      (sym? name)
      (= (type arglist) :table))
    {: fntype : name : arglist}
    ;; none
    (where [fntype arglist]
      (fn? fntype)
      (= (type arglist) :table))
    {: fntype : arglist}))

(λ hover-format [result]
  "Format code that will appear when the user hovers over a symbol"
  {:kind "markdown"
   :value
   (case (analyze-fn result.definition)
     {:fntype ?fntype :name ?name :arglist ?arglist :docstring ?docstring} (fn-format ?fntype ?name ?arglist ?docstring)
     _ (if (-?>> result.keys length (< 0))
         (code-block
           (.. "ERROR, I don't know how to show this "
               "(. "
               (view result.definition {:prefer-colon? true}) " "
               (view result.keys {:prefer-colon? true}) ")"))
         result.metadata
         (metadata-format result)
         (code-block
            (view result.definition {:prefer-colon? true}))))})

;; CompletionItemKind
(local kinds
 {:Text 1 :Method 2 :Function 3 :Constructor 4 :Field 5 :Variable 6 :Class 7
  :Interface 8 :Module 9 :Property 10 :Unit 11 :Value 12 :Enum 13 :Keyword 14
  :Snippet 15 :Color 16 :File 17 :Reference 18 :Folder 19 :EnumMember 20
  :Constant 21 :Struct 22 :Event 23 :Operator 24 :TypeParameter 25})

(λ completion-item-format [label result]
  "Makes a completion item"
  (doto
    (case (analyze-fn result.definition)
      {:fntype _} {: label
                   :kind (if (label:find ":") kinds.Method kinds.Function)}
      _ {: label
         :kind kinds.Variable})
    (tset :documentation (hover-format result))))

{: hover-format
 : completion-item-format}
