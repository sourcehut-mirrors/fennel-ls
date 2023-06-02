(import-macros {: is-matching : describe : it : before-each} :test)
(local is (require :test.is))

(local {: view} (require :fennel))
(local {: ROOT-URI
        : create-client} (require :test.mock-client))

(describe "hover"

  (fn check [request-file line char response-string]
    (let [self (create-client)
          message (self:hover (.. ROOT-URI :/ request-file) line char)]
      (is-matching
        message
        [{:jsonrpc "2.0" :id self.prev-id
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
    (check "hover.fnl" 18 6 "```fnl\n(fn lambda-fn [arg1 arg2] ...)\n```\ndocstring"))

  (it "hovers the first part of a multisym"
    (check "hover.fnl" 9 14 "```fnl\n{:field1 10 :field2 :colon-string}\n```"))

  (it "hovers over literally the very first character"
    (let [self (create-client)
          message (self:hover (.. ROOT-URI "/hover.fnl") 0 0)]
      (is-matching message [{:jsonrpc "2.0" :id 2}] "")))

  (it "can go backward through (case)"
    (check "hover.fnl" 22 22 "```fnl\n{:AB :CD}\n```")))
