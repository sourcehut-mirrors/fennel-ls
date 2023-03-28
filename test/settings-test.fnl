(import-macros {: is-matching : describe : it : before-each} :test)
(local is (require :test.is))

(local {: view} (require :fennel))
(local {: ROOT-URI
        : create-client} (require :test.mock-client))

(local dispatch (require :fennel-ls.dispatch))
(local message (require :fennel-ls.message))

(describe "settings"
  (it "can set the path"
    (let [client (doto (create-client {:fennel-ls {:fennel-path "./?/?.fnl"}})
                   (: :open-file! (.. ROOT-URI :/test.fnl) "(local {: this-is-in-modname} (require :modname))"))
          [{:result {:range message}}]
          (client:definition (.. ROOT-URI :/test.fnl) 0 12)]
      (is.not.nil message)
      "body")))

  ;; (it "can set the path"
  ;;   (local self (doto [] (setup-server {:fennel-ls {:macro-path "./?/?.fnl"}}))))

  ;; (it "can infer the macro path from fennel-path"
  ;;   (local self (doto [] (setup-server {:fennel-ls {:fennel-path "./?/?.fnl"}}))))

  ;; (it "can accept an allowed global"
  ;;   (local self (doto [] (setup-server {:fennel-ls {:globals "vim"}}))))

  ;; (it "can accept a list of allowed globals"
  ;;   (local self (doto [] (setup-server {:fennel-ls {:globals "GAMESTATE,SCREEN_CENTER_X,ETC"}}))))

  ;; (it "can accept a way to allow all globals that match a pattern"
  ;;   (local self (doto [] (setup-server {:fennel-ls {:global-pattern "[A-Z]+"}}))))

  ;; (it "can turn off strict globals"
  ;;   (local self (doto [] (setup-server {:fennel-ls {:globals "*"}}))))

  ;; (it "can treat globals as a warning instead of an error"
  ;;   (local self (doto [] (setup-server {:fennel-ls {:diagnostics {:E202 "warning"}}})))))
