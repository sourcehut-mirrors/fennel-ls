(local faith (require :faith))
(local {: view} (require :fennel))
(local {: create-client} (require :test.utils))

(fn find [diagnostics e]
  "returns the index of the diagnostic that matches `e`"
  (accumulate [result nil
               i d (ipairs diagnostics)
               &until result]
    (if (and (or (= e.message nil)
                 (if (= (type e.message) "function")
                   (e.message d.message)
                   (= e.message d.message)))
             (or (= e.code nil)
                 (= e.code d.code))
             (or (= e.range nil)
                 (and (= e.range.start.line      d.range.start.line)
                      (= e.range.start.character d.range.start.character)
                      (= e.range.end.line        d.range.end.line)
                      (= e.range.end.character   d.range.end.character))))
      i)))

(fn check [file-contents expected unexpected]
  (let [{: diagnostics} (create-client file-contents)]
    (each [_ e (ipairs unexpected)]
      (let [i (find diagnostics e)]
        (faith.= nil i (.. "Lint matching " (view e) "\n"
                           "from:    " (view file-contents) "\n"
                           (view (. diagnostics i) {:escape-newlines? true})))))

    (each [_ e (ipairs expected)]
      (let [i (find diagnostics e)]
        (faith.is i (.. "No lint matching " (view e) "\n"
                        "from:    " (view file-contents) "\n"
                        (view diagnostics {:empty-as-sequence? true
                                           :escape-newlines? true})))
        (table.remove diagnostics i)))))

(fn test-compile-error []
  (check "(do do)"
         [{:message "tried to reference a special form without calling it"
           :range {:start {:character 4 :line 0}
                   :end   {:character 6 :line 0}}}] [])
  nil)

(fn test-parse-error []
  (check "(do (print :hello(]"
         [{:message "expected whitespace before opening delimiter ("
           :range {:start {:character 17 :line 0}
                   :end   {:character 17 :line 0}}}] [])
  nil)

(fn test-macro-error []
  (check "(match)"
         [{:range {:start {:character 0 :line 0}
                   :end   {:character 7 :line 0}}}] [])
  nil)

(fn test-multiple-errors []
  ;; compiler recovery for every fennel.friend error

  (check "(let [x.y.z 10]
            (print +))"
         [{:message "unexpected multi symbol x.y.z"}
          {:message "tried to reference a special form without calling it"}] [])

  ;; use of global .* is aliased by a local

  (check "(let [+ 10]
            (print +))"
         [{:message "local + was overshadowed by a special form or macro"}
          {:message "tried to reference a special form without calling it"}] [])

  (check "(let [x 10]
            (set x 20)
            (print x +))"
         [{:message "expected var x"}
          {:message "tried to reference a special form without calling it"}] [])

  ;; expected macros to be table
  ;; expected each macro to be a function
  ;; macro tried to bind .* without gensym

  (check "(do unknown-global
            (print +))"
         [{:message "unknown identifier: unknown-global"}
          {:message "tried to reference a special form without calling it"}] [])

  (check "(let [x ()]
            (print x +))"
         [{:message "expected a function, macro, or special to call"}
          {:message "tried to reference a special form without calling it"}] [])

  (check "(let [x (3)]
            (print x +))"
         [{:message "cannot call literal value 3"}
          {:message "tried to reference a special form without calling it"}] [])

  (check "(let [x (fn [] ...)]
            (print x +))"
         [{:message "unexpected vararg"}
          {:message "tried to reference a special form without calling it"}] [])

  (check "(let [x #...]
            (print x +))"
         [{:message "use $... in hashfn"}
          {:message "tried to reference a special form without calling it"}] [])

  (check "(let [x unknown-global"
         [{:message "unknown identifier: unknown-global"}
          {:message "expected body expression"}
          {:message "expected closing delimiters )]"}] [])
  ;; recovers from mismatched let
  (check "(let [x]
            (print x +))"
         [{:message "expected even number of name/value bindings"}
          {:message "tried to reference a special form without calling it"}] [])
  ;; recovers from missing condition (if)
  (check "(let [x (if)]
            (print x +))"
         [{:message "expected condition and body"}
          {:message "tried to reference a special form without calling it"}] [])
  ; recovers from missing condition (when)
  (check "(let [x (when)]
            (print x +))"
         [{:message #($:find ".*macros.fnl:%d+: expected body")}
          {:message "tried to reference a special form without calling it"}] [])
  ;; recovers from missing body (when)
  (check "(let [x (when (< (+ 9 10) 21))]
            (print x +))"
         [{:message #($:find ".*macros.fnl:%d+: expected body")}
          {:message "tried to reference a special form without calling it"}] [])
  (check "(let [x {:mismatched :curly :braces}]
            (print x +))"
       [{:message "expected even number of values in table literal"}
        {:message "tried to reference a special form without calling it"}] [])
  nil)

{: test-compile-error
 : test-parse-error
 : test-macro-error
 : test-multiple-errors}
