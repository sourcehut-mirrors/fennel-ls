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
(fn fn-format [name args docstring]
  (.. "(fn"
      (if name (.. " " (tostring name)) "")
      (.. " " (view args {:one-line? true :prefer-colon? true}))
      " ...)"
      (if docstring (.. "\n" docstring) "")))

(λ hover-format [result]
  (code-block
      (match result.?definition
        ;; name + docstring
        (where [-fn- name args docstring body]
          (and (sym? name)
               (type= args :table)
               (type= docstring :string)))
        (fn-format name args docstring)
        ;; docstring
        (where [-fn- args docstring body]
          (and (type= args :table)
               (type= docstring :string)))
        (fn-format nil args docstring)
        ;; name
        (where [-fn- name args]
          (and (sym? name)
               (type= args :table)))
        (fn-format name args nil)
        ;; none
        (where [-fn- args]
          (and (type= args :table)))
        (fn-format nil args nil)
        ?anything-else
        (if result.?keys
          (view result.?keys)
          (view ?anything-else {:prefer-colon? true})))))

{: hover-format}
