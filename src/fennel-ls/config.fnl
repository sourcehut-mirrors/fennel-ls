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
(local {: view &as fennel} (require :fennel))
(local {: path->uri : uri->path} (require :fennel-ls.uri))

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
   :compiler-instruction-limit (option -1)
   :extra-globals (option "")})

(fn extend-path [?root extra]
  (if (not= (type extra) :string) ?root
      ?root (.. ?root "." extra)
      extra))

(fn apply-default-configuration [default ?flsproject ?parent ?name invalid]
  (if (= (getmetatable default) option-mt)
      (let [setting (case-try ?flsproject
                      nil (?. ?parent :all)
                      nil default.default-value)]
        (if (not= (type setting) (type default.default-value))
            (do (invalid (.. (or ?name "flsproject.fnl") " must be a " (type default.default-value)) ?flsproject ?parent)
                default.default-value)
            default.validate
            (case-try (default.validate setting #(invalid $ ?flsproject ?parent))
                      nil default.default-value)
            setting))
      (= :table (type default))
      (case (type ?flsproject)
        (where (or :table :nil))
        (do
          (when (= (type ?flsproject) :table)
            (each [k (pairs ?flsproject)]
              (when (not (. default k))
                (invalid (.. "didn't expect " (or (extend-path ?name k) "flsproject.fnl") "\n"
                             "valid keys: " (view (doto (icollect [k (pairs default)] k)
                                                        table.sort)))
                         (. ?flsproject k)
                         ?flsproject))))
          (collect [k (pairs default)]
              k (apply-default-configuration
                  (. default k)
                  (?. ?flsproject k)
                  ?flsproject
                  (extend-path ?name k)
                  invalid)))
        _ (do (invalid (.. "expected " (or ?name "flsproject.fnl") " to be a table") ?flsproject ?parent)
              (apply-default-configuration default nil ?parent ?name invalid)))
      (error (.. "This is a bug with fennel-ls: default-configuration has a key that isn't a table or option: " ?name))))

(λ make-configuration [?flsproject invalid]
  (apply-default-configuration default-configuration ?flsproject nil nil invalid))

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

(fn flsproject-path [server]
  (-?> server.root-uri
       uri->path
       (utils.path-join "flsproject.fnl")
       path->uri))

(λ reload [server]
  ;; clear out macros from fennel
  (each [k (pairs fennel.macro-loaded)] (tset fennel.macro-loaded k nil))
  (set server.configuration
    (make-configuration
      (case-try (flsproject-path server)
        path (files.read-file server path)
        {: text : uri} (let [[ok? _err result] [(pcall (fennel.parser text uri))]]
                         (if ok? result))
        (catch _ nil))
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
  (set server.client-capable-of-good-completions?
       ;; if client supports CompletionClientCapabilites.completionList.itemDefaults.editRange
       ;;                and CompletionClientCapabilites.completionList.itemDefaults.data
       (case (?. params :capabilities :textDocument :completion :completionList :itemDefaults)
          completion-item-defaults  (and (accumulate [found nil _ v (ipairs completion-item-defaults) &until found] (= v :editRange))
                                         (accumulate [found nil _ v (ipairs completion-item-defaults) &until found] (= v :data)))))
  (set server.client-capable-of-insert-replace-completions? (?. params :capabilities :textDocument :completion :completionItem :insertReplaceSupport))
  (set server.client-capable-of-pull-diagnostics? (or (?. params :capabilities :textDocument :diagnostic)
                                                      (not (?. params :capabilities :textDocument :publishDiagnostics))))
  (reload server))

{: initialize
 : reload
 : make-configuration
 : flsproject-path}
