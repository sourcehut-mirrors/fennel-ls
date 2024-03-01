(local faith (require :faith))
(local {: ROOT-URI
        : ROOT-PATH
        : create-client} (require :test.utils.client))
(local {: get-markup} (require :test.utils))

(fn params-with-encodings [encodings]
  {:clientInfo {:name "my mock client" :version "9000"}
   :rootPath ROOT-PATH
   :rootUri ROOT-URI
   :workspaceFolders [{:name "foo" :uri ROOT-URI}]
   :capabilities {:general {:positionEncodings encodings}}
   :trace "off"})

(fn test-offset-encoding []
  (let [(self [response])
        (create-client {:params (params-with-encodings [:utf-16])})
        _ (faith.= :utf-16 (. response :result :positionEncoding))
        {: text : cursor :ranges [{: start : end}]} (get-markup "(let [==𐐀𐐀== 100] 𐐀𐐀|)" :utf-16)
        _ (self:open-file! "foo.fnl" text)
        [response] (self:definition "foo.fnl" cursor)]
      (faith.= start response.result.range.start)
      (faith.= end response.result.range.end))

  (let [(self [response])
        (create-client {:params (params-with-encodings [:utf-16 :utf-8])})
        _ (faith.= :utf-8 (. response :result :positionEncoding))
        {: text : cursor :ranges [{: start : end}]} (get-markup "(let [==𐐀𐐀== 100] 𐐀𐐀|)" :utf-8)
        _ (self:open-file! "foo.fnl" text)
        [response] (self:definition "foo.fnl" cursor)]
      (faith.= start response.result.range.start)
      (faith.= end response.result.range.end))

  ;; utf-16 is the fallback
  (let [(_ [response]) (create-client {:params (params-with-encodings nil)})]
    (faith.= :utf-16 (. response :result :positionEncoding)))

  (let [(_ [response]) (create-client {:params (params-with-encodings [:some-nonsense-encoding-I-dont-know])})]
    (faith.= :utf-16 (. response :result :positionEncoding)))

  nil)


{: test-offset-encoding}
