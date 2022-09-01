(import-macros {: is-matching : describe : it : before-each} :test)
(local is (require :luassert))

(local {: view} (require :fennel))
(local {: ROOT-URI
        : open-file
        : setup-server} (require :test.utils))

(local dispatch (require :fennel-ls.dispatch))
(local message (require :fennel-ls.message))

(macro find [t body ?sentinel]
  (assert-compile (not ?sentinel) "you can only have one thing here, put a `(do)`")
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
    (local state (doto [] setup-server))
    (let [responses (open-file state filename "(do do)")
          diagnostic
          (match responses
            [{:params {: diagnostics}}]
            (find [i v (ipairs diagnostics)]
               (match v
                 {:message "tried to reference a special form at runtime"
                  :range {:start {:character 4 :line 0}
                          :end   {:character 6 :line 0}}}
                 v)))]
      (is diagnostic "expected a diagnostic")))

  (it "handles parse errors"
    (local state (doto [] setup-server))
    (let [responses (open-file state filename "(do (print :hello(]")
          diagnostic
          (match responses
            [{:params {: diagnostics}}]
            (find [i v (ipairs diagnostics)]
             (match v
               {:message "expected whitespace before opening delimiter ("
                :range {:start {:character 17 :line 1}
                        :end   {:character 17 :line 1}}}
               v)))]
      (is diagnostic "expected a diagnostic")))

  (it "handles (match)"
    (local state (doto [] setup-server))
    (let [responses (open-file state filename "(match)")]
      (is-matching responses
        [{:params
          {:diagnostics
           [{:range {:start {:character a :line b}
                     :end   {:character c :line d}}}]}}]
        "diagnostics should always have a range")))

  (it "gives more than one error"
    (local state (doto [] setup-server))
    (let [responses (open-file state filename "(unknown-global-1 unknown-global-2)")]
      (is-matching responses
        [{:params {:diagnostics [a b]}}]  "there should be a diagnostic for each one here"))))

;; TODO lints:
;; unnecessary (do) in body position
;; Unused variables / fields (maybe difficult)
;; discarding results to various calls
;; unnecessary `do`/`values` with only one inner form
;; mark when unification is happening on a `match` pattern (may be difficult)
;; think of more lints
