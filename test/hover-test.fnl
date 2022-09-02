(import-macros {: is-matching : describe : it : before-each} :test)
(local is (require :luassert))

(local {: view} (require :fennel))
(local {: ROOT-URI
        : setup-server} (require :test.utils))

(local dispatch (require :fennel-ls.dispatch))
(local message  (require :fennel-ls.message))

(describe "hover"

  (fn check [request-file line char response-string]
    (local state (doto [] setup-server))
    (let [message (dispatch.handle* state
                     (message.create-request 2 "textDocument/hover"
                       {:position {:character char :line line}
                        :textDocument {:uri (.. ROOT-URI "/" request-file)}}))]
      (is-matching
        message
        [{:jsonrpc "2.0" :id 2
          :result
          {:contents
           {:kind "markdown"
            :value response-string}}}]
        (.. "expected response: " (view response-string)))))

  (it "hovers over a function"
    (check "hover.fnl" 6 6 "```fnl\n(fn my-function [arg1 arg2 arg3] ...)\n```"))

  (it "hovers over a literal number"
    (check "hover.fnl" 6 16 "```fnl\n300\n```"))

  (it "hovers over a literal string"
    (check "hover.fnl" 6 19 "```fnl\n\"some text\"\n```"))

  (it "hovers over a field number"
    (check "hover.fnl" 9 20 "```fnl\n10\n```"))

  (it "hovers over a field string"
    (check "hover.fnl" 9 30 "```fnl\n:colon-string\n```"))

  (it "hovers over a literal nil"
    (check "hover.fnl" 12 9 "```fnl\nnil\n```"))

  (it "hovers over λ function"
    (check "hover.fnl" 18 6 "```fnl\n(fn lambda-fn [arg1 arg2] ...)\n```\ndocstring")))
