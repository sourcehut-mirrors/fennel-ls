(local fennel (require :fennel))

(local files (require :fennel-ls.files))
(local analyzer (require :fennel-ls.analyzer))
(local navigate (require :fennel-ls.navigate))
(local docs (require :fennel-ls.docs))

(local {: create-client} (require :test.utils))

(local get-deps (require :tools.get-deps))

;; ensure fennel source is present
(get-deps.get-fennel)

;; use fennel-ls to observe fennel/specials.fnl (make-compiler-env)
(local {: server : uri}
  (create-client {:main.fnl "(local {: make-compiler-env} (require :fennel.specials))
                             (make-compiler-env)"
                  :flsproject.fnl "{:fennel-path \"build/fennel/src/?.fnl\"}"}))

(set server.root-uri "file://.")

(local file (files.get-by-uri server uri))
(local result (analyzer.search server file (. file.ast (length file.ast)) {} {}))

;; convert results into a doc file

(tset (getmetatable (fennel.sym "x")) :__fennelview #(fennel.view (. $ 1)))
(fn into-doc [result]
  (if (= (type result.definition) :string)
    {:definition result.definition}
    {:metadata (navigate.getmetadata server result)
     :fields (if (navigate.has-fields server result)
               (collect [key field (navigate.iter-fields server result)]
                  key (into-doc field)))}))

(print (fennel.view (collect [key field (navigate.iter-fields server result)]
                      (if (and (not (docs.get-global server nil key))
                               (not (key:find "^_")))
                        (values key (into-doc field))))))
