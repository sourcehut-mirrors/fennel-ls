"State
This module keeps track of the state of the language server:
* Settings
* Loaded files

There is no global state in this project: all state is stored
in the \"server\" object."

(local searcher (require :fennel-ls.searcher))
(local utils (require :fennel-ls.utils))
(local {: compile} (require :fennel-ls.compiler))

(λ read-file [server uri]
  (case (?. server.preload uri)
    preload {: uri :text preload}
    _ (case (io.open (utils.uri->path uri) "r")
        file (let [text (file:read :*a)]
               (file:close)
               {: uri : text}))))

(λ get-by-uri [server uri]
  (or (. server.files uri)
      (case (read-file server uri)
        file (do
               (compile server file)
               (tset server.files uri file)
               file))))

(λ get-by-module [server module]
  ;; check the cache
  (case (. server.modules module)
    uri
    (or (get-by-uri server uri)
        ;; if the cached uri isn't found, clear the cache and try again
        (do (tset server.modules module nil)
            (get-by-module server module)))
    nil
    (case (searcher.lookup server module)
      uri
      (do
        (tset server.modules module uri)
        (get-by-uri server uri)))))

(λ set-uri-contents [server uri text]
  (case (. server.files uri)
    ;; modify existing file
    file
    (do
      (when (not= text file.text)
        (set file.text text)
        (compile server file))
      file)

    ;; create new file
    nil
    (let [file {: uri : text}]
      (tset server.files uri file)
      (compile server file)
      file)))

(λ flush-uri [server uri]
  "get rid of data about a file, in case it changed in some way"
  (tset server.files uri nil))

{: flush-uri
 : get-by-module
 : get-by-uri
 : set-uri-contents
 : read-file}
