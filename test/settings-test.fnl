(import-macros {: is-matching : describe : it : before-each} :test)
(local is (require :test.is))

(local {: view} (require :fennel))
(local {: ROOT-URI
        : open-file
        : setup-server} (require :test.utils))

(local dispatch (require :fennel-ls.dispatch))
(local message (require :fennel-ls.message))

(describe "settings"
  (it "can set the path"
    (local self (doto [] (setup-server {:fennel-ls {:fennel-path "./?/?.fnl"}})))
    (open-file self (.. ROOT-URI :/test.fnl) "(local {: this-is-in-modname} (require :modname))")
    (let [[{:result {:range message}}]
          (dispatch.handle* self
            (message.create-request 2 :textDocument/definition
              {:position {:character 12 :line 0}
               :textDocument {:uri (.. ROOT-URI :/test.fnl)}}))]
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
