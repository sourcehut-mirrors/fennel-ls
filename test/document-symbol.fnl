(local faith (require :faith))
(local {: create-client : range-comparator} (require :test.utils))
(local {: null} (require :dkjson))

(fn check [file-contents expected-symbols]
  (let [{: client : uri} (create-client file-contents)
        [response] (client:document-symbol uri)]
    (if (not= null response.result)
      (do
        (table.sort response.result range-comparator)
        (faith.= expected-symbols response.result))
      (faith.= expected-symbols []))))

(fn test-simple-locals []
  (check "(local x 10)"
         [{:name "x"
           :kind 13
           :range {:start {:line 0 :character 7}
                   :end {:line 0 :character 8}}
           :selectionRange {:start {:line 0 :character 7}
                            :end {:line 0 :character 8}}}])

  (check "(local y 20)
          (local z 30)"
         [{:name "y"
           :kind 13
           :range {:start {:line 0 :character 7}
                   :end {:line 0 :character 8}}
           :selectionRange {:start {:line 0 :character 7}
                            :end {:line 0 :character 8}}}
          {:name "z"
           :kind 13
           :range {:start {:line 1 :character 17}
                   :end {:line 1 :character 18}}
           :selectionRange {:start {:line 1 :character 17}
                            :end {:line 1 :character 18}}}])
  nil)

(fn test-functions []
  (check "(fn my-func [])"
         [{:name "my-func"
           :kind 12
           :range {:start {:line 0 :character 4}
                   :end {:line 0 :character 11}}
           :selectionRange {:start {:line 0 :character 4}
                            :end {:line 0 :character 11}}}])

  (check "(λ another-fn [x] x)"
         [{:name "another-fn"
           :kind 12
           :range {:start {:line 0 :character 4}
                   :end {:line 0 :character 14}}
           :selectionRange {:start {:line 0 :character 4}
                            :end {:line 0 :character 14}}}
          {:name "x"
           :kind 13
           :range {:start {:line 0 :character 16}
                   :end {:line 0 :character 17}}
           :selectionRange {:start {:line 0 :character 16}
                            :end {:line 0 :character 17}}}])
  nil)

(fn test-mixed []
  (check "(local x 10)
          (fn my-func [y] (+ x y))"
         [{:name "x"
           :kind 13
           :range {:start {:line 0 :character 7}
                   :end {:line 0 :character 8}}
           :selectionRange {:start {:line 0 :character 7}
                            :end {:line 0 :character 8}}}
          {:name "my-func"
           :kind 12
           :range {:start {:line 1 :character 14}
                   :end {:line 1 :character 21}}
           :selectionRange {:start {:line 1 :character 14}
                            :end {:line 1 :character 21}}}
          {:name "y"
           :kind 13
           :range {:start {:line 1 :character 23}
                   :end {:line 1 :character 24}}
           :selectionRange {:start {:line 1 :character 23}
                            :end {:line 1 :character 24}}}])
  nil)

(fn test-multi-sym-functions []
  (check "(local M {})
          (fn M.my-func [x] x)"
         [{:name "M"
           :kind 13
           :range {:start {:line 0 :character 7}
                   :end {:line 0 :character 8}}
           :selectionRange {:start {:line 0 :character 7}
                            :end {:line 0 :character 8}}}
          {:name "M.my-func"
           :kind 12
           :range {:start {:line 1 :character 14}
                   :end {:line 1 :character 23}}
           :selectionRange {:start {:line 1 :character 14}
                            :end {:line 1 :character 23}}}
          {:name "x"
           :kind 13
           :range {:start {:line 1 :character 25}
                   :end {:line 1 :character 26}}
           :selectionRange {:start {:line 1 :character 25}
                            :end {:line 1 :character 26}}}])

  (check "(local module {})
          (fn module.func1 [])
          (fn module.func2 [a b])"
         [{:name "module"
           :kind 13
           :range {:start {:line 0 :character 7}
                   :end {:line 0 :character 13}}
           :selectionRange {:start {:line 0 :character 7}
                            :end {:line 0 :character 13}}}
          {:name "module.func1"
           :kind 12
           :range {:start {:line 1 :character 14}
                   :end {:line 1 :character 26}}
           :selectionRange {:start {:line 1 :character 14}
                            :end {:line 1 :character 26}}}
          {:name "module.func2"
           :kind 12
           :range {:start {:line 2 :character 14}
                   :end {:line 2 :character 26}}
           :selectionRange {:start {:line 2 :character 14}
                            :end {:line 2 :character 26}}}
          {:name "a"
           :kind 13
           :range {:start {:line 2 :character 28}
                   :end {:line 2 :character 29}}
           :selectionRange {:start {:line 2 :character 28}
                            :end {:line 2 :character 29}}}
          {:name "b"
           :kind 13
           :range {:start {:line 2 :character 30}
                   :end {:line 2 :character 31}}
           :selectionRange {:start {:line 2 :character 30}
                            :end {:line 2 :character 31}}}])
  nil)

{: test-simple-locals
 : test-functions
 : test-mixed
 : test-multi-sym-functions}
