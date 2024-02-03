(import-macros {: is-matching : describe : it} :test)
(local is (require :test.is))

(local fennel (require :fennel))
(local utils (require :fennel-ls.utils))

(describe "utils"

  (fn position [line character]
    {: line : character})

  (fn range [start-line start-col end-line end-col]
    {:start (position start-line start-col) :end (position end-line   end-col)})

  ;; "a" U+0061  is in  U+0000 to  U+007F, and therefore is 1 byte  in UTF-8, and 1 codepoint  in UTF-16
  ;; "λ" U+03BB  is in  U+0080 to  U+07FF, and therefore is 2 bytes in UTF-8, and 1 codepoint  in UTF-16
  ;; "ｾ" U+FF7E  is in  U+0800 to  U+FFFF, and therefore is 3 bytes in UTF-8, and 1 codepoint  in UTF-16
  ;; "𐐀" U+10400 is in U+10000 to U+10FFFF,and therefore is 4 bytes in UTF-8, and 2 codepoints in UTF-16
  ;; These symbols cover each of the four cases of byte/codepoint widths
  ;; they should be sufficient for testing

  (it "converts position->byte properly"
    (is.equal 1 (utils.position->byte "a𐐀λ\nbλ𐐀" (position 0 0) :utf-8))
    (is.equal 2 (utils.position->byte "a𐐀λ\nbλ𐐀" (position 0 1) :utf-8))
    (is.equal 6 (utils.position->byte "a𐐀λ\nbλ𐐀" (position 0 5) :utf-8))
    (is.equal 8 (utils.position->byte "a𐐀λ\nbλ𐐀" (position 0 7) :utf-8))
    (is.equal 9 (utils.position->byte "a𐐀λ\nbλ𐐀" (position 1 0) :utf-8))
    (is.equal 10 (utils.position->byte "a𐐀λ\nbλ𐐀" (position 1 1) :utf-8))
    (is.equal 12 (utils.position->byte "a𐐀λ\nbλ𐐀" (position 1 3) :utf-8))
    (is.equal 16 (utils.position->byte "a𐐀λ\nbλ𐐀" (position 1 7) :utf-8))
    (is.equal 1 (utils.position->byte "a𐐀λ\nbλ𐐀" (position 0 0) :utf-16))
    (is.equal 2 (utils.position->byte "a𐐀λ\nbλ𐐀" (position 0 1) :utf-16))
    (is.equal 6 (utils.position->byte "a𐐀λ\nbλ𐐀" (position 0 3) :utf-16))
    (is.equal 8 (utils.position->byte "a𐐀λ\nbλ𐐀" (position 0 4) :utf-16))
    (is.equal 9 (utils.position->byte "a𐐀λ\nbλ𐐀" (position 1 0) :utf-16))
    (is.equal 10 (utils.position->byte "a𐐀λ\nbλ𐐀" (position 1 1) :utf-16))
    (is.equal 12 (utils.position->byte "a𐐀λ\nbλ𐐀" (position 1 2) :utf-16))
    (is.equal 16 (utils.position->byte "a𐐀λ\nbλ𐐀" (position 1 4) :utf-16))
    (is.equal 19 (utils.position->byte "a𐐀ｾλ\nbλ𐐀" (position 1 4) :utf-16))
    (is.equal 19 (utils.position->byte "a𐐀ｾλ\nbλ𐐀" (position 1 4) :utf-16))
    (is.equal 7 (utils.position->byte "ｾｾ" (position 0 2) :utf-16)))

  (it "converts byte->position properly"
    (is.same (position 0 0) (utils.byte->position "a𐐀λ\nbλ𐐀" 1 :utf-8))
    (is.same (position 0 1) (utils.byte->position "a𐐀λ\nbλ𐐀" 2 :utf-8))
    (is.same (position 0 5) (utils.byte->position "a𐐀λ\nbλ𐐀" 6 :utf-8))
    (is.same (position 0 7) (utils.byte->position "a𐐀λ\nbλ𐐀" 8 :utf-8))
    (is.same (position 1 0) (utils.byte->position "a𐐀λ\nbλ𐐀" 9 :utf-8))
    (is.same (position 1 1) (utils.byte->position "a𐐀λ\nbλ𐐀" 10 :utf-8))
    (is.same (position 1 3) (utils.byte->position "a𐐀λ\nbλ𐐀" 12 :utf-8))
    (is.same (position 1 7) (utils.byte->position "a𐐀λ\nbλ𐐀" 16 :utf-8))
    (is.same (position 0 0) (utils.byte->position "a𐐀λ\nbλ𐐀" 1 :utf-16))
    (is.same (position 0 1) (utils.byte->position "a𐐀λ\nbλ𐐀" 2 :utf-16))
    (is.same (position 0 3) (utils.byte->position "a𐐀λ\nbλ𐐀" 6 :utf-16))
    (is.same (position 0 4) (utils.byte->position "a𐐀λ\nbλ𐐀" 8 :utf-16))
    (is.same (position 1 0) (utils.byte->position "a𐐀λ\nbλ𐐀" 9 :utf-16))
    (is.same (position 1 1) (utils.byte->position "a𐐀λ\nbλ𐐀" 10 :utf-16))
    (is.same (position 1 2) (utils.byte->position "a𐐀λ\nbλ𐐀" 12 :utf-16))
    (is.same (position 1 4) (utils.byte->position "a𐐀λ\nbλ𐐀" 16 :utf-16))
    (is.same (position 1 4) (utils.byte->position "a𐐀ｾλ\nbλ𐐀" 19 :utf-16))
    (is.same (position 1 4) (utils.byte->position "a𐐀ｾλ\nbλ𐐀" 19 :utf-16))
    (is.same (position 0 2) (utils.byte->position "ｾｾ" 7 :utf-16)))

  (describe "apply-changes"

    (it "updates the start of a line"
      (is.equal
        (utils.apply-changes
          "replace beginning"
          [{:range (range 0 0 0 7)
            :text "the"}]
          :utf-8)
        "the beginning"))


    (it "updates the end of a line"
      (is.equal
        (utils.apply-changes
          "first line\nsecond line\nreplace end"
          [{:range (range 2 7 2 11)
            :text "ment"}]
          :utf-8)
        "first line\nsecond line\nreplacement"))

    (it "replaces a line"
      (is.equal
        (utils.apply-changes
          "replace all"
          [{:range (range 0 0 0 11)
            :text "new string"}]
          :utf-8)
        "new string"))

    (it "can handle substituting things"
      (is.equal
        (utils.apply-changes
          "replace beginning"
          [{:range (range 0 0 0 7)
            :text "the"}]
          :utf-8)
        "the beginning"))

    (it "can handle replacing everything"
      (is.equal
        (utils.apply-changes
          "this is the\nold file"
          [{:text "And this is the\nnew file"}]
          :utf-8)
        "And this is the\nnew file"))))

 ;; (it "can substitute multiple ranges")
