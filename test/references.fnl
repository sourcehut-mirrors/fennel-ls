(local faith (require :faith))
(local {: create-client : location-comparator} (require :test.utils))
(local {: null} (require :dkjson))
(local {: view} (require :fennel))

(fn check [file-contents]
  (let [{: client : uri : cursor : locations} (create-client file-contents)
        [response] (client:references uri cursor)]
    (if (not= null response.result)
      (do
        (table.sort locations location-comparator)
        (table.sort response.result location-comparator)
        (faith.= locations response.result
                 (view file-contents)))
      (faith.= locations []))))

(fn test-references []
  (check "(let [x 10] ==x==|)")
  (check "(let [x| 10] ==x==)")
  (check "(let [x| 10] ==x== ==x== ==x==)")
  (check "(fn x []) ==x|==")
  (check "(fn x []) ==|x==")
  (check "(fn x| []) ==x==")
  (check "(fn x [])| x")
  (check "(let [x nil] ==|x.y== ==x.z==)")
  (check "(let [x nil] ==x|.y== ==x.z==)")
  (check "(let [x nil] x.|y x.z)")
  (check "(let [x nil] x.y| x.z)")
  (check "(let [x| 10]
            (print ==x==)
            (let [x :shadowed] x))")
  nil)

{: test-references}
