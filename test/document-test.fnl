(import-macros {: assert-matches : describe : it} :test.macros)
(local assert (require :luassert))

(local fennel (require :fennel))
(local stringx (require :pl.stringx))

(local document (require :fennel-ls.document))

(local ROOT-URI
  (.. "file://"
      (-> (io.popen "pwd")
          (: :read :*a)
          (stringx.strip))))

(local FILE-URI (.. ROOT-URI "/test_document"))

(describe "document"
  (describe "create-from-disk"
    (it "opens documents from disk"
      (local uri (.. ROOT-URI "/test/init.fnl"))

      (local test-fnl-document (document.create-from-disk uri))
      (assert.equal (. test-fnl-document.lines 1)
                    "((require :busted.runner))"))

    (it "crashes on bad file"
      (assert.errors #(document.create-from-disk "fill://my/path/here"))
      (assert.errors #(document.create-from-disk "file:///this/path/hopefully/does/not/exist/on/the/host/system&^$!@#%"))))

  (describe "create-from-contents"
    (it "opens documents from fixed contents"
      (local uri (.. ROOT-URI "/test_document"))
      (assert-matches
        (document.create-from-contents uri "line 1\nline 2\nline 3")
        {:lines ["line 1" "line 2" "line 3"]})))

  (describe "sub"
    (it "updates the start of a line"
      (local my-document (document.create FILE-URI ["replace beginning"]))
      (document.sub my-document 0 0 0 7 "the")
      (assert-matches my-document {:lines ["the beginning"]}))

    (it "updates the end of a line"
      (local my-document (document.create FILE-URI ["replace end"]))
      (document.sub my-document 0 7 0 11 "ment")
      (assert-matches my-document {:lines ["replacement"]}))

    (it "replaces a line"
      (local my-document (document.create FILE-URI ["replace all"]))
      (document.sub my-document 0 0 0 11 "new string")
      (assert-matches my-document {:lines ["new string"]})))

    ;; fixme:
    ;; test for errors on out of bounds
    ;; test for multiline edits
    ;; test for unicode utf8 utf16 nightmare

    ;; (it "can handle unicode"
    ;;   (local uri (.. ROOT-URI "test_document"))
    ;;   (local my-document (document.create uri [""]))
    ;;   (document.sub my-document 0 0 0 0 "どれみふぁそらてぃど")
    ;;   (document.sub my-document 0 1 0 3 "😀")
    ;;   (document.sub my-document 0 11 0 11 "end")
    ;;   (assert-matches my-document {:lines ["ど😀ふぁそらてぃどend"]})))

  (describe "apply-changes"
    (it "can handle substituting things"
      (local my-document (document.create FILE-URI ["replace beginning"]))
      (document.apply-changes
        my-document
        [{:range {:start {:line 0 :character 0}
                  :end   {:line 0 :character 7}}
          :text "the"}])
      (assert-matches my-document {:lines ["the beginning"]}))

    (it "can handle replacing everything"
      (local my-document (document.create FILE-URI ["this is the" "old file"]))
      (document.apply-changes
        my-document
        [{:text "And this is the\nnew file"}])
      (assert-matches my-document {:lines ["And this is the" "new file"]})))

  (describe "lines"
    (it "splits lines"
      (assert.same (document.lines "hello world\nnewlines are fun\rgaming\r\nworld
double double\r\n\ndouble trouble\n\r\nfunny\r\rand\n\nfinal")
                   ["hello world" "newlines are fun"
                    "gaming" "world" "double double"
                    "" "double trouble"
                    "" "funny" "" "and"
                    "" "final"]))))
