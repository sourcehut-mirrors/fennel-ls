(local fennel (require :fennel))
(local util (require :fennel-ls.util))

(λ get-ast-info [?ast info]
  "find a given key of info from an AST object"
  (or (?. (getmetatable ?ast) info)
      (. ?ast info)))

(λ contains? [?ast byte]
  "check if a byte is in range of the AST object"
  (and (= (type ?ast) :table)
       (get-ast-info ?ast :bytestart)
       (get-ast-info ?ast :byteend)
       (<= (get-ast-info ?ast :bytestart)
           byte
           (+ 1 (get-ast-info ?ast :byteend)))))

(λ does-not-contain? [?ast byte]
  "check if a byte is in range of the AST object"
  (and (= (type ?ast) :table)
       (get-ast-info ?ast :bytestart)
       (get-ast-info ?ast :byteend)
       (not
         (<= (get-ast-info ?ast :bytestart)
             byte
             (+ 1 (get-ast-info ?ast :byteend))))))


(λ past? [?ast byte]
  "check if a byte is past the range of the AST object"
  (and (= (type ?ast) :table)
       (get-ast-info ?ast :bytestart)
       (< byte (get-ast-info ?ast :bytestart))
       false))

(λ range [text ?ast]
  "create a LSP range representing the span of an AST object"
  (if (= (type ?ast) :table)
    (match (values (get-ast-info ?ast :bytestart) (get-ast-info ?ast :byteend))
      (i j)
      (let [(start-line start-col) (util.byte->pos text i)
            (end-line   end-col)   (util.byte->pos text (+ j 1))]
        {:start {:line start-line :character start-col}
         :end   {:line end-line   :character end-col}}))))

{: contains?
 : does-not-contain?
 : past?
 : range}
