(local {: ROOT-URI
        : create-client
        : default-encoding} (require :test.utils.client))
(local utils (require :fennel-ls.utils))

(fn get-markup [text ?encoding]
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

(fn create-client-with-files [file-contents ?client-options]
  (let [(?give-a-root-uri file-contents) (if (= (type file-contents) :string)
                                           (values nil {:main.fnl file-contents})
                                           (values true file-contents))
        (client server) (create-client ?client-options ?give-a-root-uri)
        locations []]
    (each [name marked (pairs file-contents)]
      (if (not= name :main.fnl)
        (let [uri (.. ROOT-URI "/" name)
              {: text : ranges} (get-markup marked)]
          (icollect [_ range (ipairs ranges) &into locations]
            {: range : uri})
          (client:pretend-this-file-exists! uri text))))
    (let [uri (.. ROOT-URI "/" :main.fnl)
          main-file-contents (. file-contents :main.fnl)
          {: text : ranges : cursor} (get-markup main-file-contents)]
      (icollect [_ range (ipairs ranges) &into locations]
        {: range : uri})
      (let [[{:params {: diagnostics}}] (client:open-file! uri text)]
        {: client
         : server
         : diagnostics
         : cursor
         : locations
         : text
         : uri
         :encoding server.position-encoding}))))

(fn position-past-end-of-text [text ?encoding]
  (utils.byte->position text (+ (length text) 1) (or ?encoding default-encoding)))

{: create-client-with-files
 : position-past-end-of-text
 : get-markup}
