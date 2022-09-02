(fn my-function [arg1 arg2 arg3]
  (let [result nil]
    result))

(local foo 300)
(let [bar "some text"]
  (my-function foo bar 3))

(local foo {:field1 10 :field2 :colon-string})
(my-function foo.field1 foo.field2)

(local empty nil)
(print empty)

(λ lambda-fn [arg1 arg2]
  "docstring"
  (print "body")
  nil)

(lambda-fn 1 2)
