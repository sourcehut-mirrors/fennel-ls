(local {: view} (require :fennel))
(local windows (= "\\" (package.config:sub 1 1)))

(fn percent-encode [str]
  (pick-values 1 (str:gsub "[^0-9a-zA-Z/._~-]" #(string.format "%%%02X" (string.byte $)))))

(fn percent-decode [str]
  (pick-values 1 (str:gsub "%%(%x%x)" #(string.char (tonumber $ 16)))))

(fn path->uri [path]
  (if windows
    (.. "file:///" (percent-encode (path:gsub "\\" "/")))
    (.. "file://" (percent-encode path))))

(fn uri->path [uri]
  (let [scheme (if windows "^file:///(.*)$"
                           "^file://(.*)$")
        p (uri:match scheme)]
    (when (not p)
      (error (.. "encountered non-file URI: " (view uri))))
    (if windows
        (: (percent-decode p) :gsub "/" "\\")
        (percent-decode p))))

{: path->uri
 : uri->path}
