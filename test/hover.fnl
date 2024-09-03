(local faith (require :faith))
(local {: view} (require :fennel))
(local {: create-client} (require :test.utils))
(local {: null} (require :dkjson))

(fn check [file-contents ?response-string]
  (let [{: client : uri : cursor} (create-client file-contents)
        [message] (client:hover uri cursor)]
    (if (= (type ?response-string) :string)
      (faith.= ?response-string (?. message :result :contents :value)
               (.. "Invalid hover message\nfrom:    " (view file-contents)))
      (= (type ?response-string) :function)
      (faith.is (?response-string (?. message :result :contents :value))
               (.. "Invalid hover message:\n"
                   (?. message :result :contents :value)
                   "\nfrom:    " (view file-contents)))


      (faith.= null message.result))))

(fn test-literals []
  (check "(local x| 200)" "```fnl\n200\n```")
  (check "(local |x 200)" "```fnl\n200\n```")
  (check "(local x 200)\n|x" "```fnl\n200\n```")
  (check "(local x 200)\nx|" "```fnl\n200\n```")
  (check "(local x| \"hello\")" "```fnl\n:hello\n```")
  (check "(local x| \"hello world\")" "```fnl\n\"hello world\"\n```")
  (check "(local x \"hello\")\nx|" "```fnl\n:hello\n```")
  (check "(local x \"hello world\")\nx|" "```fnl\n\"hello world\"\n```")
  (check "(local x| nil)" "```fnl\nnil\n```")
  (check "(local x| true)" "```fnl\ntrue\n```")
  (check "(local x| false)" "```fnl\nfalse\n```")
  nil)

(fn test-builtins []
  (check "(d|o nil)" "```fnl\n(do ...)\n```\nEvaluate multiple forms; return last value.")
  (check "(|doto nil (print))" "```fnl\n(doto val ...)\n```\nEvaluate val and splice it into the first argument of subsequent forms.")
  (check "(le|t [x 10] 10)" "```fnl\n(let [name1 val1 ... nameN valN] ...)\n```\nIntroduces a new scope in which a given set of local bindings are used.")
  nil)

(fn test-globals []
  (check "(pri|nt :hello :world)" "```fnl\n(print ...)\n```
Receives any number of arguments
and prints their values to `stdout`,
converting each argument to a string
following the same rules of `tostring`.

The function `print` is not intended for formatted output,
but only as a quick way to show a value,
for instance for debugging.
For complete control over the output,
use `string.format` and `io.write`.")
  (check "(local x print) (x| :hello :world)" "```fnl\n(print ...)\n```
Receives any number of arguments
and prints their values to `stdout`,
converting each argument to a string
following the same rules of `tostring`.

The function `print` is not intended for formatted output,
but only as a quick way to show a value,
for instance for debugging.
For complete control over the output,
use `string.format` and `io.write`.")
  (check "(xpca|ll io.open debug.traceback :filename.txt)" "```fnl
(xpcall f msgh ?arg1 ...)
```
This function is similar to `pcall`,
except that it sets a new message handler `msgh`.")
  (check "(table.inser|t [] :message" #($:find "```fnl\n(table.insert list value)\n```" 1 true))
  nil)

(fn test-module []
  (check "coroutine.yie|ld"
         "```fnl\n(coroutine.yield ...)\n```\nSuspends the execution of the calling coroutine.\nAny arguments to `yield` are passed as extra results to `resume`.")
  (check "string.cha|r"
         "```fnl\n(string.char ...)\n```\nReceives zero or more integers.\nReturns a string with length equal to the number of arguments,\nin which each character has the internal numeric code equal\nto its corresponding argument.\n\nNumeric codes are not necessarily portable across platforms.")
  (check "(local x :hello)
          x.cha|r"
         "```fnl\n(string.char ...)\n```\nReceives zero or more integers.\nReturns a string with length equal to the number of arguments,\nin which each character has the internal numeric code equal\nto its corresponding argument.\n\nNumeric codes are not necessarily portable across platforms."))


(fn test-functions []
  (check "(fn my-function| [arg1 arg2 arg3]
            (print arg1 arg2 arg3))"
         "```fnl\n(fn my-function [arg1 arg2 arg3] ...)\n```")
  (check "(fn my-function| [arg1 arg2 arg3]
            \"this is a doc string\"
            (print arg1 arg2 arg3))"
         "```fnl\n(fn my-function [arg1 arg2 arg3] ...)\n```\nthis is a doc string")
  (check "(fn my-function [arg1 arg2 arg3]
            \"this is a doc string\"
            (print arg1 arg2 arg3))
          (|my-function)"
         "```fnl\n(fn my-function [arg1 arg2 arg3] ...)\n```\nthis is a doc string")
  (check "(fn my-function [arg1 arg2 arg3]
            \"this is a doc string\"
            (print arg1 arg2 arg3))
          (my-function)|" nil)
  (check "(fn foo| [x ...]
            \"not a docstring, this gets returned\")"
         "```fnl\n(fn foo [x ...] ...)\n```")
  (check "(λ foo| [x ...]
            \"not a docstring, this gets returned\")"
         "```fnl\n(λ foo [x ...] ...)\n```")
  (check "(λ foo| [{: start : end}]
            :body)"
         "```fnl\n(λ foo [{: end : start}] ...)\n```")
  (check "(λ foo| [{:list [a b c] :table {: d : e : f}}]
            :body)"
         "```fnl\n(λ foo [{:list [a b c] :table {: d : e : f}}] ...)\n```")
  nil)

(fn test-multisym []
  (check "(local x {:foo 10}) x.foo|" "```fnl\n10\n```")
  (check "(local x {:foo 10}) x.|foo" "```fnl\n10\n```")
  (check "(local x {:foo 10}) x|.foo" "```fnl\n{:foo 10}\n```")
  (check "(local x {:foo 10}) |x.foo" "```fnl\n{:foo 10}\n```")
  (check "(local x {:foo \"hello\"}) x.foo|" "```fnl\n:hello\n```")

  (check "(let [x [10 {:foo \"hello\"}]]
            (case (values 10 x)
              (bar [_ {: foo}]) fo|o))" "```fnl\n:hello\n```")
  nil)

(fn test-crash []
  (check "|(local x {:foo \"hello\"}) x.foo" nil)
  (check "|\n(local x {:foo \"hello\"}) x.foo" nil)
  (check "print.my-cool-real-field|" nil)
  nil)

(fn test-multival []
  (check "(local (a| b) (values 1 2))" "```fnl\n1\n```")
  (check "(local (a |b) (values 1 2))" "```fnl\n2\n```")
  (check "(local (a| b) (do (values 1 2)))" "```fnl\n1\n```")
  (check "(local (a |b) (do (values 1 2)))" "```fnl\n2\n```")
  (check "(let [(x y z a) (do (do (values 1 (do (values (values 2 4) (do 3))))))]\n  (print x| y z a))" "```fnl\n1\n```")
  (check "(let [(x y z a) (do (do (values 1 (do (values (values 2 4) (do 3))))))]\n  (print x y| z a))" "```fnl\n2\n```")
  (check "(let [(x y z a) (do (do (values 1 (do (values (values 2 4) (do 3))))))]\n  (print x y z| a))" "```fnl\n3\n```")
  (check "(let [(x y z a) (do (do (values 1 (do (values (values 2 4) (do 3))))))]\n  (print x y z a|))" nil)
  nil)

(fn test-macro []
  (check "(macro bind [a b c]
            \"docstring!\"
            `(let [,a ,b] ,c))
          (bind x print |x)"
         #($:find "```fnl\n(print ...)\n```" 1 true))

  (check "(macro foo [a b c]
            \"docstring!\"
            `(,a ,b ,c))
          (fo|o print :hello :world)"
         "```fnl\n(foo a b c)\n```\ndocstring!")
  ; (check {:main.fnl "(import-macros cool :cool)
  ;                    (coo|l.=)"
  ;         :cool.fnl ";; fennel-ls: macro-file
  ;                    {:= (λ [...] ...)}"}
  ;        "```fnl\n{:= (λ [...] ...)}\n```")
  nil)

(fn test-reader []
  ;; works in #
  (check "#(prin|t :hello)"
         #($:find "```fnl\n(print ...)\n```" 1 true))
  ;; works in ` and ,
  (check ";; fennel-ls: macro-file
          `(,prin|t :hello)"
         #($:find "```fnl\n(print ...)\n```" 1 true))
  (check "#prin|t"
         #($:find "```fnl\n(print ...)\n```" 1 true))
  (check "(hash|fn (print :hello))"
         #($:find "```fnl\n(hashfn ...)\n```" 1 true))
  ;; You can use it ON the symbol
  (check "#|(print)"
         #($:find "```fnl\n(hashfn ...)\n```" 1 true))
  (check ";; fennel-ls: macro-file
          `|(print)"
         #($:find "```fnl\n(quote x)\n```" 1 true))
  nil)

{: test-literals
 : test-builtins
 : test-globals
 : test-module
 : test-functions
 : test-multisym
 : test-crash
 : test-multival
 : test-macro
 : test-reader}
