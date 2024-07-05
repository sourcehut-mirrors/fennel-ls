"Settings
This module is in charge of setting up the default settings.

Settings can be read without requiring this module: just look in `server.configuration`.
There are no global settings. They're all stored in the `server` object.
"

;; TODO: Settings to set the warning levels of lints
;; Setting to allow all globals
;; Have an option for "union of all lua versions" lua version.
;; Have an option for "intersection of all lua versions", ie disallow using (unpack) without saying (or table.unpack _G.unpack).

(local option-mt {})
(fn option [default-value] (doto [default-value] (setmetatable option-mt)))

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

(λ initialize [server params]
  (set server.files {})
  (set server.modules {})
  (set server.root-uri params.rootUri)
  (set server.position-encoding (choose-position-encoding params))
  (set server.configuration (make-configuration (?. params :initializationOptions :fennel-ls)))
  ;; Eglot does completions differently than every other client I've seen so far, in that it considers foo.bar to be one "symbol".
  ;; If the user types `foo.b`, every other client accepts `bar` as a completion, bun eglot wants the full `foo.bar` symbol.
  (set server.EGLOT_COMPLETION_QUIRK_MODE (= (?. params :clientInfo :name) :Eglot)))

(λ write-configuration [server ?configuration]
  "This is where we can put anything that needs to react to config changes"
  (set server.configuration (make-configuration ?configuration)))

{: initialize
 : write-configuration}
