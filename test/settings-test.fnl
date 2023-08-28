(import-macros {: is-matching : describe : it : before-each} :test)
(local is (require :test.is))
(local {: view} (require :fennel))

(local {: ROOT-URI
        : ROOT-PATH
        : create-client} (require :test.client))

(describe "settings"
  (it "can set the path"
    (let [client (doto (create-client {:settings {:fennel-ls {:fennel-path "./?/?.fnl"}}})
                   (: :open-file! (.. ROOT-URI :/test.fnl) "(local {: this-is-in-modname} (require :modname))"))
          result (client:definition (.. ROOT-URI :/test.fnl) 0 12)]
      (is-matching
        result
        [{:result {:range _range}}]
        "error message")))

  (it "can set the macro path"
    (let [client (create-client {:settings {:fennel-ls {:macro-path "./?/?.fnl"}}})
          responses (client:open-file! (.. ROOT-URI :/test.fnl) "(import-macros {: this-is-in-modname} :modname)")]
      (assert (not (. responses 1 :params :diagnostics 1)) "if the import-macros fails it generates a diagnostic (for now at least)")))

  ;; (it "recompiles modules if the macro files are modified)"

  ;; (it "can infer the macro path from fennel-path"
  ;;   (local self (doto [] (setup-server {:fennel-ls {:fennel-path "./?/?.fnl"}}))))

  (it "can set extra allowed globals"
    (let [client (create-client {:settings {:fennel-ls {:extra-globals "foo-100 bar"}}})
          responses (client:open-file! (.. ROOT-URI :/test.fnl) "(foo-100 bar :baz)")]
      (is-matching responses
        [{:method :textDocument/publishDiagnostics
          :params {:diagnostics [nil]}}]
        "bad")))

  ;; (it "can turn off strict globals"
  ;;   (local self (doto [] (setup-server {:fennel-ls {:checks {:globals false}}}))))

  ;; (it "can treat globals as a warning instead of an error"
  ;;   (local self (doto [] (setup-server {:fennel-ls {:diagnostics {:E202 "warning"}}})))))

  ;; I suspect this test will fail when I put warnings for module return type
  (it "can disable some lints"
    (let [client (create-client {:settings {:fennel-ls {:checks {:unused-definition false}}}})
          responses (client:open-file! (.. ROOT-URI :/test.fnl) "(local x 10)")]
      (is-matching responses
        [{:method :textDocument/publishDiagnostics
          :params {:diagnostics [nil]}}]
        "bad")))

  (it "can be configured with initialization options"
      (let [initializationOptions {:fennel-ls {:checks {:unused-definition false}}}
            client (create-client {:params {: initializationOptions
                                            :rootPath ROOT-PATH
                                            :rootUri ROOT-URI
                                            :workspaceFolders [{:name ROOT-PATH
                                                                :uri ROOT-URI}]}})
            responses (client:open-file! (.. ROOT-URI :/test.fnl) "(local x 10)")]
        (is-matching responses
          [{:method :textDocument/publishDiagnostics
            :params {:diagnostics [nil]}}]
          "settings should apply when set through initializationOptions"))))
