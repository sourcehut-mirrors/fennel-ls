(local faith (require :faith))
(local {: create-client} (require :test.utils))

(fn test-path []
  (let [{: client : uri : cursor :locations [location]}
        (create-client
          {:modname.fnl "{:this-is-in-modname {:this :one :isnt :on :the :path}}"
           :modname/modname/modname/modname.fnl "(fn ==this-is-in-modname== [] nil) {: this-is-in-modname}"
           :main.fnl "(local {: this-is-in-mod|name} (require :modname))"}
          {:settings {:fennel-ls {:fennel-path "./?/?/?/?.fnl"}}})

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
  (let [{:diagnostics good} (create-client "(foo-100 bar :baz)" {:settings {:fennel-ls {:extra-globals "foo-100 bar"}}})
        {:diagnostics bad} (create-client "(foo-100 bar :baz)")]
    (faith.= [] good)
    (faith.not= [] bad))
  nil)

  ;; (it "can turn off strict globals"
  ;;   (local client (doto [] (setup-server {:fennel-ls {:checks {:globals false}}}))))

  ;; (it "can treat globals as a warning instead of an error"
  ;;   (local client (doto [] (setup-server {:fennel-ls {:diagnostics {:E202 "warning"}}})))))

(fn test-lints []
  (let [{:diagnostics good} (create-client "(local x 10)" {:settings {:fennel-ls {:checks {:unused-definition false}}}})
        {:diagnostics bad} (create-client "(local x 10)")]
    (faith.= [] good)
    (faith.not= [] bad))
  nil)

(fn test-initialization-options []
  (let [initialization-options {:fennel-ls {:checks {:unused-definition false}}}
        {: diagnostics} (create-client "(local x 10)" {: initialization-options})]
    (faith.= [] diagnostics))
  nil)

(fn test-native-libaries []
  (let [{:diagnostics bad} (create-client "(print btn)"
                             {:settings {}})
        {:diagnostics good} (create-client "(print btn)"
                              {:settings {:fennel-ls {:native-libraries [:tic80]}}})]
    (faith.not= [] bad)
    (faith.= [] good)))

{: test-path
 : test-extra-globals
 : test-lints
 : test-initialization-options
 : test-native-libaries}
