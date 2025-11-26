"Files
This module has high level helpers for creating/getting \"file\" objects."

(local searcher (require :fennel-ls.searcher))
(local {: uri->path} (require :fennel-ls.uri))

(λ read-file [server uri]
  ;; preload is here so that tests can inject files
  (case (?. server.preload uri)
    preload {: uri :text preload}
    _ (case uri
        :stdin (let [text (io.read :*a)]
                 {: uri : text})
        _ (case (io.open (uri->path uri) "r")
            file (let [text (file:read :*a)]
                   (when (not text)
                     (error (.. "could not read file:" (uri->path uri))))
                   (file:close)
                   {: uri : text})))))

(λ get-by-uri [server uri]
  (or (. server.files uri)
      (case (read-file server uri)
        file (do
               (tset server.files uri file)
               file))))

(λ get-by-module [server module macro?]
  (let [modules (if macro? server.macro-modules server.modules)]
    ;; check the cache
    (case (. modules module)
      uri
      (or (get-by-uri server uri)
          ;; if the cached uri isn't found, clear the cache and try again
          (do (tset modules module nil)
              (get-by-module server module macro?)))
      nil
      (case (searcher.lookup server module macro?)
        uri
        (do
          (tset modules module uri)
          (get-by-uri server uri))))))

(λ set-uri-contents [server uri text]
  (let [file {: uri : text}]
    (tset server.files uri file)
    file))

(λ flush-uri [server uri]
  "get rid of data about a file, in case it changed in some way"
  (tset server.files uri nil))

{: flush-uri
 : get-by-module
 : get-by-uri
 : set-uri-contents
 : read-file}
