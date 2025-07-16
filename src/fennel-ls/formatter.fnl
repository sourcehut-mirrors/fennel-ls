"Formatter
This module is for converting various objects to markdown that needs to be
shown to the client in tooltips and other notification messages. It is NOT for
formatting user code. Fennel-ls doesn't support user-code formatting as of now."

(local {: sym?
        : view
        : table?
        : varg?
        : list?} (require :fennel))

(local navigate (require :fennel-ls.navigate))

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
    (pick-values 1
      (: (view (collect [k v (pairs arg)]
                 ;; we don't want to view `v` because it's already been rendered
                 k (unview (render-arg v)))
           {:one-line? true
            :prefer-colon? true})
         ;; transform {:key key} to {: key}
         :gsub ":([%w?_-]+) ([%w?_-]+)([ }])"
         #(if (= $1 $2)
            (.. ": " $2 $3))))
    (tostring arg)))

(fn fn-signature-format [special ?name args]
  "Returns the LSP-formatted signature and parameters objects"
  (fn render-arglist [arglist offset]
    (var offset offset)
    (icollect [_ arg (ipairs arglist)]
      (let [rendered {:label [offset (+ offset (length arg))]}]
        (set offset (+ 1 (. rendered :label 2)))
        rendered)))

  (let [name (tostring (or ?name special))
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

(λ signature-help-format [doc-or-definition]
  "Return a SignatureInformation lsp object

  symbol can be an actual ast symbol or a binding object from a docset"
  (case-try (analyze-fn doc-or-definition.definition)
    {:fntype ?fntype :name ?name :arglist ?arglist :docstring ?docstring}
    (fn-signature-format ?fntype ?name ?arglist)
    (signature parameters)
    {:label signature
     :documentation ?docstring
     :parameters parameters}
    ;; if we couldn't get the info from the ast, try the metadata
    (catch _ (case-try doc-or-definition
               {: binding :metadata {:fnl/arglist arglist
                                     :fnl/docstring docstring}}
               (fn-signature-format "" binding arglist)
               (signature parameters)
               {:label signature
                :documentation docstring
                :parameters parameters}
               (catch _ {:parameters []
                         :label (.. "ERROR: don't know how to format "
                                  (view doc-or-definition {:one-line? true :depth 3}))
                         :documentation (code-block
                                           (view doc-or-definition {:depth 3}))})))))
(λ get-stub [server name definition ?short]
  "gets a string representation of this object"
  (or (case definition.definition
        ast (case (type ast)
              (where _ (varg? ast)) (view ast)
              (where _ (sym? ast :nil)) "nil"
              (where (or :string :number :boolean)) (view ast {:prefer-colon? true})
              (where _ (table? ast))
              (if ?short
                "{...}"
                (let [t (collect [k v (navigate.iter-fields server definition)]
                          k (unview (get-stub server (.. name "." k) v true)))]
                  (view t)))))
      (case definition.definition
        (where [hfn body]
               (list? definition.definition)
               (sym? hfn :hashfn))
        (.. "#" (view body {:one-line? true})))
      (case (navigate.getmetadata server definition)
        metadata
        (if metadata.fnl/arglist
          (.. "("
              (table.concat (icollect [_ arg (ipairs metadata.fnl/arglist) &into [name]]
                                (render-arg arg))
                            " ")
              ")")
          ?short
          "{...}"
          (let [t (collect [k v (navigate.iter-fields server definition)]
                    k (unview (get-stub server (.. name "." k) v true)))]
            (view t {:prefer-colon true}))))
      (when definition.indeterminate
        "?")
      (view (or definition.binding definition.definition))))

(λ hover-format [server name definition ?opts]
  "Format code that will appear when the user hovers over a symbol"
  {:kind "markdown"
   :value (.. (code-block (get-stub server name definition))
              (case (navigate.getmetadata server definition)
                {: fnl/docstring}
                (.. "\n---\n" fnl/docstring)
                _ "")
              (case (?. ?opts :macroexpansion)
                macroexpansion
                (.. "\n---\n"
                    "Macro expands to:\n"
                    (code-block macroexpansion))
                _ ""))})

;; CompletionItemKind
(local kinds
 {:Text 1 :Method 2 :Function 3 :Constructor 4 :Field 5 :Variable 6 :Class 7
  :Interface 8 :Module 9 :Property 10 :Unit 11 :Value 12 :Enum 13 :Keyword 14
  :Snippet 15 :Color 16 :File 17 :Reference 18 :Folder 19 :EnumMember 20
  :Constant 21 :Struct 22 :Event 23 :Operator 24 :TypeParameter 25})

(λ completion-item-format [server name definition range ?kind]
  "Makes a completion item"
  {:label name
   :documentation (when (not server.can-do-good-completions?) (hover-format server name definition))
   :textEdit (when (not server.can-do-good-completions?) {:newText name : range})
   :kind (or (?. kinds ?kind)
             (if (name:find ".:") kinds.Method)
             (case (navigate.getmetadata server definition)
               metadata (?. kinds metadata.fls/itemKind))
             kinds.Value)})

{: signature-help-format
 : hover-format
 : completion-item-format}
