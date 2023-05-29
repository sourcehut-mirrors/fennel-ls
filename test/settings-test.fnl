(import-macros {: is-matching : describe : it : before-each} :test)
(local is (require :test.is))

(local {: ROOT-URI
        : create-client} (require :test.mock-client))

(describe "settings"
  (it "can set the path"
    (let [client (doto (create-client {:fennel-ls {:fennel-path "./?/?.fnl"}})
                   (: :open-file! (.. ROOT-URI :/test.fnl) "(local {: this-is-in-modname} (require :modname))"))
          result (client:definition (.. ROOT-URI :/test.fnl) 0 12)]
      (is-matching
        result
        [{:result {:range _range}}]
        "error message")))

  ;; (it "can set the path"
  ;;   (let [client (doto (create-client {:fennel-ls {:macro-path "./?/?.fnl"}})
  ;;                  (: :open-file! (.. ROOT-URI :/test.fnl) "(import-macros {: this-is-in-modname} :modname)"))]
  ;;     (is-matching
  ;;         (client:definition (.. ROOT-URI :/test.fnl) 0 12)
  ;;         [{:result {:range message}}]))))

  ;; (it "can infer the macro path from fennel-path"
  ;;   (local self (doto [] (setup-server {:fennel-ls {:fennel-path "./?/?.fnl"}}))))

  ;; (it "can accept an allowed global"
  ;;   (local self (doto [] (setup-server {:fennel-ls {:extra-globals "vim"}}))))

  ;; (it "can accept a list of allowed globals"
  ;;   (local self (doto [] (setup-server {:fennel-ls {:extra-globals "GAMESTATE,SCREEN_CENTER_X,ETC"}}))))

  ;; (it "can turn off strict globals"
  ;;   (local self (doto [] (setup-server {:fennel-ls {:checks {:globals false}}}))))

  ;; (it "can treat globals as a warning instead of an error"
  ;;   (local self (doto [] (setup-server {:fennel-ls {:diagnostics {:E202 "warning"}}})))))

  ;; I suspect this test will fail when I put warnings for module return type
  (it "can disable some lints"
    (let [client (create-client {:fennel-ls {:checks {:unused-definition false}}})
          responses (client:open-file! (.. ROOT-URI :/test.fnl) "(local x 10)")]
      (is-matching responses
        [{:method :textDocument/publishDiagnostics
          :params {:diagnostics [nil]}}]
        "bad"))))
