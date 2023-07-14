(import-macros {: is-matching : is-casing : describe : it : before-each} :test)
(local {: view} (require :fennel))

(local is (require :test.is))
(local {: ROOT-URI
        : ROOT-PATH
        : create-client} (require :test.client))

(fn default [tbl field value]
  (when (= nil (. tbl field))
    (tset tbl field value)))

(fn client-initialization [params]
  (default params :clientInfo {:name "xerool's mock client" :version "9000"}) ;; not necessary, but why not have some fun?
  (default params :rootPath ROOT-PATH) ;; deprecated, TODO delete
  (default params :rootUri ROOT-URI)   ;; deprecated, TODO delete
  {default params :workspaceFolders [{:name "my cool space" :uri ROOT-URI}]}
  (default params :capabilities {})
  (default params :trace "off") ;; | "messages" | "verbose"
  ;; :initializationOptions {}) ;; LspAny
  ;; :processId nil
  ;; :locale "en" ;; I don't support languages/translations as of now
  params)

(describe "capabilities negotiations"

  (it "chooses utf-16"
    (let [(self [response])
          (create-client
            {:params
              (client-initialization
                 {:capabilities
                   {:general
                     {:positionEncodings
                       [:utf-16]}}})})]
      (is.equal :utf-16 (. response :result :positionEncoding))
      (self:open-file! "foo.fnl" "(let [𐐀𐐀 100] 𐐀𐐀)")
      (let [[response] (self:definition "foo.fnl" 0 16)]
        (is.equal 6 response.result.range.start.character)
        (is.equal 10 response.result.range.end.character))))

  (it "chooses utf-8 if at all possible"
    (let [(self [response])
          (create-client
            {:params
             (client-initialization
               {:capabilities
                 {:general
                   {:positionEncodings
                     [:utf-16 :utf-8]}}})})]
      (is.equal :utf-8 (. response :result :positionEncoding))
      (self:open-file! "foo.fnl" "(let [𐐀𐐀 100] 𐐀𐐀)")
      (let [[response] (self:definition "foo.fnl" 0 20)]
        (is.equal 6 response.result.range.start.character)
        (is.equal 14 response.result.range.end.character)))))

(it "falls back to utf-16"
  (let [(self [response]) (create-client {:params (client-initialization {})})]
    (is.equal :utf-16 (. response :result :positionEncoding))))


