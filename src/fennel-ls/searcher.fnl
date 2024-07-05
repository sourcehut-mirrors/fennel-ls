"Searcher
This module is responsible for resolving (require) calls. It has all the logic
for using the name of a module and find the corresponding URI.
I suspect this file may be gone after a bit of refactoring."

(local {: absolute-path?
        : uri->path
        : path->uri
        : path-sep
        : path-join} (require :fennel-ls.utils))

(λ add-workspaces-to-path [path ?workspaces]
  "Make every relative path be relative to every workspace."
  (let [result []]
    (each [path (path:gmatch "[^;]+")]
      (if (absolute-path? path)
        (table.insert result path)
        (each [_ workspace (ipairs (or ?workspaces []))]
          (table.insert result (path-join (uri->path workspace) path)))))
    (table.concat result ";")))

(fn file-exists? [server uri]
   (or (?. server.preload uri)
       (case (io.open (uri->path uri))
         f (do (f:close) true))))

(λ lookup [{:configuration {: fennel-path} :root-uri ?root-uri &as server} mod]
  "Use the fennel path to find a file on disk"
  (when ?root-uri
    (let [mod (mod:gsub "%." path-sep)
          root-path (uri->path ?root-uri)]
      (accumulate [uri nil
                   segment (fennel-path:gmatch "[^;]+")
                   &until uri]
        (let [segment (segment:gsub "%?" mod)
              segment (if (absolute-path? segment)
                        segment
                        (path-join root-path segment))
              segment (path->uri segment)]
          (if (file-exists? server segment)
            segment))))))

{: lookup
 : add-workspaces-to-path}
