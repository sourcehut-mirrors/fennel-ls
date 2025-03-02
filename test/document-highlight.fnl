(local faith (require :faith))
(local {: create-client} (require :test.utils))
(local {: null} (require :dkjson))
(local {: view} (require :fennel))

(fn range-comparator [a b]
    (or (< a.range.start.line b.range.start.line)
        (and (= a.range.start.line b.range.start.line)
             (or (< a.range.start.character b.range.start.character)
                 (and (= a.range.start.character b.range.start.character)
                     (or (< a.range.end.line b.range.end.line)
                         (and (= a.range.end.line b.range.end.line)
                             (or (< a.range.end.character b.range.end.character)
                                 (= a.range.end.character b.range.end.character)))))))))

(fn check [file-contents]
  (let [{: client : uri : cursor : highlights} (create-client file-contents)
        [response] (client:document-highlight uri cursor)]
    (if (not= null response.result)
      (do
        (table.sort highlights range-comparator)
        (table.sort response.result range-comparator)
        ;; Override kind in the result because utils.parse-markup doesn't have
        ;; a way to express it. The ranges are more important.
        (each [_ v (ipairs response.result)]
          (set v.kind 1))
        (faith.= highlights response.result
                 (view file-contents)))
      (faith.= highlights []))))

(fn test-document-highlights []
  (check "(let [==x== 10] ==x==|)")
  (check "(let [==x==| 10] ==x==)")
  (check "(let [==x==| 10] ==x== ==x== ==x==)")
  (check "(fn ==x== []) ==x|==")
  (check "(fn ==x== []) ==|x==")
  (check "(fn ==x==| []) ==x==")
  (check "(fn x [])| x")
  (check "(let [==x== nil] ==|x.y== ==x.z==)")
  (check "(let [==x== nil] ==x|.y== ==x.z==)")
  (check "(let [x nil] x.|y x.z)")
  (check "(let [x nil] x.y| x.z)")
  (check "(let [==x==| 10]
            (print ==x==)
            (let [x :shadowed] x))")
  nil)

(fn test-multiple-files []
  (check
    {:foo.fnl "(fn target []
                 nil)
               {: target}"
     :main.fnl "(local foo (require :foo))
                (foo.targe|t)"})

  nil)

{: test-document-highlights
 : test-multiple-files}
