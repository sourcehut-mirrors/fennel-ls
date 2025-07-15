(local {: view} (require :fennel))
(local lint (require :fennel-ls.lint))
(local utils (require :fennel-ls.utils))

(fn test-lints-are-documented []
  (each [_ lint (ipairs lint.list)]
    (let [name lint.name]
      (when (not= (type lint.what-it-does) "string") (error (.. name " needs a description of what it does in :what-it-does")))
      (when (not= (type lint.why-care?) "string") (error (.. name " needs a description of why the linted pattern is bad in :why-care?")))
      (when (not= (type lint.example) "string") (error (.. name " needs an example of broken and fixed code in :example")))
      (when (not= (type lint.since) "string") (error (.. name " needs version: :since " (view utils.version)))))))


;; other ideas:
;; selflint
;; docs on top of each file
;; makefile covers

{: test-lints-are-documented}
