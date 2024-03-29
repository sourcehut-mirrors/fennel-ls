(local faith (require :faith))
(local {: view} (require :fennel))
(local {: create-client-with-files} (require :test.utils))

(fn find [diagnostics e]
  "returns the index of the diagnostic "
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
  (let [{: diagnostics} (create-client-with-files file-contents)]
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
  (check "(unknown-global-1 unknown-global-2)"
         [{:message "unknown identifier: unknown-global-1"}
          {:message "unknown identifier: unknown-global-2"}] [])
  (check "(let [x unknown-global"
         [{:message "unknown identifier: unknown-global"}
          {:message "expected body expression"}
          {:message "expected closing delimiters )]"}] [])
  ;; recovers from ()
  (check "(let [x ()]
            (print x +))"
         [{:message "expected a function, macro, or special to call"}
          {:message "tried to reference a special form without calling it"}] [])
  ;; recovers from mismatched let
  (check "(let [x]
            (print x +))"
         [{:message "expected even number of name/value bindings"}
          {:message "tried to reference a special form without calling it"}] [])
  nil)

{: test-compile-error
 : test-parse-error
 : test-macro-error
 : test-multiple-errors}
