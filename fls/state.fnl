(local stringx (require :pl.stringx))

(λ open-uri [uri]
  (local prefix "file://")
  (assert (stringx.startswith uri prefix))
  (let [path (string.sub uri 8)]
    (io.open path)))

(λ make-file [uri lines ?dirty]
  {: uri
   : lines
   :dirty? ?dirty})

(λ make-file-from-disk [uri]
  (make-file
    uri
    (with-open [file (open-uri uri)]
      (icollect [line (file:lines)]
         line))
    false))

(fn add-file [self uri ?contents]
  ;; assert file isn't loaded yet
  (assert (not (. self.files uri)))
  (tset
    self.files
    uri
    (make-file-from-disk uri)))

(fn new-state []
  {:files {}})
   ; :variables {}
   ; :settings {}
   ; :other-things {}

{: new-state : add-file}
