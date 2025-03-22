(local faith (require :faith))
(local {: view} (require :fennel))
(local {: create-client} (require :test.utils))
(local {: apply-edits} (require :fennel-ls.utils))

(create-client "(print :hi)")

(fn check [file-contents action-I-want-to-take desired-file-contents]
  (let [{: client : uri :locations [range] : encoding : text} (create-client file-contents)
        [{:result responses}] (client:code-action uri range.range)
        action (accumulate [result nil
                            _ action (ipairs responses) &until result]
                 (if (= action.title action-I-want-to-take)
                   action))]
    (if (not action)
      (error
         (.. "I couldn't find your action \"" action-I-want-to-take "\" in:\n"
             (view (icollect [_ action (ipairs responses)]
                     action.title)))))
    (let [edits (?. action :edit :changes uri)
          edited-text (apply-edits text edits encoding)]
      (faith.= desired-file-contents edited-text))))

(fn check-negative [file-contents action-not-suggested]
  (let [{: client : uri :locations [range]} (create-client file-contents)
        [{:result responses}] (client:code-action uri range.range)]
    (each [_ action (ipairs responses)]
      (assert (not= action.title action-not-suggested)
        (.. "I found your action \"" action-not-suggested "\" in:\n"
            (view (icollect [_ action (ipairs responses)]
                    action.title)))))))

(fn test-fix-op-no-arguments []
  (check "(let [x (+====)]
            (print x))"
         "Replace with the corresponding literal"
         "(let [x 0]
            (print x))"))

(fn test-fix-unused-definition []
  (check "(local x==== 10)"
         "Prefix with _ to silence warning"
         "(local _x 10)"))

(fn test-unnecessary-tset []
  (check "==(tset state :mouse 496)=="
         "Replace with set"
         "(set state.mouse 496)")

  (check "==(tset state :mouse :cursor 496)=="
         "Replace with set"
         "(set state.mouse.cursor 496)")

  (check "==(tset state :mouse :cursor {:x 4 :y 7})=="
         "Replace with set"
         "(set state.mouse.cursor {:x 4 :y 7})")

  (check "==(tset state :mouse :cursor :x 496)=="
         "Replace with set"
         "(set state.mouse.cursor.x 496)"))

{: test-fix-op-no-arguments
 : test-fix-unused-definition
 : test-unnecessary-tset}
