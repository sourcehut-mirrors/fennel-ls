(fn it [title ...]
  `((. (require :busted) :it)
    ,title (fn [] ,...)))

(fn describe [title ...]
  `((. (require :busted) :describe)
    ,title (fn [] ,...)))

(fn assert-matches [item pattern]
  `(match ,item
    ,pattern nil
    ?otherwise#
    (error
      (.. "Pattern did not match:\n"
          (let [fennel# (require :fennel)]
            (fennel#.view ?otherwise#))
          "\ndid not match pattern:\n"
          ,(view pattern)))))

{: it
 : describe
 : assert-matches}
