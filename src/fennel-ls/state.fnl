"State
This module keeps track of the state of the language server.
There are helpers to get file objects, and in the future, there
will be functions for managing user options. There is no global
state in this project: all state will be stored in the \"self\"
object."

(local utils (require :fennel-ls.utils))
(local searcher (require :fennel-ls.searcher))
(local {: compile} (require :fennel-ls.compiler))

(λ init-state [self params]
  (set self.files {})
  (set self.modules {})
  (set self.root-uri params.rootUri))

(λ read-file [uri]
  (with-open [fd (io.open (utils.uri->path uri))]
    {:uri uri
     :text (fd:read :*a)}))

(λ get-by-uri [self uri]
  (or (. self.files uri)
      (let [file (read-file uri)]
        (compile file)
        (tset self.files uri file)
        file)))

(λ get-by-path [self path]
  (get-by-uri (utils.path->uri path)))

(λ get-by-module [self module]
  ;; check the cache
  (match (. self.modules module)
    uri
    (or (get-by-uri self uri)
      ;; if the cached uri isn't found, clear the cache and try again
      (do (tset self.modules module nil)
          (get-by-module self module)))
    nil
    (match (searcher.lookup self module)
      uri
      (do
        (tset self.modules module uri)
        (get-by-uri self uri))
      nil
      (error (.. "cannot find module " module)))))

(λ set-uri-contents [self uri text]
  (match (. self.files uri)
    ;; modify existing file
    file
    (do
      (when (not= text file.text)
        (set file.text text)
        (compile file))
      file)

    ;; create new file
    nil
    (let [file {: uri : text}]
      (tset self.files uri file)
      (compile file)
      file)))

{: get-by-uri
 : get-by-module
 : set-uri-contents
 : init-state}
