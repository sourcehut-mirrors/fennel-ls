(local faith (require :faith))
(local {: create-client : NIL} (require :test.utils))

(fn test-offset-encoding []
  (let [{: client
         : cursor
         : uri
         : encoding
         :locations [{:range {: start : end}}]
         : initialize-response} (create-client "(let [==𐐀𐐀== 100] 𐐀𐐀|)"
                                  {:position-encodings [:utf-16]
                                   :markup-encoding :utf-16})
        [response] (client:definition uri cursor)]
    (faith.= :utf-16 encoding)
    (faith.= :utf-16 (. initialize-response 1 :result :capabilities :positionEncoding))
    (faith.= cursor {:line 0 :character 20})
    (faith.= start response.result.range.start)
    (faith.= end response.result.range.end))

  (let [{: client
         : cursor
         : uri
         : encoding
         :locations [{:range {: start : end}}]
         : initialize-response} (create-client "(let [==𐐀𐐀== 100] 𐐀𐐀|)"
                                   {:position-encodings [:utf-8]
                                    :markup-encoding :utf-8})
        [response] (client:definition uri cursor)]
      (faith.= :utf-8 encoding)
      (faith.= :utf-8 (. initialize-response 1 :result :capabilities :positionEncoding))
      (faith.= cursor {:line 0 :character 28})
      (faith.= start response.result.range.start)
      (faith.= end response.result.range.end))

  ;; utf-16 is the fallback
  (let [{: initialize-response} (create-client "" {:position-encodings NIL})]
    (faith.= :utf-16 (. initialize-response 1 :result :capabilities :positionEncoding)))

  (let [{: initialize-response} (create-client "" {:position-encodings [:some-unknown-encoding]})]
    (faith.= :utf-16 (. initialize-response 1 :result :capabilities :positionEncoding)))

  (let [{: initialize-response} (create-client "" {:position-encodings [:utf-8 :utf-16]})]
    (faith.= :utf-8 (. initialize-response 1 :result :capabilities :positionEncoding)))

  nil)


{: test-offset-encoding}
