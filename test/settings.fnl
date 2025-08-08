(local faith (require :faith))
(local {: create-client} (require :test.utils))

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

(fn get-diagnostics [file-contents]
  (let [{: uri : client} (create-client file-contents)]
    (. (client:diagnostic uri) 1 :result :items)))

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
  (let [good (get-diagnostics {:main.fnl "(foo-100 bar :baz)"
                               :flsproject.fnl "{:extra-globals \"foo-100 bar\"}"})
        bad (get-diagnostics {:main.fnl "(foo-100 bar :baz)"
                              :flsproject.fnl "{}"})]
    (faith.= [] good)
    (faith.not= [] bad))
  nil)

  ;; (it "can turn off strict globals"
  ;;   (local client (doto [] (setup-server {:fennel-ls {:lints {:globals false}}}))))

  ;; (it "can treat globals as a warning instead of an error"
  ;;   (local client (doto [] (setup-server {:fennel-ls {:diagnostics {:E202 "warning"}}})))))

(fn test-lints []
  (let [good (get-diagnostics {:main.fnl "(local x 10)"
                               :flsproject.fnl "{:lints {:unused-definition false}}"})
        bad (get-diagnostics {:main.fnl "(local x 10)"
                              :flsproject.fnl "{}"})]
    (faith.= [] good)
    (faith.not= [] bad))
  nil)

(fn test-editing-settings []
  (let [{: client : uri} (create-client {:main.fnl ""
                                         :flsproject.fnl "{}"})
        uri (uri:gsub "main" "flsproject")]
    (client:pretend-this-file-exists! uri "{:extra-globals \"my-new-global\"}")
    (client:did-save uri)
    (faith.= "my-new-global" client.server.configuration.extra-globals)
    (local _ nil))
  nil)

(fn test-config-validation []
  (let [{: initialize-response} (create-client {:main.fnl ""
                                                :flsproject.fnl "{:lua-version \"lua5.0\"}"})
        [_init show] initialize-response]
    (faith.= "window/showMessage" show.method)
    (faith.match "doesn't know about lua version lua5.0" show.params.message))
  (let [{: initialize-response : client} (create-client {:main.fnl ""
                                                         :flsproject.fnl "{:libraries {:nasilemak true}}"})
        [_init show] initialize-response]
    ;; showMessage
    (faith.= "window/showMessage" show.method)
    (faith.match "Could not find docset for library nasilemak"
                 show.params.message)
    ;; diagnostic
    (client:open-file! (.. client.server.root-uri "/" :flsproject.fnl) "{:libraries {:nasilemak true}}")
    (let [[diagnostics] (client:diagnostic (.. client.server.root-uri "/" :flsproject.fnl))]
      (faith.match "Could not find docset for library nasilemak" (. diagnostics.result.items 1 :message))))
  nil)

(fn test-infinite-macro []
  (when (not debug.debug)
    (faith.skip))
  (let [diagnostics (get-diagnostics {:main.fnl "(macro infinite [] (while true nil))\n(infinite)\n"
                                      :flsproject.fnl "{:compiler-instruction-limit 25000}"})]
    (faith.= "instruction limit reached"
             (?. diagnostics 1 :message)))
  (let [diagnostics (get-diagnostics {:main.fnl "(macro finite [] (while false nil))\n(finite)\n"
                                      :flsproject.fnl "{:compiler-instruction-limit 25000}"})]
    (faith.= [] diagnostics))
  nil)
    

{: test-path
 : test-extra-globals
 : test-lints
 : test-config-validation
 : test-editing-settings
 : test-infinite-macro}
