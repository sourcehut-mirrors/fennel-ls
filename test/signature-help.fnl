(local faith (require :faith))
(local {: view} (require :fennel))
(local {: create-client} (require :test.utils))

(λ check-signature [expected response]
  (case response
    {:signatures [{:label signature}]}
    (faith.= expected.signature signature)
    ;; fail
    _ (faith.is nil (.. "Invalid response: " (view response)))))

(fn check [file-contents expected]
  (let [{: client : uri : cursor} (create-client file-contents)
        [{: result}] (client:signature-help uri cursor)]
    (check-signature expected result)))

(fn test-fn-definition []
  (check "(fn func [arg1 arg2] (print :hello))
          (func|)"
         {:signature "(func arg1 arg2)"})

  (check "(fn func [arg1 arg2] (print :hello))
          (func |)"
         {:signature "(func arg1 arg2)"})

  (check "(fn func [arg1 arg2] (print :hello))
          (func a1|)"
         {:signature "(func arg1 arg2)"})

  (check "(fn func [arg1 arg2] (print :hello))
          (func a|1 a2)"
         {:signature "(func arg1 arg2)"})

  (check "(fn func [arg1 arg2] (print :hello))
          (func a1 a2|)"
         {:signature "(func arg1 arg2)"})

  (check "(fn func [arg1 arg2] (print :hello))
          (func a1 a|2)"
         {:signature "(func arg1 arg2)"}))

(fn test-lua-builtin []
  (check "(error msg lvl|)"
         {:signature "(error message ?level)"}))

(fn test-multisym []
  (check "(table.concat tbl s|)"
         {:signature "(table.concat list ?sep ?i ?j)"}))

(fn test-destructuring-arg []
  (check "(fn dstr [{:field name} arg2] {})
          (dstr |)"
         {:signature "(dstr {:field name} arg2)"})

  (check "(fn dstr [{:field name} arg2] {})
          (dstr arg1 ar|)"
         {:signature "(dstr {:field name} arg2)"}))

(fn test-special []
  (check "(each |)"
         {:signature "(each [key value (iterator)] ...)"})

  (check "(each [|])"
         {:signature "(each [key value (iterator)] ...)"})

  (check "(each [k val|])"
         {:signature "(each [key value (iterator)] ...)"})

  (check "(each [33|])"
         {:signature "(each [key value (iterator)] ...)"}))

{: test-fn-definition
 : test-lua-builtin
 : test-multisym
 : test-destructuring-arg
 : test-special}
