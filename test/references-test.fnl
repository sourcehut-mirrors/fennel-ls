(import-macros {: is-matching : describe : it : before-each} :test)
(local is (require :test.is))

(local {: view} (require :fennel))
(local {: ROOT-URI
        : create-client} (require :test.mock-client))

(local filename (.. ROOT-URI "/imaginary-file.fnl"))

(fn check-references [body line col expected]
  (let [client (doto (create-client)
                 (: :open-file! filename body))
        response (client:references filename line col)]
    (is.same response [])))

(describe "references")
  ; (it "finds a reference from let"
  ;   (check-references "(let [x 10] x)" 0 1))) 
