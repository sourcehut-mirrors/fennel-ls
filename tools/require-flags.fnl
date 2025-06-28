;; We only want to include our vendored files
;; If we're falling back to the user's system files, require can find them at runtime; no need to include
(local skip-when-file-not-present [[:fennel :deps/fennel.lua]
                                   [:dkjson :deps/dkjson.lua]])

;; The fennel.compiler module has no file to include
(local always-skip [:fennel.compiler])

(local skip (icollect [_ [module file] (ipairs skip-when-file-not-present)
                       &into always-skip]
              (if (not (io.open file "r"))
                  module)))

(when (< 0 (length skip))
  (print (.. "--skip-include " (table.concat skip ","))))
