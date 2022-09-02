"Formatter
This module is for formatting code that needs to be shown to the client
in tooltips and other notification messages. It is NOT for formatting
user code."

(local {: sym
        : sym?
        : view
        : list} (require :fennel))
(local {: type=} (require :fennel-ls.utils))


(local -fn- (sym :fn))
(local -varg- (sym :...))

(λ code-block [str]
  (.. "```fnl\n" str "\n```"))

(local width 80)
(fn fn-format [special name args docstring]
  (.. (code-block (.. "(fn"
                     (if name (.. " " (tostring name)) "")
                     (.. " " (view args
                               {:one-line? true
                                :prefer-colon? true}))
                     " ...)"))
      (if docstring (.. "\n" docstring) "")))


(λ fn? [sym]
  (if (sym? sym)
    (let [sym (tostring sym)]
      (or (= sym "fn")
          (= sym "λ")
          (= sym "lambda")))))

(λ hover-format [result]
  "Format code that will appear when the user hovers over a symbol"
  (match result.definition
    ;; name + docstring
    (where [special name args docstring body]
      (fn? special)
      (sym? name)
      (type= args :table)
      (type= docstring :string))
    (fn-format special name args docstring)
    ;; docstring
    (where [special args docstring body]
      (fn? special)
      (type= args :table)
      (type= docstring :string))
    (fn-format special nil args docstring)
    ;; name
    (where [special name args]
      (fn? special)
      (sym? name)
      (type= args :table))
    (fn-format special name args nil)
    ;; none
    (where [special args]
      (fn? special)
      (type= args :table))
    (fn-format special nil args nil)
    ?anything-else
    (code-block
      (if (-?>> result.keys length (< 0))
        (.. "ERROR, I don't know how to show this "
            "(. "
            (view ?anything-else {:prefer-colon? true}) " "
            (view result.keys {:prefer-colon? true}) ")")
        (view ?anything-else {:prefer-colon? true})))))

{: hover-format}
