(local util (require :fennel-ls.util))
(local mod (require :fennel-ls.mod))

(local {: analyze} (require :fennel-ls.plugin))

(λ init-state [self params]
  (set self.files {})
  (set self.modules {})
  (set self.root-uri params.rootUri))

(λ read-file [uri]
  (with-open [fd (io.open (util.uri->path uri))]
    {:uri uri
     :text (fd:read :*a)}))

(λ get-by-uri [self uri]
  (or (. self.files uri)
      (let [file (read-file uri)]
        (analyze file)
        (tset self.files uri file)
        file)))

(λ get-by-module [self module]
  (match (. self.modules module)
    uri (or (get-by-uri self uri)
          ;; if the cached uri isn't found, clear the cache and try again
          (do (tset self.modules module nil)
              (get-by-module self module)))
    nil (let [uri (mod.lookup self module)]
          (tset self.modules module uri)
          (get-by-uri self uri))))

(λ set-uri-contents [self uri text]
  (if (. self.files uri)
    ;; modify existing file
    (let [file (. self.files uri)]
      (when (not= text file.text)
        (set file.text text)
        (analyze file)
        file))
    ;; create new file
    (let [file {: uri : text}]
        (tset self.files uri file)
        (analyze file)
        file)))


{: get-by-uri
 : get-by-module
 : set-uri-contents
 : init-state}
