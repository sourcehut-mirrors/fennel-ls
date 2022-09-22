"State
This module keeps track of the state of the language server.
There are helpers to get file objects, and in the future, there
will be functions for managing user options. There is no global
state in this project: all state will be stored in the \"self\"
object."

(local utils (require :fennel-ls.utils))
(local searcher (require :fennel-ls.searcher))
(local {: compile} (require :fennel-ls.compiler))

(λ read-file [uri]
  (with-open [fd (io.open (utils.uri->path uri))]
    {:uri uri
     :text (fd:read :*a)}))

(λ get-by-uri [self uri]
  (or (. self.files uri)
      (let [file (read-file uri)]
        (compile self file)
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
        (get-by-uri self uri)))))

(λ set-uri-contents [self uri text]
  (match (. self.files uri)
    ;; modify existing file
    file
    (do
      (when (not= text file.text)
        (set file.text text)
        (compile self file))
      file)

    ;; create new file
    nil
    (let [file {: uri : text}]
      (tset self.files uri file)
      (compile self file)
      file)))

(local default-config
  {:fennel-path "./?.fnl;./?/init.fnl;src/?.fnl;src/?/init.fnl"
   :macro-path  "./?.fnl;./?/init-macros.fnl;./?/init.fnl;src/?.fnl;src/?/init-macros.fnl;src/?/init.fnl"
   :globals     ""})

(λ write-config [self ?config]
  (if (not ?config)
    (set self.config default-config) ;; fast path, use all defaults
    (set self.config
      {;; fennel-path:
       ;; the path to use to find fennel files using (require) or (include)
       :fennel-path (or ?config.fennelpath
                        default-config.fennel-path)
       ;; macro-path:
       ;; the path to use to find fennel files using (require-macros) or (include-macros)
       :macro-path (or ?config.macro-path
                       default-config.fennel-path)
       ;; globals:
       ;; Comma separated list of extra globals that are allowed.
       :globals (or ?config.globals
                    default-config.globals)})))

(λ init-state [self params]
  (set self.files {})
  (set self.modules {})
  (set self.root-uri params.rootUri)
  (write-config self))

{: get-by-module
 : get-by-uri
 : init-state
 : set-uri-contents
 : write-config}
