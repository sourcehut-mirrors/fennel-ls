(local stringx (require :pl.stringx))

(λ open-uri [uri]
  (local prefix "file://")
  (assert (stringx.startswith uri prefix))
  (let [path (string.sub uri 8)]
    (io.open path)))

(λ make-file [uri lines]
  {: uri
   : lines})

(λ make-file-from-disk [uri]
  (make-file
    uri
    (with-open [file (open-uri uri)]
      (icollect [line (file:lines)]
         line))))

{: make-file
 : make-file-from-disk}

