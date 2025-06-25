"Formatter
This module is for formatting code that needs to be shown to the client
in tooltips and other notification messages. It is NOT for formatting
user code. Fennel-ls doesn't support user-code formatting as of now."

(local {: sym?
        : view
        : table?} (require :fennel))
(local message (require :fennel-ls.message))

(λ code-block [str]
  (.. "```fnl\n" str "\n```"))

(local unview-mt {:__fennelview #$.value})
(fn unview [value]
  "Creates a value that renders to `value` when viewed"
  (setmetatable {: value} unview-mt))

(λ render-arg [arg]
  "Renders an argument to a string.
   Strings and symbols are treated the same.
   Fennel supports destructuring, so tables need to be rendered recursively.

   Examples:
      (render-arg :foo)       -> \"foo\"
      (render-arg (sym :foo)) -> \"foo\"
      (render-arg [:foo])       -> \"[foo]\"
      (render-arg [(sym :foo)]) -> \"[foo]\""
  (if (table? arg)
    (: (view (collect [k v (pairs arg)]
               ;; we don't want to view `v` because it's already been rendered
               k (unview (render-arg v)))
         {:one-line? true
          :prefer-colon? true})
       ;; transform {:key key} to {: key}
       :gsub ":([%w?_-]+) ([%w?_-]+)([ }])"
       #(if (= $1 $2)
          (.. ": " $2 $3)))
    (tostring arg)))

(fn fn-signature-format [special name args]
  "Returns the LSP-formatted signature and parameters objects"
  (fn render-arglist [arglist offset]
    (var offset offset)
    (icollect [_ arg (ipairs arglist)]
      (let [rendered {:label [offset (+ offset (length arg))]}]
        (set offset (+ 1 (. rendered :label 2)))
        rendered)))

  (let [name (tostring (or name special))
        args (case (type (?. args 1))
               :table (icollect [_ v (ipairs args)]
                        (render-arg v))
               _ args)
        ;; + 2 for the opening paren and the space
        args-offset (+ 2 (length name))]
    (values (.. "("
                name " "
                (table.concat args " ")
                ")")
            (render-arglist args args-offset))))

(fn fn-format [special name args docstring]
  (.. (code-block (fn-signature-format special name args))
      (if docstring (.. "\n---\n" docstring) "")))

(fn metadata-format [{: binding : metadata}]
  "formats a special using its builtin metadata magic"
  (..
    (code-block
      (if (not metadata.fnl/arglist)
        (tostring binding)
        (= 0 (length metadata.fnl/arglist))
        (.. "(" (tostring binding) ")")
        (.. "(" (tostring binding) " "
            (table.concat
              (icollect [_ v (ipairs metadata.fnl/arglist)]
                (render-arg v))
              " ")
            ")")))
    "\n---\n"
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

(λ signature-help-format [symbol]
  "Return a signatureHelp lsp object

  symbol can be an actual ast symbol or a binding object from a docset"
  (case-try (analyze-fn symbol.definition)
    {:fntype ?fntype :name ?name :arglist ?arglist :docstring ?docstring}
    (fn-signature-format ?fntype ?name ?arglist)
    (signature parameters)
    {:label signature
     :documentation ?docstring
     :parameters parameters}
    ;; if we couldn't get the info from the ast, try the metadata
    (catch _ (case-try symbol
               {: binding :metadata {:fnl/arglist arglist
                                     :fnl/docstring docstring}}
               (fn-signature-format "" binding arglist)
               (signature parameters)
               {:label signature
                :documentation docstring
                :parameters parameters}
               (catch _ {:parameters (message.array)
                         :label (.. "ERROR: don't know how to format "
                                  (view symbol {:one-line? true :depth 3}))
                         :documentation (code-block
                                           (view symbol {:depth 3}))})))))

(λ hover-format [result]
  "Format code that will appear when the user hovers over a symbol"
  {:kind "markdown"
   :value
   (case (analyze-fn result.definition)
     {:fntype ?fntype :name ?name :arglist ?arglist :docstring ?docstring}
     (fn-format ?fntype ?name ?arglist ?docstring)
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

(λ completion-item-format [server name definition range ?kind]
  "Makes a completion item"
  {:label name
   :documentation (when (not server.can-do-good-completions?) (hover-format definition))
   :textEdit (when (not server.can-do-good-completions?) {:newText name : range})
   :kind (or (when ?kind (. kinds ?kind))
             (. kinds (?. definition :metadata :fls/itemKind))
             (when (or (?. definition :metadata :fnl/arglist)
                       (?. (analyze-fn definition.definition)) :fntype)
                 (if (name:find ":") kinds.Method kinds.Function)))})

{: signature-help-format
 : hover-format
 : completion-item-format}
