(import-macros {: is-matching : describe : it : before-each} :test)
(local is (require :test.is))

(local {: view} (require :fennel))
(local {: ROOT-URI
        : create-client} (require :test.client))

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
    (check "hover.fnl" 22 22 "```fnl\n{:AB :CD}\n```"))

  (it "hovers over a special"
    (check "hover.fnl" 5 2 "```fnl\n(let [name1 val1 ... nameN valN] ...)\n```\nIntroduces a new scope in which a given set of local bindings are used."))

  (it "hovers over a multival destructure over (values)"
    (let [client (doto (create-client)
                       (: :open-file! :foo.fnl "(local (a b) (values 1 2))"))
          [hover-a] (client:hover :foo.fnl 0 8)
          [hover-b] (client:hover :foo.fnl 0 10)]
      (is (hover-a.result.contents.value:find "```fnl\n1\n```"))
      (is (hover-b.result.contents.value:find "```fnl\n2\n```"))
      nil))

  (it "hovers over a multival destructure over (do (values))"
    (let [client (doto (create-client)
                       (: :open-file! :foo.fnl "(local (a b) (do (values 1 2)))"))
          [hover-a] (client:hover :foo.fnl 0 8)
          [hover-b] (client:hover :foo.fnl 0 10)]
      (is (hover-a.result.contents.value:find "```fnl\n1\n```"))
      (is (hover-b.result.contents.value:find "```fnl\n2\n```"))
      nil))

  (it "hovers over a multival destructure over a mean test (do (values))"
    (let [client (doto (create-client)
                       (: :open-file! :foo.fnl "(let [(x y z a) (do (do (values 1 (do (values (values 2 4) (do 3))))))]\n  (print x y z a))"))
          [hover-x] (client:hover :foo.fnl 1 9)
          [hover-y] (client:hover :foo.fnl 1 11)
          [hover-z] (client:hover :foo.fnl 1 13)]
      (is (hover-x.result.contents.value:find "```fnl\n1\n```"))
      (is (hover-y.result.contents.value:find "```fnl\n2\n```"))
      (is (hover-z.result.contents.value:find "```fnl\n3\n```"))
      nil)))
