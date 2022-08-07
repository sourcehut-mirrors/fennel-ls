(import-macros {: is-matching : describe : it} :test.macros)
(local is (require :luassert))

(local fennel (require :fennel))
(local util (require :fennel-ls.util))

(describe "util"

    ;; fixme:
    ;; test for errors on out of bounds
    ;; test for multiline edits
    ;; test for unicode utf8 utf16 nightmare

    ;; (it "can handle unicode"
    ;;   (local uri (.. ROOT-URI "test_document"))
    ;;   (local my-document (document.create uri ""))
    ;;   (document.replace my-document 0 0 0 0 "どれみふぁそらてぃど")
    ;;   (document.replace my-document 0 1 0 3 "😀")
    ;;   (document.replace my-document 0 11 0 11 "end")
    ;;   (is-matching my-document {:text "ど😀ふぁそらてぃどend"})))

  (describe "apply-changes"

    (fn range [start-line start-col end-line end-col]
      {:start {:line start-line :character start-col}
       :end   {:line end-line   :character end-col}})

    (it "updates the start of a line"
      (is.equal
        (util.apply-changes
          "replace beginning"
          [{:range (range 0 0 0 7)
            :text "the"}])
        "the beginning"))

    (it "updates the end of a line"
      (is.equal
        (util.apply-changes
          "first line\nsecond line\nreplace end"
          [{:range (range 2 7 2 11)
            :text "ment"}])
        "first line\nsecond line\nreplacement"))

    (it "replaces a line"
      (is.equal
        (util.apply-changes
          "replace all"
          [{:range (range 0 0 0 11)
            :text "new string"}])
        "new string"))

    (it "can handle substituting things"
      (is.equal
        (util.apply-changes
          "replace beginning"
          [{:range {:start {:line 0 :character 0}
                    :end   {:line 0 :character 7}}
            :text "the"}])
        "the beginning"))

    (it "can handle replacing everything"
      (is.equal
        (util.apply-changes
          "this is the\nold file"
          [{:text "And this is the\nnew file"}])
        "And this is the\nnew file"))))
