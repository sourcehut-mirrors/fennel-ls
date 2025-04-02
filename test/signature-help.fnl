(local faith (require :faith))
(local {: view} (require :fennel))
(local {: create-client} (require :test.utils))

(λ check-signature [expected response]
  (case response
    {:signatures [{:label signature}]}
    (do
      (faith.= expected.signature signature)
      (faith.= expected.activeParameter response.activeParameter))
    ;; fail
    _ (faith.is nil (.. "Invalid response: " (view response)))))

(fn check [file-contents expected]
  (let [{: client : uri : cursor} (create-client file-contents)
        [{: result}] (client:signature-help uri cursor)]
    (check-signature expected result)))

(fn test-fn-definition []
  (check "(fn |)"
         {:signature "(fn name? args docstring? ...)"
          :activeParameter 0})

  (check "(fn some-nam|)"
         {:signature "(fn name? args docstring? ...)"
          :activeParameter 0})

  (check "(fn some-name [|]"
         {:signature "(fn name? args docstring? ...)"
          :activeParameter 1})

  (check "(fn some-name [arg|])"
         {:signature "(fn name? args docstring? ...)"
          :activeParameter 1})

  (check "(fn some-name [arg1 arg2]
            \"docstring|\")"
         {:signature "(fn name? args docstring? ...)"
          :activeParameter 2})

  (check "(fn some-name [arg1 arg2]
            \"docstring\"
            |"
         {:signature "(fn name? args docstring? ...)"
          :activeParameter 2}))

(fn test-local-function []
  (check "(fn func [arg1 arg2] (print :hello))
          (func|)"
         {:signature "(func arg1 arg2)"
          :activeParameter nil})

  (check "(fn func [arg1 arg2] (print :hello))
          (func |)"
         {:signature "(func arg1 arg2)"
          :activeParameter 0})

  (check "(fn func [arg1 arg2] (print :hello))
          (func a1|)"
         {:signature "(func arg1 arg2)"
          :activeParameter 0})

  (check "(fn func [arg1 arg2] (print :hello))
          (func a|1 a2)"
         {:signature "(func arg1 arg2)"
          :activeParameter 0})

  (check "(fn func [arg1 arg2] (print :hello))
          (func a1 a2|)"
         {:signature "(func arg1 arg2)"
          :activeParameter 1})

  (check "(fn func [arg1 arg2] (print :hello))
          (func a1 a|2)"
         {:signature "(func arg1 arg2)"
          :activeParameter 1}))

(fn test-literals []
  (check "(fn func [arg1 arg2] (print :hello))
          (func arg 10|2)"
         {:signature "(func arg1 arg2)"
          :activeParameter 1})

  (check "(fn func [arg1 arg2] (print :hello))
          (func arg \"10|2\")"
         {:signature "(func arg1 arg2)"
          :activeParameter 1}))

(fn test-vararg []
  (check "(or a b|)"
         {:signature "(or a b ...)"
          :activeParameter 1})

  (check "(or a b c|)"
         {:signature "(or a b ...)"
          :activeParameter 2})

  (check "(or a b c d e|)"
         {:signature "(or a b ...)"
          :activeParameter 2}))

(fn test-lua-builtin []
  (check "(error msg lvl|)"
         {:signature "(error message ?level)"
          :activeParameter 1})

  (check "(error msg lvl extr|)"
         {:signature "(error message ?level)"
          :activeParameter 2}))

(fn test-multisym []
  (check "(table.concat tbl s|)"
         {:signature "(table.concat list ?sep ?i ?j)"
          :activeParameter 1}))

(fn test-destructuring-arg []
  (check "(fn dstr [{:field name} arg2] {})
          (dstr |)"
         {:signature "(dstr {:field name} arg2)"
          :activeParameter 0})

  (check "(fn dstr [{:field name} arg2] {})
          (dstr arg1 ar|)"
         {:signature "(dstr {:field name} arg2)"
          :activeParameter 1})

  (check "(fn dstr [{:field |} arg2] {})"
         {:signature "(fn name? args docstring? ...)"
          :activeParameter 1}))

(fn test-binding-form []
  (check "(each |)"
         {:signature "(each [key value (iterator)] ...)"
          :activeParameter 0})

  (check "(each [|])"
         {:signature "(each [key value (iterator)] ...)"
          :activeParameter 0})

  (check "(each [k val|])"
         {:signature "(each [key value (iterator)] ...)"
          :activeParameter 0})

  (check "(let [a 0]
            (error |))"
         {:signature "(error message ?level)"
          :activeParameter 0})

  (check "(let [a|] (error))"
         {:signature "(let [name1 val1 ... nameN valN] ...)"
          :activeParameter 0}))

(fn test-indirect-definition []
  (check "(let [a error]
            (a |))"
         {:signature "(error message ?level)"
          :activeParameter 0}))

(fn test-destructuring-binding []
  (check "(let [(a b|) {}]"
         {:signature "(let [name1 val1 ... nameN valN] ...)"
          :activeParameter 0})

  (check "(let [(a {:b |}) {}]"
         {:signature "(let [name1 val1 ... nameN valN] ...)"
          :activeParameter 0})

  (check "(let [{:field |} {}]"
         {:signature "(let [name1 val1 ... nameN valN] ...)"
          :activeParameter 0})

  (check "(let [{:field {: nested |"
         {:signature "(let [name1 val1 ... nameN valN] ...)"
          :activeParameter 0})

  (check "(let [{:field {: nested &as |}} {}]"
         {:signature "(let [name1 val1 ... nameN valN] ...)"
          :activeParameter 0}))

{: test-fn-definition
 : test-local-function
 : test-literals
 : test-vararg
 : test-lua-builtin
 : test-multisym
 : test-destructuring-arg
 : test-binding-form
 : test-indirect-definition
 : test-destructuring-binding}
