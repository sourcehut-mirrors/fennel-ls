(import-macros {: is-matching : describe : it : before-each} :test)
(local is (require :luassert))

(local {: view} (require :fennel))
(local {: ROOT-URI
        : setup-server} (require :test.util))

(local dispatch (require :fennel-ls.dispatch))
(local message (require :fennel-ls.message))

(describe "diagnostic messages"
  (it "handles compile errors"
    (local state (doto [] setup-server))
    (let
      [responses
       (dispatch.handle* state
         (message.create-notification "textDocument/didOpen"
           {:textDocument
            {:uri (.. ROOT-URI "imaginary-file.fnl")
             :languageId "fennel"
             :version 1
             :text "(do do)"}}))]
      (is-matching
        responses
        [{:params {:diagnostics [diagnostic]}}]
        "")))

  (it "handles parse errors"
    (local state (doto [] setup-server))
    (let
      [responses
       (dispatch.handle* state
         (message.create-notification "textDocument/didOpen"
           {:textDocument
            {:uri (.. ROOT-URI "imaginary-file.fnl")
             :languageId "fennel"
             :version 1
             :text "(do (print :hello(]"}}))]
      (is-matching
        responses
        [{:params {:diagnostics [diagnostic]}}]
        ""))))
