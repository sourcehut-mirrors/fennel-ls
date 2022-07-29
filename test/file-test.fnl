(import-macros {: assert-matches : describe : it} :test.macros)
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

(local FILE-URI (.. ROOT-URI "test_file"))

(describe "File Loading"
  (it "can open files from disk"
    (local uri (.. ROOT-URI "test.fnl"))

    (local test-fnl-file (fls.file.make-file-from-disk uri))
    (assert.equal (. test-fnl-file.lines 1)
                  "((require :busted.runner))"))

  (it "can open files from fixed contents"
    (local uri (.. ROOT-URI "test_file"))
    (local my-file (fls.file.make-file uri ["line 1" "line 2" "line 3"]))
    (assert
      (match my-file
        {:lines ["line 1" "line 2" "line 3"]}
        true
        otherwise (values false (fennel.view otherwise)))))

  (it "can update the start of a line"
    (local my-file (fls.file.make-file FILE-URI ["replace beginning"]))
    (fls.file.sub my-file 0 0 0 7 "the")
    (assert-matches my-file {:lines ["the beginning"]}))

  (it "can update the end of a line"
    (local my-file (fls.file.make-file FILE-URI ["replace end"]))
    (fls.file.sub my-file 0 7 0 11 "ment")
    (assert-matches my-file {:lines ["replacement"]}))

  (it "can replace a line"
    (local my-file (fls.file.make-file FILE-URI ["replace all"]))
    (fls.file.sub my-file 0 0 0 11 "new string")
    (assert-matches my-file {:lines ["new string"]})))

  ;; next steps:
  ;; test for errors on out of bounds
  ;; test for multiline edits
  ;; test for unicode utf8 utf16 nightmare

  ;; (it "can handle unicode"
  ;;   (local uri (.. ROOT-URI "test_file"))
  ;;   (local my-file (fls.file.make-file uri [""]))
  ;;   (fls.file.sub my-file 0 0 0 0 "どれみふぁそらてぃど")
  ;;   (fls.file.sub my-file 0 1 0 3 "😀")
  ;;   (fls.file.sub my-file 0 11 0 11 "end")
  ;;   (assert-matches my-file {:lines ["ど😀ふぁそらてぃどend"]})))
