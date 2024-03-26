(local _faith (require :faith))
(local {: view} (require :fennel))
(local {: create-client-with-files} (require :test.utils))

(fn check [file-contents]
  (let [{: self : uri :locations [range]} (create-client-with-files file-contents)
        response (self:code-action uri range.range)]
;;    (print "hello" (view response))))
      nil))

(fn test-thing []
  (check "(+====)"
         "op-with-no-arguments"))

{: test-thing}
