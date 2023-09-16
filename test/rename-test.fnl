(import-macros {: is-matching : is-casing : describe : it : before-each} :test)
(local utils (require :fennel-ls.utils))
(local is (require :test.is))

(local {: view} (require :fennel))
(local {: ROOT-URI
        : create-client} (require :test.client))

(local filename (.. ROOT-URI "/imaginary-file.fnl"))

(fn check-rename [body line col new-name new-body]
  (let [client (doto (create-client)
                 (: :open-file! filename body))
        [{: result}] (client:rename filename line col new-name)
        changes (. result.changes filename)
        body (. client.server.files filename :text)]
    (is.equal
      (utils.apply-edits body changes client.server.position-encoding)
      new-body)))

(describe "rename"
  (it "renames a variable"
    (check-rename "(let [old-name 100] old-name)" 0 9 :new-name
                  "(let [new-name 100] new-name)"))

  (it "renames a variable 2"
    (check-rename "(let [old-name 100] (print old-name) (print old-name))" 0 9 :new-name!!
                  "(let [new-name!! 100] (print new-name!!) (print new-name!!))"))

  (it "renames a multisym"
    (check-rename "(let [old-name {:field 10}] old-name.field)" 0 9 :new-name
                  "(let [new-name {:field 10}] new-name.field)")
    (check-rename "(let [old-name {:field 10}] old-name.field)" 0 30 :new-name
                  "(let [new-name {:field 10}] new-name.field)"))

  (it "renames from destructure/args"
    (check-rename "(fn [{: x}] x)" 0 8 :foo "(fn [{: foo}] foo)")
    (check-rename "(fn [{:x x}] x)" 0 9 :foo "(fn [{:x foo}] foo)"))

 (it "renames a sym inside of lambda"
   (check-rename "(λ [foo] (print foo))" 0 6 :something
                 "(λ [something] (print something))")))
