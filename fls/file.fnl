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

(λ sub [self start-line start-char end-line end-char replacement]
  (local index (+ 1 start-line))
  (tset self.lines index
    (.. (string.sub (. self.lines index) 1 start-char)
        replacement
        (string.sub (. self.lines index) (+ 1 end-char)))))

{: make-file
 : make-file-from-disk
 : sub}
