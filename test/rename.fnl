(local faith (require :faith))
(local {: create-client} (require :test.utils))
(local {: null} (require :dkjson))
(local {: apply-edits} (require :fennel-ls.utils))

(fn check [file-content new-name expected-file-content]
  (let [{: client : uri : cursor : text : encoding} (create-client file-content)
        [{: result}] (client:rename uri cursor new-name)]
    (if (= null result)
      (faith.= expected-file-content text)
      (let [new-content (apply-edits text (. result.changes uri) encoding)]
        (faith.= expected-file-content new-content)))))

(fn test-prepare-rename []
  ;; Test that prepareRename returns a range for valid rename locations
  (let [{: client : uri : cursor} (create-client "(let [old-name| 100] old-name)")
        [{: result}] (client:prepare-rename uri cursor)]
    (faith.is result "prepareRename should return a result for local binding")
    (faith.is result.range "result should have a range field"))

  ;; Test prepareRename on the reference
  (let [{: client : uri : cursor} (create-client "(let [old-name 100] old-|name)")
        [{: result}] (client:prepare-rename uri cursor)]
    (faith.is result "prepareRename should return a result for reference")
    (faith.is result.range "result should have a range field"))

  ;; Test prepareRename on function parameters
  (let [{: client : uri : cursor} (create-client "(λ [foo|] (print foo))")
        [{: result}] (client:prepare-rename uri cursor)]
    (faith.is result "prepareRename should return a result for function parameter")
    (faith.is result.range "result should have a range field"))

  ;; Test prepareRename on var binding
  (let [{: client : uri : cursor} (create-client "(var x| 10)")
        [{: result}] (client:prepare-rename uri cursor)]
    (faith.is result "prepareRename should return a result for var binding")
    (faith.is result.range "result should have a range field"))

  ;; Test that prepareRename returns null for invalid locations
  (let [{: client : uri : cursor} (create-client "(let [old-name 10|0] old-name)")
        [{: result}] (client:prepare-rename uri cursor)]
    (faith.= null result "prepareRename should return null for number literal"))

  ;; Test prepareRename returns null for string literal
  (let [{: client : uri : cursor} (create-client "(print \"hel|lo\")")
        [{: result}] (client:prepare-rename uri cursor)]
    (faith.= null result "prepareRename should return null for string literal"))

  ;; Test prepareRename returns null for special forms
  (let [{: client : uri : cursor} (create-client "(le|t [x 10] x)")
        [{: result}] (client:prepare-rename uri cursor)]
    (faith.= null result "prepareRename should return null for special form")))

(fn test-rename []
  (check "(let [old-name| 100] old-name)" :new-name
         "(let [new-name 100] new-name)")
  (check "(let [old-name| 100] (print old-name) (print old-name))" :new-name!!
         "(let [new-name!! 100] (print new-name!!) (print new-name!!))")

  (check "(let [old|-name {:field 10}] old-name.field)" :new
         "(let [new {:field 10}] new.field)")
  (check "(let [old-name {:field 10}] old-|name.field)" :new
         "(let [new {:field 10}] new.field)")
  (check "(let [[|old-name] [{:field 10}]] (old-name:field 10))" :new
         "(let [[new] [{:field 10}]] (new:field 10))")
  (check "(let [[|old-name] [{:field 10}]] (case 1 (where 1 (old-name:field 10)) 1)" :new
         "(let [[new] [{:field 10}]] (case 1 (where 1 (new:field 10)) 1)")

  (check "(fn [{: x|}] x)" :foo
         "(fn [{: foo}] foo)")
  (check "(fn [{:x x|}] x)" :foo
         "(fn [{:x foo}] foo)")

  ;; issue fennel-ls#8
  (check "(λ [foo|] (print foo))" :something
         "(λ [something] (print something))")

  (check "(var x 10)
          (set x| 20)" :something
         "(var something 10)
          (set something 20)")

  (check "(var x 10)
          (var m 0)
          (set (m |x) (values 10 20))" :something
         "(var something 10)
          (var m 0)
          (set (m something) (values 10 20))")

  (check "(var (x y) 10)
          (set (x |y) 10)" :something
         "(var (x something) 10)
          (set (x something) 10)")

  (check "(var x 10)
          (doto |x (set 20) (set 30))" :something
         "(var something 10)
          (doto something (set 20) (set 30))"))

{: test-prepare-rename
 : test-rename}
