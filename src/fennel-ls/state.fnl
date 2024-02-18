"State
This module keeps track of the state of the language server.
There are helpers to get files (get-by functions are all for
getting files), and there's stuff for configuration options.
There is no global state in this project: all state is stored
in the \"self\" object. Pretty much every \"self\" in the
entire fennel-ls project is referring to the same object."

(local searcher (require :fennel-ls.searcher))
(local utils (require :fennel-ls.utils))
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

(λ _get-by-path [self path]
  (get-by-uri self (utils.path->uri path)))

(λ get-by-module [self module]
  ;; check the cache
  (case (. self.modules module)
    uri
    (or (get-by-uri self uri)
      ;; if the cached uri isn't found, clear the cache and try again
      (do (tset self.modules module nil)
          (get-by-module self module)))
    nil
    (case (searcher.lookup self module)
      uri
      (do
        (tset self.modules module uri)
        (get-by-uri self uri)))))

(λ set-uri-contents [self uri text]
  (case (. self.files uri)
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

(λ flush-uri [self uri]
  "get rid of data about a file, in case it changed in some way"
  (tset self.files uri nil))

;; TODO: set the warning levels of lints
;; allow all globals
;; pick from existing libraries of globals (ie love2d)
;; pick between different versions of lua (ie luajit)
;; pick a "compat always" mode that accepts anything if it could be valid in any lua
;; make a "compat strict" mode that warns about any lua-version-specific patterns
;; ie using (unpack) without saying (or table.unpack _G.unpack) or something like that

(local option-mt {})
(fn option [default-value]
  "represents an \"option\" that the user can override"
  (doto [default-value] (setmetatable option-mt)))

(fn make-configuration-from-template [default ?user ?parent]
  (if (= option-mt (getmetatable default))
      (let [setting
             (case-try ?user
               nil (?. ?parent :all)
               nil (. default 1))]
        (assert (= (type (. default 1)) (type setting)))
        setting)
      (= :table (type default))
      (collect [k _ (pairs default)]
          k (make-configuration-from-template
              (. default k)
              (?. ?user k)
              ?user))
      (error "This is a bug with fennel-ls: default-configuration has a key that isn't a table or option")))

(local default-configuration
  {:fennel-path (option "./?.fnl;./?/init.fnl;src/?.fnl;src/?/init.fnl")
   :macro-path (option "./?.fnl;./?/init-macros.fnl;./?/init.fnl;src/?.fnl;src/?/init-macros.fnl;src/?/init.fnl")
   :version (option "lua54")
   :checks {:unused-definition (option true)
            :unknown-module-field (option true)
            :unnecessary-method (option true)
            :bad-unpack (option true)
            :var-never-set (option true)
            :op-with-no-arguments (option true)}
   :extra-globals (option "")})

(λ make-configuration [?c]
  (make-configuration-from-template default-configuration ?c))

(λ choose-position-encoding [init-params]
  "fennel-ls natively uses utf-8, so ideally we will choose positionEncoding=utf-8.
However, fennel-ls can fall back to positionEncoding=utf-16 (with a performance hit)."
  (let [?position-encodings (?. init-params :capabilities :general :positionEncodings)
        utf8?
        (if (= (type ?position-encodings) :table)
          (accumulate [_utf-8? false
                       _ encoding (ipairs ?position-encodings)]
            (or (= encoding :utf-8)
                (= encoding :utf8)))
          false)]
    (if utf8?
     :utf-8
     :utf-16)))

(λ init-state [self params]
  (set self.files {})
  (set self.modules {})
  (set self.root-uri params.rootUri)
  (set self.position-encoding (choose-position-encoding params))
  (set self.configuration (make-configuration (?. params :initializationOptions :fennel-ls))))

(λ write-configuration [self ?configuration]
  (set self.configuration (make-configuration ?configuration)))

{: flush-uri
 : get-by-module
 : get-by-uri
 : init-state
 : set-uri-contents
 : write-configuration}
