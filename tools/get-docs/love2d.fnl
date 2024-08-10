(local fennel (require :deps.fennel))
(local {:clone git-clone} (require :tools.util.git))

(local love-api-build-directory :build/love-api)
(local require-love-api
       (partial require (.. love-api-build-directory :/love_api)))

(local stringify-table fennel.view)

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
            (if (?. result k)
                (values k (merge v (. result k)))
                (values k v)))))))

(fn fn-arguments->names [arguments]
  "Given an array of arguments, return all names as an array."
  (icollect [_i {:description _ : name :type _} (ipairs arguments)]
    name))

(fn fn-return->string [returns]
  "Given an array of arguments, return a formatted description."
  (accumulate [x "\n\nReturns -" _i {: description : name :type return-type} (ipairs returns)]
    (.. x "\n" " * " name " (`" return-type "`) - " description)))

(fn parse-fn-variant [variant]
  "Given an array of fuction variants, return an object where the first variant
   is made the formatted LSP option, with any remaining variants being formatted
   as a single description."
  (collect [v-key v-value (pairs variant)]
    (case v-key
      :returns (values :returns v-value)
      :arguments (values :args (fn-arguments->names v-value)))))

; (fn build-arg-name-list [arguments-tbl]
;   "Returns a list of all argument names"
;   (print (.. "CHECK OUT THIS TABLE —" (fennel.view arguments-tbl)))
;   (icollect [_ v (ipairs arguments-tbl)]
;     v.name))

(fn build-lsp-value [name ?args ?docstring]
  "Takes ... and returns a table to be used with the LSP."
  (let [lsp-value {:binding name :metadata {}}]
    (when ?args (set lsp-value.metadata.fnl/arglist ?args))
    (when ?docstring (set lsp-value.metadata.fnl/docstring ?docstring))
    lsp-value))

; TODO - This function takes the functions object directly, then it can be used
; for any high-level object.

(fn get-love-functions [docs-tbl]
  "Takes the LÖVE-API documentation table and generates a list of the
   library-level functions suitable for the Fennel LSP."
  (collect [_i value (ipairs docs-tbl)]
    (let [{: name : description} value
          ?variants (?. value :variants)
          first-variant (if ?variants
                            (parse-fn-variant (. ?variants 1))
                            nil)
          ?args (?. first-variant :args)
          ?returns (?. first-variant :returns)
          docstring (.. description (if ?returns (fn-return->string ?returns)
                                        ""))]
      (values name (build-lsp-value name ?args docstring)))))

(fn convert []
  (download-love-api-tooling!)
  (let [love-docs-tbl (require-love-api)
        love-doc-string (.. "LÖVE is a framework for making "
                            "2D games in the Lua programming language.")
        love-docs (build-lsp-value :love nil love-doc-string)
        love-functions {:fields (get-love-functions love-docs-tbl.functions)}
        love-callbacks {:fields (get-love-functions love-docs-tbl.callbacks)}]
    (stringify-table {:love (merge love-docs love-functions love-callbacks)})))

{: convert}
