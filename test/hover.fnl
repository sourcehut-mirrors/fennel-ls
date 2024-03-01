(local faith (require :faith))
(local {: view} (require :fennel))
(local {: create-client-with-files} (require :test.utils))
(local {: null} (require :fennel-ls.json.json))

(fn check [file-contents ?response-string]
  (let [{: self : uri : cursor} (create-client-with-files file-contents)
        [message] (self:hover uri cursor)]
    (if ?response-string
      (faith.= ?response-string (?. message :result :contents :value)
               (.. "Invalid hover message\nfrom:    " (view file-contents)))

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
;; TODO fix globals
;   (check "(pri|nt :hello :world)" "```fnl\n(print ...)\n```\nHi its me! I'm the print docs")
;   (check "(xpca|ll io.open debug.traceback :filename.txt)" "```fnl\n(xpcall ...)\n```\nHi its me! I'm the xpcall docs"))
  nil)

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
  (check "(λ foo| [x ...]
            \"not a docstring, this gets returned\")"
         "```fnl\n(fn foo [x ...] ...)\n```")
  ;; TODO cleanup signatures
  ; (check "(λ foo| [{: start : end} ...]
  ;           :body)"
  ;        "```fnl\n(fn foo [{: start : end} ...] ...)\n```")
  nil)

(fn test-multisym []
  (check "(local x {:foo 10}) x.foo|" "```fnl\n10\n```")
  (check "(local x {:foo 10}) x.|foo" "```fnl\n10\n```")
  ;; TODO make it pick the other side of the multisym
  ;; (check "(local x {:foo 10}) x|.foo" "```fnl\n{:foo 10}\n```")
  (check "(local x {:foo 10}) |x.foo" "```fnl\n{:foo 10}\n```")
  (check "(local x {:foo \"hello\"}) x.foo|" "```fnl\n:hello\n```")

  (check "(let [x [10 {:foo \"hello\"}]]
            (case (values 10 x)
              (bar [_ {: foo}]) fo|o))" "```fnl\n:hello\n```")
  nil)

(fn test-crash []
  (check "|(local x {:foo \"hello\"}) x.foo" nil)
  (check "|\n(local x {:foo \"hello\"}) x.foo" nil)
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

{: test-literals
 : test-builtins
 : test-globals
 : test-functions
 : test-multisym
 : test-crash
 : test-multival}
