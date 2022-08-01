(local fennel (require :fennel))
(local util (require :fennel-ls.util))

(fn get-ast-info [ast info]
  "find a given key of info from an AST object"
  (or (. (getmetatable ast) info)
      (. ast info)))

(fn contains? [ast byte]
  "check if a byte is in range of the AST object"
  (and (= (type ast) :table)
       (<= (get-ast-info ast :bytestart)
           byte
           (get-ast-info ast :byteend))))

(fn past? [ast byte]
  "check if a byte is past the range of the AST object"
  (and (= (type ast) :table)
       (< byte (get-ast-info ast :bytestart))))

(fn range [ast]
  "create a LSP range representing the span of an AST object"
  (if (= (type ast) :table)
    (match (values (get-ast-info ast :bytestart) (get-ast-info ast :byteend))
      (i j)
      (let [(start-line start-col) (util.byte->pos i)
            (end-line   end-col)   (util.byte->pos j)]
        {:start {:line start-line :character start-col}
         :end   {:line end-line   :character end-col}}))))

(fn from-fennel [file]
  (icollect [k v (fennel.parser file.text file.uri)]
      v))

{: from-fennel
 : contains?
 : past?}
