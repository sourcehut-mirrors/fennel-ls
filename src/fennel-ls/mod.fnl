"Mod
This file has all the logic needed to take the name of a module and find the corresponding URI.
I suspect this file is going to be gone after a bit of refactoring."

(local fennel (require :fennel))
(local stringx (require :pl.stringx))
(local plpath (require :pl.path))
(local util (require :fennel-ls.util))

"works on my machine >:)"
(local luapath "?.lua;src/?.lua")
(local fennelpath "?.fnl;src/?.fnl")

(fn add-workspaces-to-path [path ?workspaces]
  (let [paths (stringx.split path ";")
        result []]
    (each [_ path (ipairs paths)]
      (if (plpath.isabs path)
        (table.insert result path)
        (each [_ space (ipairs (or ?workspaces []))]
          (table.insert result (plpath.normpath (plpath.join (util.uri->path space) path))))))
    (table.concat result ";")))

(fn lookup [{: root-uri} mod]
  (match (or (fennel.searchModule mod (add-workspaces-to-path luapath [root-uri]))
             (fennel.searchModule mod (add-workspaces-to-path fennelpath [root-uri])))
    modname (util.path->uri modname)
    nil nil))

{: lookup}
