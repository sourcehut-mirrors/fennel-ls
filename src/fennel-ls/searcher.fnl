"Searcher
This file has all the logic needed to take the name of a module and find the corresponding URI.
I suspect this file is going to be gone after a bit of refactoring."

(local fennel (require :fennel))
(local utils (require :fennel-ls.utils))

"works on my machine >:)"
(local luapath "?.lua;src/?.lua")
(local fennelpath "?.fnl;src/?.fnl")

(local sep (package.config:sub 1 1))

(λ is_absolute [path]
  (or
    ;; windows
    (-> path
     (: :sub 2 3)
     (: :match ":\\"))
    ;; modern society
    (= (path:sub 1 1) "/")))

(λ join [path suffix]
  (-> (.. path sep suffix)
    ;; delete duplicate
    ;; windows
    (: :gsub "\\+" "\\")
    ;; modern society
    (: :gsub "/+" "/")
    (->> (pick-values 1))))

(λ add-workspaces-to-path [path ?workspaces]
  "Make every relative path be relative to every workspace."
  (let [result []]
    (each [path (path:gmatch "[^;]+")]
      (if (is_absolute path)
        (table.insert result path)
        (each [_ workspace (ipairs (or ?workspaces []))]
          (table.insert result (join (utils.uri->path workspace) path)))))
    (table.concat result ";")))

(λ lookup [{: root-uri} mod]
  (match (or (fennel.searchModule mod (add-workspaces-to-path luapath [root-uri]))
             (fennel.searchModule mod (add-workspaces-to-path fennelpath [root-uri])))
    modname (utils.path->uri modname)
    nil nil))

{: lookup}
