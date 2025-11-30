(local {: view} (require :fennel))
(local windows (= "\\" (package.config:sub 1 1)))

(fn is-windows? [?opts]
  (case (?. ?opts :windows)
    override override
    _ windows))

(local encode1 #(string.format "%%%02X" (string.byte $)))
(fn percent-encode [str] (pick-values 1 (str:gsub "[^0-9a-zA-Z/._~-]" encode1)))

(local decode1 #(string.char (tonumber $ 16)))
(fn percent-decode [str] (pick-values 1 (str:gsub "%%(%x%x)" decode1)))

(fn path->uri [path ?opts]
  (if (is-windows? ?opts)
    (.. "file:///" (percent-encode (path:gsub "\\" "/")))
    (.. "file://" (percent-encode path))))

(fn uri->path [uri ?opts]
  (if (is-windows? ?opts)
    (case (uri:match "^file:///(.*)$")
      p (: (percent-decode p) :gsub "/" "\\")
      _ (error (.. "encountered non-file URI: " (view uri))))
    (case (uri:match "^file://(.*)$")
      p (percent-decode p)
      _ (error (.. "encountered non-file URI: " (view uri))))))

{: path->uri
 : uri->path}
