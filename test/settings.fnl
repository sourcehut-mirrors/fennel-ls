(local faith (require :faith))
(local {: create-client} (require :test.utils))
(local fennel (require :fennel))

(fn test-path []
  (let [{: client : uri : cursor :locations [location]}
        (create-client
          {:modname.fnl "{:this-is-in-modname {:this :one :isnt :on :the :path}}"
           :modname/modname/modname/modname.fnl "(fn ==this-is-in-modname== [] nil) {: this-is-in-modname}"
           :main.fnl "(local {: this-is-in-mod|name} (require :modname))"
           :flsproject.fnl "{:fennel-path \"./?/?/?/?.fnl\"}"})
        [response] (client:definition uri cursor)]
    (faith.= location response.result
      "error message")))

  ;; TODO fix macros to use a custom searcher
  ; (let [{: diagnostics}
  ;       (create-client
  ;         {:modname.fnl "{:this-is-in-modname {:this :one :isnt :on :the :path}}"
  ;          :modname/modname/modname/modname.fnl "(fn this-is-in-modname [] nil) {: this-is-in-modname}"
  ;          :main.fnl "(import-macros {: this-is-in-modname} :modname)
  ;                     (this-is-in-modname)"}
  ;         {:settings {:fennel-ls {:macro-path "./?/?/?/?.fnl"}}})]
  ;   (faith.= [] diagnostics) "if the import-macros fails it generates a diagnostic (for now at least)")
  ; nil)

  ;; (it "recompiles modules if the macro files are modified)"

  ;; (it "can infer the macro path from fennel-path"
  ;;   (local client (doto [] ({:settings {:fennel-ls {:fennel-path "./?/?/?/?.fnl"}}))))

(fn test-extra-globals []
  (let [{:diagnostics good} (create-client {:main.fnl "(foo-100 bar :baz)"
                                            :flsproject.fnl "{:extra-globals \"foo-100 bar\"}"})
        {:diagnostics bad} (create-client {:main.fnl "(foo-100 bar :baz)"
                                           :flsproject.fnl "{}"})]
    (faith.= [] good)
    (faith.not= [] bad))
  nil)

  ;; (it "can turn off strict globals"
  ;;   (local client (doto [] (setup-server {:fennel-ls {:lints {:globals false}}}))))

  ;; (it "can treat globals as a warning instead of an error"
  ;;   (local client (doto [] (setup-server {:fennel-ls {:diagnostics {:E202 "warning"}}})))))

(fn test-lints []
  (let [{:diagnostics good} (create-client {:main.fnl "(local x 10)"
                                            :flsproject.fnl "{:lints {:unused-definition false}}"})
        {:diagnostics bad} (create-client {:main.fnl "(local x 10)"
                                           :flsproject.fnl "{}"})]
    (faith.= [] good)
    (faith.not= [] bad))
  nil)

(fn test-native-libaries []
  (let [{:diagnostics bad} (create-client {:main.fnl "(print btn)"
                                           :flsproject.fnl "{}"})
        {:diagnostics good} (create-client {:main.fnl "(print btn)"
                                            :flsproject.fnl "{:libraries {:tic-80 true}}"})]
    (faith.not= [] bad)
    (faith.= [] good)))

(fn test-editing-settings []
  (let [{: client : uri} (create-client {:main.fnl ""
                                         :flsproject.fnl "{}"})
        uri (uri:gsub "main" "flsproject")]
    (client:pretend-this-file-exists! uri "{:extra-globals \"my-new-global\"}")
    (client:did-save uri)
    (faith.= "my-new-global" client.server.configuration.extra-globals)
    (local _ nil))
  nil)

{: test-path
 : test-extra-globals
 : test-lints
 : test-native-libaries
 : test-editing-settings}
