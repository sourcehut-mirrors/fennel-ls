(import-macros {: is-matching : describe : it : before-each} :test)
(local is (require :test.is))

(local {: view} (require :fennel))
(local {: ROOT-URI
        : create-client} (require :test.client))

(macro find [t body ?should-be-nil]
  (assert-compile (= nil ?should-be-nil) "you can only have one thing here, put a `(do)`")
  (assert-compile (sequence? t) "[] square brackets please")
  (local result (gensym :result))
  (local nil* (sym :nil))
  (table.insert t 1 result)
  (table.insert t 2 nil*)
  (table.insert t `&until)
  (table.insert t result)
  `(accumulate ,t ,body))

(local filename (.. ROOT-URI "/imaginary.fnl"))

(describe "diagnostic messages"
  (it "handles compile errors"
    (let [self (create-client)
          responses (self:open-file! filename "(do do)")
          diagnostic
          (match responses
            [{:params {: diagnostics}}]
            (is (find [i v (ipairs diagnostics)]
                  (match v
                    {:message "tried to reference a special form without calling it"
                     :range {:start {:character 4 :line 0}
                             :end   {:character 6 :line 0}}}
                    v))
                "not found")
            _ (error "did not match"))]
      (is diagnostic "expected a diagnostic")))

  (it "handles parse errors"
    (let [self (create-client)
          responses (self:open-file! filename "(do (print :hello(]")
          diagnostic
          (match responses
            [{:params {: diagnostics}}]
            (is (find [i v (ipairs diagnostics)]
                 (match v
                   {:message "expected whitespace before opening delimiter ("
                    :range {:start {:character 17 :line 0}
                            :end   {:character 17 :line 0}}}
                   v))
                "not found")
            _ (error "did not match"))]
      (is diagnostic "expected a diagnostic")))

  (it "handles (match)"
    (let [self (create-client)
          responses (self:open-file! filename "(match)")]
      (is-matching responses
        [{:params
          {:diagnostics
           [{:range {:start {:character 0 :line 0}
                     :end   {:character 7 :line 0}}}]}}]
        "diagnostics should always have a range")))

  (it "gives more than one error"
    (let [self (create-client)
          responses (self:open-file! filename "(unknown-global-1 unknown-global-2)")]
      (is-matching responses
        [{:params {:diagnostics [a b]}}]  "there should be a diagnostic for each one here")))

  (it "warns about unused variables"
    (let [self (create-client)
          responses (self:open-file! filename "(local x 10)")]
      (match responses
        [{:params {: diagnostics}}]
        (is (find [i v (ipairs diagnostics)]
             (match v
               {:message "unused definition: x"
                :range {:start {:character 7 :line 0}
                        :end   {:character 8 :line 0}}}
               v))
            "not found")
        _ (error "did not match"))))

  (it "warns about unused functions"
    (let [self (create-client)
          responses (self:open-file! filename "(fn x [])")]
      (match responses
        [{:params {: diagnostics}}]
        (is (find [i v (ipairs diagnostics)]
             (match v
               {:message "unused definition: x"
                :range {:start {:character 4 :line 0}
                        :end   {:character 5 :line 0}}}
               v))
            "not found")
        _ (error "did not match"))))

  (it "does not warn if a field is used"
    (let [self (create-client)
          responses (self:open-file! filename "(fn [abc] (set abc.xyz 10))")]
      (assert (not (?. responses 1 :params :diagnostics 1)))))

  (it "warns if a var is written but not read"
    (let [self (create-client)
          responses (self:open-file! filename "(var x 1) (set x 2) (set [x] [3])")]
      (match responses
        [{:params {: diagnostics}}]
        (is (find [i v (ipairs diagnostics)]
             (match v
               {:message "unused definition: x"
                :range {:start {:character 5 :line 0}
                        :end   {:character 6 :line 0}}}
               v))
            "not found")
        _ (error "did not match")))))




;; TODO lints:
;; unnecessary (do) in body position
;; Unused variables / fields (maybe difficult)
;; discarding results to various calls
;; unnecessary `do`/`values` with only one inner form
;; mark when unification is happening on a `match` pattern (may be difficult)
;; think of more lints
