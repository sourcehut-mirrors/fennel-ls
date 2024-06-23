;; There is no fennel.compiler module on disk to require.
;; It is part of fennel.lua, and doesn't need to be indcuded separately.
(local always-skip [:fennel.compiler])
(local skip-when-file-not-present [[:fennel :deps/fennel.lua]
                                   [:dkjson :deps/dkjson.lua]])

(local skip (icollect [_ [module file] (ipairs skip-when-file-not-present)
                       &into always-skip]
              (if (not (io.open file "r"))
                module)))

(when (< 0 (length skip))
  (print (.. "--skip-include " (table.concat skip ","))))


