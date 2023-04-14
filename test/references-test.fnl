(import-macros {: is-matching : describe : it : before-each} :test)
(local is (require :test.is))
(local message (require :fennel-ls.message))

(local {: view} (require :fennel))
(local {: ROOT-URI
        : create-client} (require :test.mock-client))

(local filename (.. ROOT-URI "/imaginary-file.fnl"))

(fn check-references [body line col expected]
  (let [client (doto (create-client)
                 (: :open-file! filename body))
        response (client:references filename line col)]
    (is-matching response
      (where [{:jsonrpc "2.0" :id client.prev-id
               : result}]
        (is.same result expected)))))

(describe "references"
  (it "finds a reference from let"
    (check-references "(let [x 10] x)" 0 12
      [{:uri filename :range (message.pos->range 0 12 0 13)}]))

  (it "finds a reference from let"
    (check-references "(let [x 10] x)" 0 6
      [{:uri filename :range (message.pos->range 0 12 0 13)}])))
