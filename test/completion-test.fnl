(import-macros {: is-matching : describe : it : before-each} :test)
(local is (require :luassert))

(local {: view} (require :fennel))
(local {: ROOT-URI
        : setup-server} (require :test.util))

(local dispatch (require :fennel-ls.dispatch))
(local message (require :fennel-ls.message))

(local FILENAME (.. ROOT-URI "imaginary-file.fnl"))

(fn open-file [state text]
  (dispatch.handle* state
    (message.create-notification "textDocument/didOpen"
      {:textDocument
       {:uri FILENAME
        :languageId "fennel"
        :version 1
        : text}})))

(describe "completions")
  ;; (it "suggests globals"
  ;;   (local state (doto [] setup-server))
  ;;   ;; empty file
  ;;   (open-file state "")
  ;;   (let [response (dispatch.handle* state
  ;;                    (message.create-request 2 "textDocument/completion"
  ;;                      {:position {:line 0 :character 0}
  ;;                       :textDocument {:uri FILENAME}}))]
  ;;     (is-matching response nil "oops"))))

  ;; (it "suggests locals in scope")
  ;; (it "does not suggest locals out of scope")
  ;; (it "suggests fields of tables")
  ;; (it "knows what fields are meant to be inside of globals")
