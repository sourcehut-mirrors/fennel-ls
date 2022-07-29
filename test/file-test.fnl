(import-macros {: it! : describe!} :test.macros)
(local assert (require :luassert))

(local fennel (require :fennel))
(local fls (require :fls))
(local stringx (require :pl.stringx))


(local ROOT-URI
  (.. "file://"
      (-> (io.popen "pwd")
          (: :read :*a)
          (stringx.strip))
      "/"))

(describe! "File Loading"
  (it! "can open files from disk"
    (local uri (.. ROOT-URI "test.fnl"))

    (local test-fnl-file (fls.file.make-file-from-disk uri))
    (assert.equal (. test-fnl-file.lines 1)
                  "((require :busted.runner))"))

  (it! "can have files with fixed contents"
    (local uri (.. ROOT-URI "test.fnl"))
    (local my-file (fls.file.make-file uri ["line 1" "line 2" "line 3"]))
    (assert
      (match my-file
        {:lines ["line 1" "line 2" "line 3"]}
        true
        otherwise (values false (fennel.view otherwise))))))
