"Config
This module is in charge of setting up the default settings.

Settings are stored in `server.configuration`.
config.reload should be the only function that ever writes
to server.configuration. Every other use case should be read-only."

;; TODO: Settings to set the warning levels of lints
;; Setting to allow all globals

(local files (require :fennel-ls.files))
(local docs (require :fennel-ls.docs))
(local utils (require :fennel-ls.utils))
(local lint (require :fennel-ls.lint))
(local message (require :fennel-ls.message))
(local {: view} (require :fennel))

(local option-mt {})
(fn option [default-value ?validate]
  "A flsproject.fnl configuration option. The user can provide any value that matches the type of default-value"
  (setmetatable {: default-value :validate ?validate} option-mt))

;; this default configuration gets merged with the user-provided ones
;; the (option) values can be overridden by the user, instead of doing the merge logic
(local default-configuration
  {:fennel-path (option "./?.fnl;./?/init.fnl;src/?.fnl;src/?/init.fnl")
   :macro-path (option (table.concat ["./?.fnlm" "./?/init.fnlm"
                                      "./?.fnl" "./?/init-macros.fnl"
                                      "./?/init.fnl"
                                      "src/?.fnlm" "src/?/init.fnlm"
                                      "src/?.fnl" "src/?/init-macros.fnl"
                                      "src/?/init.fnl"] ";"))
   :lua-version (option "lua54" docs.validate-lua-version)
   :lints (collect [_ lint (ipairs lint.list)]
            lint.name (option (not lint.disabled)))
   :libraries (option {} docs.validate-libraries)
   :extra-globals (option "")})

(fn extend-path [?root extra]
  (if (not= (type extra) :string) ?root
      ?root (.. ?root "." extra)
      extra))

(fn make-configuration-from-template [template ?user ?parent ?path invalid]
  (if (= (getmetatable template) option-mt)
      (let [setting (case-try ?user
                      nil (?. ?parent :all)
                      nil template.default-value)]
        (if (not= (type setting) (type template.default-value))
            (do (invalid (.. (or ?path "flsproject.fnl") " must be a " (type template.default-value)) ?user ?parent)
                template.default-value)
            template.validate
            (case-try (template.validate setting #(invalid $ ?user ?parent))
                      nil template.default-value)
            setting))
      (= :table (type template))
      (case (type ?user)
        (where (or :table :nil))
        (do
          (when (= (type ?user) :table)
            (each [k (pairs ?user)]
              (when (not (. template k))
                (invalid (.. "didn't expect " (or (extend-path ?path k) "flsproject.fnl") "\n"
                             "valid keys: " (view (doto (icollect [k (pairs template)] k)
                                                        table.sort)))
                         (. ?user k)
                         ?user))))
          (collect [k (pairs template)]
              k (make-configuration-from-template
                  (. template k)
                  (?. ?user k)
                  ?user
                  (extend-path ?path k)
                  invalid)))
        _ (do (invalid (.. "expected " (or ?path "flsproject.fnl") " to be a table") ?user ?parent)
              (make-configuration-from-template template nil ?parent ?path invalid)))
      (error (.. "This is a bug with fennel-ls: default-configuration has a key that isn't a table or option: " ?path))))

(λ make-configuration [?c invalid]
  (make-configuration-from-template default-configuration ?c nil nil invalid))

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

(λ parse-flsconfig [{: text : uri}]
  (local fennel (require :fennel))
  (local [ok? _err result] [(pcall (fennel.parser text uri))])
  (if ok? result))

(λ load-config [server invalid]
  "This is where we can put anything that needs to react to config changes"
  (make-configuration
    (-?> server.root-uri
         utils.uri->path
         (utils.path-join "flsproject.fnl")
         utils.path->uri
         (->> (files.read-file server))
         parse-flsconfig)
    invalid))

(λ reload [server]
  (set server.configuration
    (load-config server
      ;; according to the spec it is valid to send showMessage during initialization
      ;; but eglot will only flash the message briefly before replacing it with
      ;; another message, and probably other clients will do similarly. so queue
      ;; up the warnings to send *after* the initialization is complete. cheesy, eh?
      #(table.insert server.queue (message.show-message $1 :WARN)))))

(λ initialize [server params]
  (set server.queue [])
  (set server.files {})
  (set server.modules {})
  (set server.macro-modules {})
  (set server.root-uri params.rootUri)
  (set server.position-encoding (choose-position-encoding params))
  (set server.can-do-good-completions?
       ;; if client supports CompletionClientCapabilites.completionList.itemDefaults.editRange
       ;;                and CompletionClientCapabilites.completionList.itemDefaults.data
       (case (?. params :capabilities :textDocument :completion :completionList :itemDefaults)
          completion-item-defaults  (and (accumulate [found nil _ v (ipairs completion-item-defaults) &until found] (= v :editRange))
                                         (accumulate [found nil _ v (ipairs completion-item-defaults) &until found] (= v :data)))))
  (reload server))

{: initialize
 : reload
 : make-configuration}
