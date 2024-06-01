(local fennel (require :fennel))

(fn remove-html-escape-codes [x]
  (-> x
      (: :gsub "&nbsp;" " ")
      (: :gsub "&ndash;" "–")
      (: :gsub "&mdash;" "—")
      (: :gsub "&gt;" ">")
      (: :gsub "&lt;" "<")
      (: :gsub "&amp;" "<")
      (: :gsub "&pi;" "π")))

(fn markdown->arglist [markdown]
  (case (markdown:match "%(([^%)]*)%)")
    signature
    (icollect [arg (signature:gmatch "%S+")]
      (case (arg:match "(.*)=")
        argname (.. "?" argname)
        _ arg))))

(fn markdown->data [html]
  (let [api-markdown (html:match "## API functions.-### (.*)## Button IDs")
        api-markdown (remove-html-escape-codes api-markdown)]
    (collect [(name args docs) (api-markdown:gmatch
                                "([_%w]+)%s+`([^`]+)`%s(.-)\n### ")]
      (let [arglist (markdown->arglist args)]
        (values name {:metadata {:fnl/arglist arglist
                                 :fnl/docstring docs}
                      :binding name})))))

(fn convert [contents]
  (fennel.view (markdown->data contents)))

{: convert}
