(import-macros {: is-matching : describe : it : before-each} :test)
(local is (require :test.is))

(local {: view} (require :fennel))
(local {: ROOT-URI
        : create-client} (require :test.mock-client))

(local filename (.. ROOT-URI "/imaginary-file.fnl"))

(fn range [a b c d]
  {:start {:line a :character b}
   :end   {:line c :character d}})

(fn check-references [body line col ?expected]
  (let [client (doto (create-client)
                 (: :open-file! filename body))
        response (client:references filename line col)]
    (is-matching response
      (where [{:jsonrpc "2.0" :id client.prev-id
               :result ?result}]
        (is.same ?result ?expected)))))

(describe "references"
  (it "finds a reference from let"
    (check-references "(let [x 10] x)" 0 12
      [{:uri filename :range (range 0 12 0 13)}]))

  (it "finds a reference from let"
    (check-references "(let [x 10] x)" 0 6
      [{:uri filename :range (range 0 12 0 13)}]))

  (let [x 10] x x x)
  (it "finds multiple reference from let"
    (check-references "(let [x 10] x x x)" 0 6
      [{:uri filename :range (range 0 12 0 13)}
       {:uri filename :range (range 0 14 0 15)}
       {:uri filename :range (range 0 16 0 17)}]))

  (it "finds a reference from fn"
    (check-references "(fn x []) x" 0 10
      [{:uri filename :range (range 0 10 0 11)}]))

  ; (it "finds a reference from fn"
  ;   (check-references "(fn x []) x" 0 4
  ;     [{:uri filename :range (range 0 10 0 11)}]))

  (it "doesn't crash here"
    (check-references "(let [x nil] x.y)" 0 14
      nil)))

