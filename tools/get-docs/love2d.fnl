(local fennel (require :fennel))
(local {:clone git-clone} (require :tools.util.git))

(local love-api-build-directory :build/love-api)
(local require-love-api
       (partial require (.. love-api-build-directory :/love_api)))

;
; UTILS
; -----
(fn build-lsp-value [name ?args ?docstring ?fields]
  "Takes ... and returns a table to be used with the LSP."
  (let [lsp-value {:binding name}
        ?metadata (or ?args ?docstring)]
    (when ?metadata (set lsp-value.metadata {}))
    (when ?args (set lsp-value.metadata.fnl/arglist ?args))
    (when ?docstring (set lsp-value.metadata.fnl/docstring ?docstring))
    (when ?fields (set lsp-value.fields ?fields))
    lsp-value))

(fn clone-love-api! []
  (when (not (io.open :build/love-api))
    (git-clone love-api-build-directory
               "https://github.com/love2d-community/love-api")))

(fn merge [...]
  (let [arg-count (select "#" ...)
        args [...]]
    (if (= arg-count 0)
        {}
        (faccumulate [result {} i 1 arg-count]
          (collect [k v (pairs (. args i)) &into result]
            (values k v))))))

;
; PARSERS
; -------
(fn get-fn-argument-names [fn-arguments]
  "Given an array of arguments, return all names as an array."
  (icollect [_i {:description _ : name :type _} (ipairs fn-arguments)]
    name))

(fn format-description-of-fn-return-values [fn-returns]
  (accumulate [x "\n\nReturns -" _i {: description : name :type return-type} (ipairs fn-returns)]
    (.. x "\n" " * " name " (`" return-type "`) - " description)))

(fn parse-first-fn-variant [[variant]]
  "Given an array of fuction variants, format and return the first variant
   for the LSP."
  (collect [k v (pairs variant)]
    (case k
      :returns (values :returns (format-description-of-fn-return-values v))
      :arguments (values :args (get-fn-argument-names v)))))

(fn get-all-love-api-functions [love-api]
  [(table.unpack love-api.functions) (table.unpack love-api.callbacks)])

(fn love-functions->lsp-table [docs-tbl namespace]
  (collect [_i value (ipairs docs-tbl)]
    (let [{: name : description} value
          binding (.. namespace name)
          ?variants (?. value :variants)
          ; LÖVE functions have several variants, e.g. different arities or
          ; types; however, it's uncertain how to best display all of that
          ; information, so the first is selected here as a reasonable default.
          first-variant (if ?variants
                            (parse-first-fn-variant ?variants)
                            nil)
          ?args (?. first-variant :args)
          ?returns (or (?. first-variant :returns) "")
          docstring (.. description ?returns)]
      (values name (build-lsp-value binding ?args docstring)))))

(fn module-list->lsp-table [modules ?namespace]
  (collect [_i module (ipairs modules)]
    (let [{: name} module ; Other keys - :enum, :functions, :types
          namespace (if ?namespace (.. ?namespace ".") "")
          binding (.. namespace name)
          ?docstring (?. module :description)
          ?functions (?. module :functions)
          ?modules (?. module :modules)
          function-keys (if ?functions
                            (love-functions->lsp-table ?functions (.. binding "."))
                            {})
          module-keys (if ?modules (module-list->lsp-table ?modules binding) {})
          fields (merge function-keys module-keys)]
      (values name (build-lsp-value binding nil ?docstring fields)))))

(fn love-api->lsp-table [love-api]
  (let [root-module {:description (.. "LÖVE is a framework for making 2D "
                                      "games in the Lua programming language.")
                     :functions (get-all-love-api-functions love-api)
                     :modules love-api.modules
                     :name :love}]
    (module-list->lsp-table [root-module])))

(fn convert []
  "Download documentation for the LÖVE framework via the love-api repo and
   convert it to a Lua table usable for fennel-ls."
  (clone-love-api!)
  (let [love-api (require-love-api)]
    (fennel.view (love-api->lsp-table love-api))))

{: convert}
