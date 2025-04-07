(local faith (require :faith))
(local {: view} (require :fennel))
(local {: create-client} (require :test.utils))

(λ check-signature [expected response]
  (case response
    {:signatures [{:label signature : parameters}]}
    (do
      (faith.= expected.signature signature)
      (faith.= expected.activeParameter response.activeParameter)
      (faith.= expected.parameters parameters))
    ;; fail
    _ (faith.is nil (.. "Invalid response: " (view response)))))

(fn check [file-contents expected]
  (let [{: client : uri : cursor} (create-client file-contents)
        [{: result}] (client:signature-help uri cursor)]
    (check-signature expected result)))

(local fn-signature "(fn name? args docstring? ...)")
(local fn-params [{:label [4 9]}
                  {:label [10 14]}
                  {:label [15 25]}
                  {:label [26 29]}])

(local err-signature "(error message ?level)")
(local err-params [{:label [7 14]}
                   {:label [15 21]}])

(local let-signature "(let [name1 val1 ... nameN valN] ...)")
(local let-params [{:label [5 32]}
                   {:label [33 36]}])

(local function-signature "(func arg1 arg2)")
(local function-params [{:label [6 10]}
                        {:label [11 15]}])

(fn test-fn-definition []
  (check "(fn |)"
         {:signature fn-signature
          :activeParameter 0
          :parameters fn-params})

  (check "(fn some-nam|)"
         {:signature fn-signature
          :activeParameter 0
          :parameters fn-params})

  (check "(fn some-name [|]"
         {:signature fn-signature
          :activeParameter 1
          :parameters fn-params})

  (check "(fn some-name [arg|])"
         {:signature fn-signature
          :activeParameter 1
          :parameters fn-params})

  (check "(fn some-name [arg1 arg2]
            \"docstring|\")"
         {:signature fn-signature
          :activeParameter 2
          :parameters fn-params})

  (check "(fn some-name [arg1 arg2]
            \"docstring\"
            |"
         {:signature fn-signature
          :activeParameter 2
          :parameters fn-params}))

(fn test-local-function []
  (check "(fn func [arg1 arg2] (print :hello))
          (func|)"
         {:signature function-signature
          :activeParameter nil
          :parameters function-params})

  (check "(fn func [arg1 arg2] (print :hello))
          (func |)"
         {:signature function-signature
          :activeParameter 0
          :parameters function-params})

  (check "(fn func [arg1 arg2] (print :hello))
          (func a1|)"
         {:signature function-signature
          :activeParameter 0
          :parameters function-params})

  (check "(fn func [arg1 arg2] (print :hello))
          (func a|1 a2)"
         {:signature function-signature
          :activeParameter 0
          :parameters function-params})

  (check "(fn func [arg1 arg2] (print :hello))
          (func a1 a2|)"
         {:signature function-signature
          :activeParameter 1
          :parameters function-params})

  (check "(fn func [arg1 arg2] (print :hello))
          (func a1 a|2)"
         {:signature function-signature
          :activeParameter 1
          :parameters function-params}))

(fn test-literals []
  (check "(fn func [arg1 arg2] (print :hello))
          (func arg 10|2)"
         {:signature function-signature
          :activeParameter 1
          :parameters function-params})

  (check "(fn func [arg1 arg2] (print :hello))
          (func arg \"10|2\")"
         {:signature function-signature
          :activeParameter 1
          :parameters function-params}))

(fn test-vararg []
  (local or-params [{:label [4 5]}
                    {:label [6 7]}
                    {:label [8 11]}])

  (check "(or a b|)"
         {:signature "(or a b ...)"
          :activeParameter 1
          :parameters or-params})

  (check "(or a b c|)"
         {:signature "(or a b ...)"
          :activeParameter 2
          :parameters or-params})

  (check "(or a b c d e|)"
         {:signature "(or a b ...)"
          :activeParameter 2
          :parameters or-params}))

(fn test-lua-builtin []
  (check "(error msg|)"
         {:signature err-signature
          :activeParameter 0
          :parameters err-params})

  (check "(error msg lvl|)"
         {:signature err-signature
          :activeParameter 1
          :parameters err-params})

  (check "(error msg lvl extr|)"
         {:signature err-signature
          :activeParameter 1
          :parameters err-params}))

(fn test-multisym []
  (check "(table.concat tbl s|)"
         {:signature "(table.concat list ?sep ?i ?j)"
          :activeParameter 1
          :parameters [{:label [14 18]}
                       {:label [19 23]}
                       {:label [24 26]}
                       {:label [27 29]}]}))

(fn test-destructuring-arg []
  (local dstr-params [{:label [6 19]}
                      {:label [20 24]}])

  (check "(fn dstr [{:field name} arg2] {})
          (dstr |)"
         {:signature "(dstr {:field name} arg2)"
          :activeParameter 0
          :parameters dstr-params})

  (check "(fn dstr [{:field name} arg2] {})
          (dstr arg1 ar|)"
         {:signature "(dstr {:field name} arg2)"
          :activeParameter 1
          :parameters dstr-params})

  (check "(fn dstr [{:field |} arg2] {})"
         {:signature fn-signature
          :activeParameter 1
          :parameters fn-params}))

(fn test-binding-form []
  (local each-signature "(each [key value (iterator)] ...)")
  (local each-params [{:label [6 28]}
                      {:label [29 32]}])

  (check "(each |)"
         {:signature each-signature
          :activeParameter 0
          :parameters each-params})

  (check "(each [|])"
         {:signature each-signature
          :activeParameter 0
          :parameters each-params})

  (check "(each [k val|])"
         {:signature each-signature
          :activeParameter 0
          :parameters each-params})

  (check "(let [a 0]
            (error |))"
         {:signature err-signature
          :activeParameter 0
          :parameters err-params})

  (check "(let [a|] (error))"
         {:signature let-signature
          :activeParameter 0
          :parameters let-params}))

(fn test-indirect-definition []
  (check "(let [a error]
            (a |))"
         {:signature err-signature
          :activeParameter 0
          :parameters err-params}))

(fn test-destructuring-binding []
  (check "(let [(a b|) {}]"
         {:signature let-signature
          :activeParameter 0
          :parameters let-params})

  (check "(let [(a {:b |}) {}]"
         {:signature let-signature
          :activeParameter 0
          :parameters let-params})

  (check "(let [{:field |} {}]"
         {:signature let-signature
          :activeParameter 0
          :parameters let-params})

  (check "(let [{:field {: nested |"
         {:signature let-signature
          :activeParameter 0
          :parameters let-params})

  (check "(let [{:field {: nested &as |}} {}]"
         {:signature let-signature
          :activeParameter 0
          :parameters let-params}))

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
