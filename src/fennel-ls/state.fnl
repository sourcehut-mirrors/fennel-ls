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
  (let [text (case (. server.preload uri)
               preload preload
               _ (let [file (io.open (utils.uri->path uri))]
                    (if file
                      (let [body (file:read :*a)]
                        (file:close)
                        body)
                      (error (.. "failed to open file" uri)))))]
    {: uri : text}))

(λ get-by-uri [server uri]
  (or (. server.files uri)
      (let [file (read-file server uri)]
        (compile server file)
        (tset server.files uri file)
        file)))

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
            :op-with-no-arguments (option true)
            :multival-in-middle-of-call (option true)}
   :native-libraries (option [])
   :extra-globals (option "")})

(λ make-configuration [?c]
  (make-configuration-from-template default-configuration ?c))

(λ choose-position-encoding [init-params]
  "fennel-ls natively uses utf-8, so the goal is to choose positionEncoding=\"utf-8\".
However, when not an option, fennel-ls will fall back to positionEncoding=\"utf-16\" (with a performance hit)."
  (let [?position-encodings (?. init-params :capabilities :general :positionEncodings)
        utf8?
        (if (= (type ?position-encodings) :table)
          (accumulate [utf-8? false
                       _ encoding (ipairs ?position-encodings)
                       &until utf-8?]
            (or (= encoding :utf-8)
                (= encoding :utf8)))
          false)]
    (if utf8?
     :utf-8
     :utf-16)))

(λ init-state [server params]
  (set server.files {})
  (set server.preload {})
  (set server.modules {})
  (set server.root-uri params.rootUri)
  (set server.position-encoding (choose-position-encoding params))
  (set server.configuration (make-configuration (?. params :initializationOptions :fennel-ls)))
  ;; Eglot does completions differently than every other client I've seen so far, in that it considers foo.bar to be one "symbol".
  ;; If the user types `foo.b`, every other client accepts `bar` as a completion, bun eglot wants the full `foo.bar` multisym.
  (set server.EGLOT_COMPLETION_QUIRK_MODE (= (?. params :clientInfo :name) :Eglot)))

(λ write-configuration [server ?configuration]
  "This is where we can put anything that needs to react to config changes"
  (set server.configuration (make-configuration ?configuration)))

{: flush-uri
 : get-by-module
 : get-by-uri
 : init-state
 : set-uri-contents
 : write-configuration}
