(local {: ROOT-URI
        : ROOT-PATH
        : client-mt
        : default-encoding} (require :test.utils.client))

(local utils (require :fennel-ls.utils))
(local dispatch (require :fennel-ls.dispatch))

(local NIL {})
(fn un-nil [arg]
  (if (not= arg NIL)
    arg))

(fn parse-markup [text ?encoding]
  "find the | character, which represents the cursor position"
  (var text text)
  (let [result {:ranges []}
        encoding (or ?encoding default-encoding)]
    (while
      (case
        (case (values (text:find "|") (text:find "=="))
          (where (| ==) (< | ==)) [| "|"]
          (_ ==) [== "=="]
          (| _) [| "|"])
        [i "|"]
        (do
          (set text (.. (text:sub 1 (- i 1)) (text:sub (+ i 1))))
          (set result.cursor (utils.byte->position text i encoding))
          true)
        [i "=="]
        (do
          (set text (.. (text:sub 1 (- i 1)) (text:sub (+ i 2))))
          (let [position (utils.byte->position text i encoding)]
            (if result.unmatched-range
              (do
                (table.insert result.ranges {:start result.unmatched-range :end position})
                (set result.unmatched-range nil))
              (set result.unmatched-range position)))
          true)
        nil nil))
    (set result.text text)
    result))

(fn create-client [file-contents ?opts]
  ;; TODO big function, split up
  (let [opts (or ?opts {})
        (provide-root-uri file-contents) (if (= (type file-contents) :table)
                                           (values true file-contents)
                                           (values false {:main.fnl file-contents}))

        server {:preload (if provide-root-uri {})}
        client (doto {: server :prev-id 1}
                     (setmetatable client-mt))
        locations []]
    ;; NOT main.fnl
    (each [name contents (pairs file-contents)]
      (if (not= name :main.fnl)
        (let [uri (.. ROOT-URI "/" name)
              {: text : ranges} (parse-markup contents opts.markup-encoding)]
          (icollect [_ range (ipairs ranges) &into locations]
            {: range : uri})
          (client:pretend-this-file-exists! uri text))))
    ;; main.fnl
    (let [uri (.. ROOT-URI "/" :main.fnl)
          main-file-contents (. file-contents :main.fnl)
          {: text : ranges : cursor} (parse-markup main-file-contents opts.markup-encoding)
          _ (icollect [_ range (ipairs ranges) &into locations]
              {: range : uri})

          params {:capabilities {:general {:positionEncodings (un-nil (or opts.position-encodings [default-encoding]))}}
                  :clientInfo (un-nil (or opts.client-info {:name "Neovim" :version "0.7.2"}))
                  :initializationOptions opts.initialization-options
                  :processId 16245
                  :rootPath (if provide-root-uri ROOT-PATH)
                  :rootUri (if provide-root-uri ROOT-URI)
                  :trace "off"
                  :workspaceFolders (if provide-root-uri [{:name ROOT-PATH :uri ROOT-URI}])}

          initialize-response (dispatch.handle* server
                                {:id 1
                                 :jsonrpc "2.0"
                                 :method "initialize"
                                 : params})
          [{:params {: diagnostics}}] (client:open-file! uri text)]
        {: client
         : server
         : diagnostics
         : cursor
         : locations
         : text
         : uri
         : initialize-response
         :encoding server.position-encoding})))

(fn position-past-end-of-text [text ?encoding]
  (utils.byte->position text (+ (length text) 1) (or ?encoding default-encoding)))

{: create-client
 : position-past-end-of-text
 : parse-markup
 : NIL}
