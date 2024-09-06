(local fennel (require :deps.fennel))
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

(fn download-love-api-tooling! []
  "Clones the LÖVE-API git repository that contains tooling to scrape and
   convert the LÖVE Wiki into a Lua table."
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
(fn variant-arguments->names [arguments]
  "Given an array of arguments, return all names as an array."
  (icollect [_i {:description _ : name :type _} (ipairs arguments)]
    name))

(fn variant-return->string [returns]
  "Given an array of return values, return a formatted description."
  (accumulate [x "\n\nReturns -" _i {: description : name :type return-type} (ipairs returns)]
    (.. x "\n" " * " name " (`" return-type "`) - " description)))

(fn parse-first-function-variant [[variant]]
  "Given an array of fuction variants, format and return the first variant
   for the LSP."
  (collect [v-key v-value (pairs variant)]
    (case v-key
      :returns (values :returns (variant-return->string v-value))
      :arguments (values :args (variant-arguments->names v-value)))))

(fn love-functions->lsp [docs-tbl prefix]
  "Given an array of documented functions for a LÖVE module, generate a table
   for the Fennel LSP."
  (collect [_i value (ipairs docs-tbl)]
    (let [{: name : description} value
          binding (.. prefix name)
          ?variants (?. value :variants)
          first-variant (if ?variants
                            (parse-first-function-variant ?variants)
                            nil)
          ?args (?. first-variant :args)
          ?returns (or (?. first-variant :returns) "")
          docstring (.. description ?returns)]
      (values name (build-lsp-value binding ?args docstring)))))

(fn module-list->fields [modules ?prefix]
  "Given a list of LÖVE modules from the LÖVE-API Lua library, recursively
   generate LSP data for Fennel."
  (collect [_i module (ipairs modules)]
    (let [{: name} module ; Other keys - :enum, :functions, :types
          prefix (if ?prefix (.. ?prefix ".") "")
          binding (.. prefix name)
          ?docstring (?. module :description)
          ?functions (?. module :functions)
          ?modules (?. module :modules)
          function-keys (if ?functions
                            (love-functions->lsp ?functions (.. binding "."))
                            {})
          module-keys (if ?modules (module-list->fields ?modules binding) {})
          fields (merge function-keys module-keys)]
      (values name (build-lsp-value binding nil ?docstring fields)))))

(fn get-all-love-api-functions [love-api]
  [(table.unpack love-api.functions) (table.unpack love-api.callbacks)])

(fn love-api->lsp [love-api]
  "Given documentation for the entire LÖVE framework from the LÖVE-API Lua
   library, generate the root LÖVE object suitable for the Fennel LSP."
  (let [root-module {:description (.. "LÖVE is a framework for making 2D "
                                      "games in the Lua programming language.")
                     :functions (get-all-love-api-functions love-api)
                     :modules love-api.modules
                     :name :love}]
    (module-list->fields [root-module])))

(fn convert []
  "Convert LÖVE framework from Lua table to a configuration object
   used by fennel-ls."
  (download-love-api-tooling!)
  (let [love-api (require-love-api)]
    (fennel.view (love-api->lsp love-api))))

{: convert}
