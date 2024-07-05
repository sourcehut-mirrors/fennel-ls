"Searcher
This module is responsible for resolving (require) calls. It has all the logic
for using the name of a module and find the corresponding URI.
I suspect this file may be gone after a bit of refactoring."

(local utils (require :fennel-ls.utils))

(local sep (package.config:sub 1 1))

(λ absolute? [path]
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
    (: :gsub "%.\\" "")
    (: :gsub "\\+" "\\")
    ;; modern society
    (: :gsub "%./" "")
    (: :gsub "/+" "/")
    (->> (pick-values 1))))

(λ add-workspaces-to-path [path ?workspaces]
  "Make every relative path be relative to every workspace."
  (let [result []]
    (each [path (path:gmatch "[^;]+")]
      (if (absolute? path)
        (table.insert result path)
        (each [_ workspace (ipairs (or ?workspaces []))]
          (table.insert result (join (utils.uri->path workspace) path)))))
    (table.concat result ";")))

(fn file-exists? [server uri]
   (or (?. server.preload uri)
       (case (io.open (utils.uri->path uri))
         f (do (f:close) true))))

(λ lookup [{:configuration {: fennel-path} :root-uri ?root-uri &as server} mod]
  "Use the fennel path to find a file on disk"
  (when ?root-uri
    (let [mod (mod:gsub "%." sep)
          root-path (utils.uri->path ?root-uri)]
      (accumulate [uri nil
                   segment (fennel-path:gmatch "[^;]+")
                   &until uri]
        (let [segment (segment:gsub "%?" mod)
              segment (if (absolute? segment)
                        segment
                        (join root-path segment))
              segment (utils.path->uri segment)]
          (if (file-exists? server segment)
            segment))))))

{: lookup
 : add-workspaces-to-path}
